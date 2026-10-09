package com.nexus.nx_cards

import android.app.Activity
import android.os.SystemClock
import android.view.ViewTreeObserver
import android.view.Choreographer
import java.io.File
import java.lang.ref.WeakReference
import java.util.ArrayDeque
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Bounded recorder. A single frame probe is requested only when work appears stuck. */
internal object InputFlightRecorder {
    private val events = ArrayDeque<Pair<Long, String>>()
    private val writer = Executors.newSingleThreadExecutor { Thread(it, "CardsInputRecorder").apply { isDaemon = true } }
    private val writing = AtomicBoolean(false)
    private var activity = WeakReference<Activity>(null)
    @Volatile private var directory: File? = null
    private var observer: ViewTreeObserver? = null
    private var drawListener: ViewTreeObserver.OnDrawListener? = null
    private var frames = 0L
    private var inputs = 0L
    private var moves = 0L
    private var maxQueued = 0L
    private var maxDispatch = 0L
    private var dispatchDepth = 0
    private var lastInput = 0L
    private var lastFrame = 0L
    private var lastSample = 0L
    private var lastIncident = 0L
    private var state: (() -> String)? = null
    private var onHealth: ((Boolean) -> Unit)? = null
    private var initialAnrGeneration = 0L
    private var frameProbeAt: Long? = null
    private var frameProbe: Choreographer.FrameCallback? = null

