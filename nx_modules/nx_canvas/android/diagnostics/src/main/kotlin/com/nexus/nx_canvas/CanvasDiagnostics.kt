package com.nexus.nx_canvas

import android.content.Context
import android.os.*
import android.util.Log
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
    data class Span(val id:Long,val name:String,val start:Long,val cpu:Long,val thread:String,val fields:Map<String,Any?>) : DiagnosticSpan { override fun end(fields: Map<String, Any?>) { CanvasDiagnostics.end(this, fields) } }
    private val sequence=AtomicLong()
    private val active=ConcurrentHashMap<Long,Span>()
    private val buffer=InkDiagnosticBuffer(2048)
    private val main=Handler(Looper.getMainLooper())
    private val monitor=Executors.newSingleThreadScheduledExecutor{r->Thread(r,"canvas-watchdog").apply{isDaemon=true}}
    private val runId=UUID.randomUUID().toString()
    @Volatile private var started=false
    @Volatile private var heartbeat=0L
    @Volatile private var awaitingHeartbeat=false
    @Volatile private var transition: String? = null
    private var lastStack=0L
    fun transitionStart(id: String) { transition = id }
    fun transitionEnd() { transition = null }

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
        monitor.scheduleAtFixedRate({runCatching{tick()}},0,250,TimeUnit.MILLISECONDS)
        event("diagnostics.start",mapOf("sdk" to Build.VERSION.SDK_INT,"model" to Build.MODEL,
            "version" to context.packageManager.getPackageInfo(context.packageName,0).versionName,
            "build" to if(Build.VERSION.SDK_INT>=28)context.packageManager.getPackageInfo(context.packageName,0).longVersionCode else context.packageManager.getPackageInfo(context.packageName,0).versionCode.toLong(),
            "directory" to directory.absolutePath))
    }
    override fun event(name:String,fields:Map<String,Any?>) {
        if(!started || !CanvasDiagnosticPolicy.event(name))return
        buffer.offer(mapOf("event" to name,"run" to runId,"time_ms" to System.currentTimeMillis(),
            "elapsed_ms" to SystemClock.elapsedRealtime(),"thread" to Thread.currentThread().name)+fields)
    }
    override fun begin(name:String,fields:Map<String,Any?>):Span {
        val span=Span(sequence.incrementAndGet(),name,SystemClock.elapsedRealtimeNanos(),Debug.threadCpuTimeNanos(),Thread.currentThread().name,fields)
        active[span.id]=span
        return span
    }
    fun end(span:Span,fields:Map<String,Any?> = emptyMap()) {
        active.remove(span.id)
        val wallMs = (SystemClock.elapsedRealtimeNanos()-span.start)/1e6
        if (started && CanvasDiagnosticPolicy.span(span.name, wallMs)) {
            buffer.offer(mapOf("event" to "span.end", "run" to runId,
                "time_ms" to System.currentTimeMillis(), "elapsed_ms" to SystemClock.elapsedRealtime(),
                "thread" to span.thread, "stage" to span.name, "wall_ms" to wallMs,
                "cpu_ms" to if(Thread.currentThread().name==span.thread)(Debug.threadCpuTimeNanos()-span.cpu)/1e6 else -1.0,
                "transition" to transition) + span.fields + fields)
        }
    }
    private fun tick() {
        if (transition == null) return
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
            event("main.stall",mapOf("delay_ms" to now-heartbeat,"transition" to transition,
                "main_stack" to Looper.getMainLooper().thread.stackTrace.take(32).map{it.toString()},
                "active_spans" to active.values.map{mapOf("id" to it.id,"stage" to it.name,"thread" to it.thread,"age_ms" to (SystemClock.elapsedRealtimeNanos()-it.start)/1e6)}))
        }
    }
}
