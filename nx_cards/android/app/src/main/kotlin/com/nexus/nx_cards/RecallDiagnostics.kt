package com.nexus.nx_cards

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.MotionEvent
import java.util.concurrent.atomic.AtomicBoolean

/** Bounded diagnostics: no card text, audio, pen coordinates, or per-move logging. */
internal object RecallDiagnostics {
    private val main = Handler(Looper.getMainLooper())
    private val pending = AtomicBoolean(false)
    private val asyncPending = AtomicBoolean(false)
    private val asyncMain = if (android.os.Build.VERSION.SDK_INT >= 28)
        Handler.createAsync(Looper.getMainLooper()) else main
    @Volatile private var asyncPostedAt = 0L
    @Volatile private var screen = "background"
    @Volatile private var postedAt = 0L
    private var started = false
    private var gestures = 0
    private var lastSlowInput = 0L
    @Volatile var systemAnrGeneration = 0L
        private set
    @Volatile var systemAnrAt = 0L
        private set
    private var anrObserverStarted = false

    @Synchronized fun observeSystemErrors(context: android.content.Context) {
        if (anrObserverStarted) return
        anrObserverStarted = true
        val manager = context.applicationContext.getSystemService(android.content.Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        Thread({
            var previous: String? = null
            while (true) {
                Thread.sleep(2000)
                if (screen != "drawing") continue
                runCatching {
                    val error = manager.processesInErrorState?.firstOrNull {
                        it.pid == android.os.Process.myPid() &&
                            it.condition == android.app.ActivityManager.ProcessErrorStateInfo.NOT_RESPONDING
                    }
                    val signature = error?.shortMsg
                    if (signature != null && signature != previous) {
                        systemAnrAt = SystemClock.uptimeMillis()
                        systemAnrGeneration++
                        InputFlightRecorder.event("system_anr generation=$systemAnrGeneration reason=$signature")
                        InputFlightRecorder.incident("system_anr")
                    }
                    previous = signature
                }.onFailure { Log.w("NxCardsPerf", "System ANR status unavailable", it) }
            }
        }, "CardsAnrStatus").apply { isDaemon = true; start() }
    }

    @Synchronized fun foreground(name: String) {
        screen = name
        Log.i("NxCardsPerf", "foreground=$name uptime_ms=${SystemClock.uptimeMillis()}")
        if (started) return
        started = true
        Thread({
            var reports = 0
            while (true) {
                Thread.sleep(500)
                if (screen == "background") continue
                if (asyncPending.compareAndSet(false, true)) {
                    asyncPostedAt = SystemClock.uptimeMillis()
                    asyncMain.post {
                        try {
                            InputFlightRecorder.sample(
                                if (pending.get()) SystemClock.uptimeMillis() - postedAt else 0,
                                SystemClock.uptimeMillis() - asyncPostedAt
                            )
                        } catch (e: Exception) { Log.w("NxCardsPerf", "Input sampling unavailable", e) }
                        finally { asyncPending.set(false) }
                    }
                }
                if (pending.compareAndSet(false, true)) {
                    reports = 0
                    postedAt = SystemClock.uptimeMillis()
                    main.post {
                        val delay = SystemClock.uptimeMillis() - postedAt
                        if (delay >= 250) Log.w("NxCardsPerf", "main_recovered screen=$screen delay_ms=$delay")
                        pending.set(false)
                    }
                } else {
                    val delay = SystemClock.uptimeMillis() - postedAt
                    if (delay >= 1000 && reports < 3) {
                        reports++
                        InputFlightRecorder.incident(if (asyncPending.get() && SystemClock.uptimeMillis() - asyncPostedAt >= 1000) "ui_thread_stall" else "synchronous_queue_stall")
                        val stack = Looper.getMainLooper().thread.stackTrace.take(28).joinToString("\n")
                        Log.w("NxCardsPerf", "main_stall screen=$screen delay_ms=$delay sample=$reports\n$stack")
                    }
                }
            }
        }, "NxCardsPerfWatchdog").apply { isDaemon = true; start() }
    }
    fun background(name: String) { if (screen == name) screen = "background" }

    fun <T> measure(stage: String, block: () -> T): T {
        val start = SystemClock.uptimeMillis()
        InputFlightRecorder.event("stage_begin=$stage")
        try { return block() } finally {
            val elapsed = SystemClock.uptimeMillis() - start
            InputFlightRecorder.event("stage=$stage elapsed_ms=$elapsed")
            Log.i("NxCardsPerf", "stage=$stage elapsed_ms=$elapsed")
        }
    }

    fun inputBegin(event: MotionEvent): Long {
        val start = SystemClock.uptimeMillis()
        val action = event.actionMasked
        InputFlightRecorder.input(action, event.getToolType(0), start - event.eventTime)
        if (action == MotionEvent.ACTION_DOWN) gestures++
        val boundary = action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL
        if (boundary) Log.i("NxCardsPerf", "input_begin gesture=$gestures action=$action tool=${event.getToolType(0)} queued_ms=${start - event.eventTime}")
        return start
    }
    fun inputEnd(event: MotionEvent, start: Long) {
        val elapsed = SystemClock.uptimeMillis() - start
        val action = event.actionMasked
        val boundary = action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL
        if (boundary || (elapsed >= 32 && start - lastSlowInput >= 1000)) {
            lastSlowInput = start
            InputFlightRecorder.event("input_end action=$action dispatch_ms=$elapsed")
            Log.i("NxCardsPerf", "input_end gesture=$gestures action=$action dispatch_ms=$elapsed")
        }
    }
}
