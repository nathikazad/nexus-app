package com.nexus.nx_canvas

import android.app.Activity
import android.content.Context
import android.os.*
import android.util.Log
import android.view.FrameMetrics
import org.json.JSONObject
import java.io.File
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong

/** Local-only diagnostics. No network, drawing points, titles, or document identifiers.
 * Producers never perform disk IO. A bounded queue and rotating files cap overhead.
 */
object CanvasDiagnostics : DiagnosticSink {
    data class Span(val id:Long,val name:String,val start:Long,val cpu:Long,val thread:String) : DiagnosticSpan { override fun end(fields: Map<String, Any?>) { CanvasDiagnostics.end(this, fields) } }
    private val sequence=AtomicLong()
    private val active=ConcurrentHashMap<Long,Span>()
    private val buffer=InkDiagnosticBuffer(2048)
    private val main=Handler(Looper.getMainLooper())
    private val monitor=Executors.newSingleThreadScheduledExecutor{r->Thread(r,"canvas-watchdog").apply{isDaemon=true}}
    private val frames=HandlerThread("canvas-frame-metrics")
    private val runId=UUID.randomUUID().toString()
    @Volatile private var started=false
    @Volatile private var heartbeat=0L
    @Volatile private var awaitingHeartbeat=false
    @Volatile private var state:Map<String,Any?> = emptyMap()
    private var lastStack=0L
    private var lastMemory=0L
    private var lastThreads=0L
    private var frameCount=0L
    private var slowFrames=0L
    private var worstFrame=0.0
    private var lastFrameReport=0L

    @Synchronized fun start(context:Context) {
        if(started)return
        started=true
        val directory=File(context.getExternalFilesDir(null)?:context.filesDir,"canvas-diagnostics")
        Thread({
            directory.mkdirs()
            var file=File(directory,"events.jsonl")
            while(true) {
                val entry=buffer.take()
                try {
                    val line=JSONObject(entry).toString()
                    if(file.length()>2*1024*1024) {
                        File(directory,"events.3.jsonl").delete()
                        for(i in 2 downTo 1)File(directory,"events.$i.jsonl").renameTo(File(directory,"events.${i+1}.jsonl"))
                        file.renameTo(File(directory,"events.1.jsonl"))
                    }
                    file.appendText(line+"\n")
                    // File retains the full record; logcat stays under its per-entry limit.
                    Log.i("NxCanvasDiag",line.take(3800))
                } catch(_:Exception){Log.w("NxCanvasDiag","Diagnostic file write failed")}
            }
        },"canvas-diagnostic-writer").apply{isDaemon=true;start()}
        frames.start()
        monitor.scheduleAtFixedRate({runCatching{tick()}},0,250,TimeUnit.MILLISECONDS)
        event("diagnostics.start",mapOf("sdk" to Build.VERSION.SDK_INT,"model" to Build.MODEL,
            "version" to context.packageManager.getPackageInfo(context.packageName,0).versionName,
            "build" to if(Build.VERSION.SDK_INT>=28)context.packageManager.getPackageInfo(context.packageName,0).longVersionCode else context.packageManager.getPackageInfo(context.packageName,0).versionCode.toLong(),
            "directory" to directory.absolutePath))
    }
    override fun event(name:String,fields:Map<String,Any?>) {
        if(name == "canvas.state")state = fields
        if(!started)return
        buffer.offer(mapOf("event" to name,"run" to runId,"time_ms" to System.currentTimeMillis(),
            "elapsed_ms" to SystemClock.elapsedRealtime(),"thread" to Thread.currentThread().name)+fields)
    }
    override fun begin(name:String,fields:Map<String,Any?>):Span {
        val span=Span(sequence.incrementAndGet(),name,SystemClock.elapsedRealtimeNanos(),Debug.threadCpuTimeNanos(),Thread.currentThread().name)
        active[span.id]=span;event("span.begin",mapOf("id" to span.id,"stage" to name)+fields)
        return span
    }
    fun end(span:Span,fields:Map<String,Any?> = emptyMap()) {
        active.remove(span.id)
        event("span.end",mapOf("id" to span.id,"stage" to span.name,
            "wall_ms" to (SystemClock.elapsedRealtimeNanos()-span.start)/1e6,
            "cpu_ms" to if(Thread.currentThread().name==span.thread)(Debug.threadCpuTimeNanos()-span.cpu)/1e6 else -1.0)+fields)
    }
    fun attach(activity:Activity) {
        activity.window.addOnFrameMetricsAvailableListener({_,metrics,dropped->
            val ms=metrics.getMetric(FrameMetrics.TOTAL_DURATION)/1e6
            frameCount++;if(ms>50)slowFrames++;worstFrame=maxOf(worstFrame,ms)
            val now=SystemClock.elapsedRealtime()
            if(ms>250 || now-lastFrameReport>5000) {
                event("window.frames",mapOf("count" to frameCount,"over_50ms" to slowFrames,"max_ms" to worstFrame,
                    "last_ms" to ms,"draw_ms" to metrics.getMetric(FrameMetrics.DRAW_DURATION)/1e6,
                    "layout_ms" to metrics.getMetric(FrameMetrics.LAYOUT_MEASURE_DURATION)/1e6,
                    "sync_ms" to metrics.getMetric(FrameMetrics.SYNC_DURATION)/1e6,
                    "swap_ms" to metrics.getMetric(FrameMetrics.SWAP_BUFFERS_DURATION)/1e6,"dropped_reports" to dropped))
                frameCount=0;slowFrames=0;worstFrame=0.0;lastFrameReport=now
            }
        },Handler(frames.looper))
    }
    private fun tick() {
        val now=SystemClock.elapsedRealtime()
        if(!awaitingHeartbeat) {
            heartbeat=now;awaitingHeartbeat=true
            main.post {
                val delay=SystemClock.elapsedRealtime()-heartbeat
                if(delay>=250)event("main.recovered",mapOf("delay_ms" to delay))
                awaitingHeartbeat=false
            }
        } else if(now-heartbeat>=500 && now-lastStack>=1000) {
            lastStack=now
            event("main.stall",mapOf("delay_ms" to now-heartbeat,"state" to state,
                "main_stack" to Looper.getMainLooper().thread.stackTrace.take(32).map{it.toString()},
                "active_spans" to active.values.map{mapOf("id" to it.id,"stage" to it.name,"thread" to it.thread,"age_ms" to (SystemClock.elapsedRealtimeNanos()-it.start)/1e6)}))
            if(now-heartbeat>=2000 && now-lastThreads>=5000) {
                lastThreads=now
                event("threads.stall",mapOf("threads" to Thread.getAllStackTraces().entries
                .filter{it.key.name!="canvas-diagnostic-writer"}.take(24)
                .map{mapOf("thread" to it.key.name,"state" to it.key.state.name,"stack" to it.value.take(18).map{frame->frame.toString()})}))
            }
        }
        if(now-lastMemory>=10000) {
            lastMemory=now
            val runtime=Runtime.getRuntime();val info=Debug.MemoryInfo();Debug.getMemoryInfo(info)
            event("process.sample",mapOf("java_used" to runtime.totalMemory()-runtime.freeMemory(),
                "java_limit" to runtime.maxMemory(),"native_allocated" to Debug.getNativeHeapAllocatedSize(),
                "pss_kb" to info.totalPss,"memory" to info.memoryStats,"gc" to Debug.getRuntimeStats(),
                "process_cpu_ms" to Process.getElapsedCpuTime(),"dropped_events" to buffer.dropped.get(),"state" to state))
        }
    }
}