    fun attach(owner: Activity, health: (Boolean) -> Unit, state: () -> String) {
        detach()
        activity = WeakReference(owner)
        directory = File(owner.getExternalFilesDir(null) ?: owner.filesDir, "input-diagnostics")
        val dir = directory!!
        writer.execute {
            runCatching {
                val recent = File(dir, "recent.txt")
                if (recent.exists()) recent.copyTo(File(dir, "previous-session.txt"), overwrite = true)
            }
        }
        this.state = state
        onHealth = health
        lastSample = 0
        initialAnrGeneration = RecallDiagnostics.systemAnrGeneration
        RecallDiagnostics.observeSystemErrors(owner.applicationContext)
        frames = 0; inputs = 0; moves = 0; maxQueued = 0; maxDispatch = 0; dispatchDepth = 0; lastInput = 0; lastFrame = 0
        runCatching {
            org.lsposed.hiddenapibypass.HiddenApiBypass.addHiddenApiExemptions(
                "Landroid/view/View;", "Landroid/view/ViewRootImpl;", "Landroid/view/InputEventReceiver;",
                "Landroid/view/BatchedInputEventReceiver;")
        }
        drawListener = ViewTreeObserver.OnDrawListener { frames++; lastFrame = SystemClock.uptimeMillis() }
        observer = owner.window.decorView.viewTreeObserver.also { it.addOnDrawListener(drawListener) }
        event("attach pid=${android.os.Process.myPid()} activity=${System.identityHashCode(owner)} version=${owner.packageManager.getPackageInfo(owner.packageName, 0).longVersionCode}")
    }
    fun detach() {
        drawListener?.let { if (observer?.isAlive == true) observer?.removeOnDrawListener(it) }
        frameProbe?.let { Choreographer.getInstance().removeFrameCallback(it) }
        frameProbe = null; frameProbeAt = null; onHealth = null
        observer = null; drawListener = null; state = null; activity.clear()
        event("detach")
    }
    @Synchronized fun event(value: String) {
        val now = SystemClock.uptimeMillis()
        events.addLast(now to "$now $value")
        while (events.size > 2048 || (events.isNotEmpty() && now - events.first.first > 60000)) events.removeFirst()
    }
    fun input(action: Int, tool: Int, queued: Long) {
        inputs++; dispatchDepth++; lastInput = SystemClock.uptimeMillis()
        if (action == 2) moves++
        maxQueued = maxOf(maxQueued, queued)
        if (action != 2) event("input action=$action tool=$tool queued_ms=$queued")
    }
    fun inputFinished(elapsed: Long) {
        dispatchDepth = (dispatchDepth - 1).coerceAtLeast(0)
        maxDispatch = maxOf(maxDispatch, elapsed)
    }
    private fun field(target: Any?, name: String): Any? {
        var type: Class<*>? = target?.javaClass
        while (type != null) {
            try { return type.getDeclaredField(name).apply { isAccessible = true }.get(target) }
            catch (_: NoSuchFieldException) { type = type.superclass }
        }
        return null
    }
    /** Called on the UI heartbeat, independently of vsync/input delivery. */
    fun sample(syncDelay: Long, asyncDelay: Long) {
        val owner = activity.get() ?: return
        val now = SystemClock.uptimeMillis()
        if (now - lastSample < 2000) return
        lastSample = now
        var outstanding = 0
        var batched = false
        val queue = runCatching {
            val root = android.view.View::class.java.getDeclaredMethod("getViewRootImpl").apply { isAccessible = true }.invoke(owner.window.decorView)
            val receiver = field(root, "mInputEventReceiver")
            outstanding = (field(receiver, "mSeqMap") as? android.util.SparseIntArray)?.size() ?: 0
            outstanding += (field(root, "mPendingInputEventCount") as? Int) ?: 0
            batched = field(root, "mConsumeBatchedInputScheduled") == true
            "pending=${field(root, "mPendingInputEventCount")} outstanding=$outstanding batched=${field(root, "mConsumeBatchedInputScheduled")} traversal=${field(root, "mTraversalScheduled")} receiver=${receiver?.javaClass?.simpleName} receiver_batched=${field(receiver, "mBatchedInputScheduled")} stopped=${field(root, "mStopped")}"
        }.getOrElse { "queue_unavailable=${it.javaClass.simpleName}" }
        val evidence = InputStallEvidence(owner.hasWindowFocus(), outstanding, batched,
            now - lastInput, syncDelay, 0,
            RecallDiagnostics.systemAnrGeneration > initialAnrGeneration && lastInput < RecallDiagnostics.systemAnrAt)
        val suspect = evidence.needsFrameProbe
        if (suspect && frameProbe == null) {
            frameProbeAt = now
            frameProbe = Choreographer.FrameCallback {
                event("frame_probe_complete delay_ms=${SystemClock.uptimeMillis() - (frameProbeAt ?: now)}")
                frameProbeAt = null; frameProbe = null
            }.also { Choreographer.getInstance().postFrameCallback(it) }
        } else if (!suspect && frameProbe != null) {
            Choreographer.getInstance().removeFrameCallback(frameProbe!!)
            frameProbeAt = null; frameProbe = null
        }
        val frameDelay = frameProbeAt?.let { now - it } ?: 0
        val systemAnr = evidence.newSystemAnr
        val blocked = evidence.copy(frameProbeDelay = frameDelay).blocked
        event("heartbeat sync_delay_ms=$syncDelay async_delay_ms=$asyncDelay frame_probe_ms=$frameDelay system_anr=$systemAnr")
        event("sample inputs=$inputs moves=$moves dispatch_depth=$dispatchDepth max_queue_ms=$maxQueued max_dispatch_ms=$maxDispatch input_age=${now-lastInput} frames=$frames frame_age=${now-lastFrame} focused=${owner.hasWindowFocus()} ${state?.invoke()} $queue")
        maxQueued = 0; maxDispatch = 0
        if (systemAnr && !owner.hasWindowFocus()) event("recovery_deferred=window_not_focused system_anr=true")
        if (blocked) incident("input_or_frame_stall")
        flush(false)
        onHealth?.invoke(blocked)
    }
    fun incident(reason: String, force: Boolean = false) {
        val now = SystemClock.uptimeMillis()
        synchronized(this) {
            if (!force && now-lastIncident < 15000) return
            lastIncident = now
        }
        event("incident=$reason main_stack=" + android.os.Looper.getMainLooper().thread.stackTrace.take(24).joinToString(" | "))
        Thread.getAllStackTraces().entries.filter { (thread, _) ->
            thread.name == "main" || thread.name.startsWith("Binder:") ||
                thread.name.contains("raster") || thread.name.contains("RenderThread") ||
                thread.name.contains("hwui")
        }.take(8).forEach { (thread, stack) ->
            event("thread=${thread.name} state=${thread.state} stack=" + stack.take(24).joinToString(" | "))
        }
        flush(true)
    }
    private fun flush(incident: Boolean) {
        val dir = directory ?: return
        if (!incident && !writing.compareAndSet(false, true)) return
        if (incident) writing.set(true)
        val snapshot = synchronized(this) { "pid=${android.os.Process.myPid()} wall_ms=${System.currentTimeMillis()} uptime_ms=${SystemClock.uptimeMillis()} elapsed_ms=${SystemClock.elapsedRealtime()}\n" + events.joinToString("\n") { it.second } + "\n" }
        writer.execute {
            try {
                dir.mkdirs()
                val target = File(dir, if (incident) "incident-${System.currentTimeMillis()}.txt" else "recent.txt")
                val pending = File(dir, "pending.txt")
                pending.writeText(snapshot)
                pending.renameTo(target)
                dir.listFiles()?.filter { it.name.startsWith("incident-") }?.sortedByDescending { it.name }?.drop(5)?.forEach { it.delete() }
            } catch (e: Exception) { android.util.Log.w("NxCardsPerf", "Recorder write failed", e) }
            finally { writing.set(false) }
        }
    }
}
