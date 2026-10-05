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
    @Volatile private var screen = "background"
    @Volatile private var postedAt = 0L
    private var started = false
    private var gestures = 0
    private var lastSlowInput = 0L

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
                if (pending.compareAndSet(false, true)) {
                    reports = 0
                    postedAt = SystemClock.uptimeMillis()
                    main.post {
                        val delay = SystemClock.uptimeMillis() - postedAt
                        if (delay >= 250) Log.w("NxCardsPerf", "main_recovered screen=$screen delay_ms=$delay")
                        try { InputFlightRecorder.sample() }
                        catch (e: Exception) { Log.w("NxCardsPerf", "Input sampling unavailable", e) }
                        finally { pending.set(false) }
                    }
                } else {
                    val delay = SystemClock.uptimeMillis() - postedAt
                    if (delay >= 1000 && reports < 3) {
                        reports++
                        InputFlightRecorder.incident("main_stall")
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
