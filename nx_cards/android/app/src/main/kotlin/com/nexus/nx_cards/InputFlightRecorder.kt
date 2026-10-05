package com.nexus.nx_cards

import android.app.Activity
import android.os.SystemClock
import android.view.ViewTreeObserver
import java.io.File
import java.lang.ref.WeakReference
import java.util.ArrayDeque
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Passive recorder: never requests frames, consumes input, or changes ink state. */
internal object InputFlightRecorder {
    private val events = ArrayDeque<Pair<Long, String>>()
    private val writer = Executors.newSingleThreadExecutor { Thread(it, "CardsInputRecorder").apply { isDaemon = true } }
    private val writing = AtomicBoolean(false)
    private var activity = WeakReference<Activity>(null)
    private var directory: File? = null
    private var observer: ViewTreeObserver? = null
    private var drawListener: ViewTreeObserver.OnDrawListener? = null
    private var frames = 0L
    private var inputs = 0L
    private var lastInput = 0L
    private var lastFrame = 0L
    private var lastSample = 0L
    private var lastIncident = 0L
    private var state: (() -> String)? = null

    fun attach(owner: Activity, state: () -> String) {
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
        frames = 0; inputs = 0; lastInput = 0; lastFrame = 0
        runCatching {
            org.lsposed.hiddenapibypass.HiddenApiBypass.addHiddenApiExemptions(
                "Landroid/view/View;", "Landroid/view/ViewRootImpl;", "Landroid/view/InputEventReceiver;",
                "Landroid/view/BatchedInputEventReceiver;")
        }
        drawListener = ViewTreeObserver.OnDrawListener { frames++; lastFrame = SystemClock.uptimeMillis() }
        observer = owner.window.decorView.viewTreeObserver.also { it.addOnDrawListener(drawListener) }
        event("attach version=${owner.packageManager.getPackageInfo(owner.packageName, 0).longVersionCode}")
    }
    fun detach() {
        drawListener?.let { if (observer?.isAlive == true) observer?.removeOnDrawListener(it) }
        observer = null; drawListener = null; state = null; activity.clear()
        event("detach")
    }
    @Synchronized fun event(value: String) {
        val now = SystemClock.uptimeMillis()
        events.addLast(now to "$now $value")
        while (events.size > 2048 || (events.isNotEmpty() && now - events.first.first > 60000)) events.removeFirst()
    }
    fun input(action: Int, tool: Int, queued: Long) {
        inputs++; lastInput = SystemClock.uptimeMillis()
        if (action != 2) event("input action=$action tool=$tool queued_ms=$queued")
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
    fun sample() {
        val owner = activity.get() ?: return
        val now = SystemClock.uptimeMillis()
        if (now - lastSample < 2000) return
        lastSample = now
        var outstanding = 0
        val queue = runCatching {
            val root = android.view.View::class.java.getDeclaredMethod("getViewRootImpl").apply { isAccessible = true }.invoke(owner.window.decorView)
            val receiver = field(root, "mInputEventReceiver")
            outstanding = (field(receiver, "mSeqMap") as? android.util.SparseIntArray)?.size() ?: 0
            outstanding += (field(root, "mPendingInputEventCount") as? Int) ?: 0
            "pending=${field(root, "mPendingInputEventCount")} outstanding=$outstanding batched=${field(root, "mConsumeBatchedInputScheduled")} traversal=${field(root, "mTraversalScheduled")}"
        }.getOrElse { "queue_unavailable=${it.javaClass.simpleName}" }
        event("sample inputs=$inputs input_age=${now-lastInput} frames=$frames frame_age=${now-lastFrame} focused=${owner.hasWindowFocus()} ${state?.invoke()} $queue")
        if (outstanding > 0 && now-lastInput > 4000) incident("input_ack_stall")
        flush(false)
    }
    fun incident(reason: String) {
        val now = SystemClock.uptimeMillis()
        synchronized(this) {
            if (now-lastIncident < 15000) return
            lastIncident = now
        }
        event("incident=$reason main_stack=" + android.os.Looper.getMainLooper().thread.stackTrace.take(24).joinToString(" | "))
        flush(true)
    }
    private fun flush(incident: Boolean) {
        val dir = directory ?: return
        if (!writing.compareAndSet(false, true)) return
        val snapshot = synchronized(this) { "wall_ms=${System.currentTimeMillis()}\n" + events.joinToString("\n") { it.second } + "\n" }
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
