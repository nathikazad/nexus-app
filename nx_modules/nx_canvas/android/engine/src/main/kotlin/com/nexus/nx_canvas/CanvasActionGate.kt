package com.nexus.nx_canvas

/** Owns waiting command lifetime. Timeout does not discard unconfirmed ink. */
class CanvasActionGate(private val input: () -> DrainResult, private val scheduler: CanvasScheduler, private val shouldTimeout: () -> Boolean = {true}) {
    private var waiting: (() -> Unit)? = null
    private var timeout: Cancellation? = null
    val busy get() = waiting != null
    fun submit(action: () -> Unit, unresolved: () -> Unit) {
        check(!busy) { "An action is already waiting" }
        waiting = action
        if (shouldTimeout() && input() == DrainResult.Unresolved) timeout = scheduler.after(250) {
            if (waiting != null && input() == DrainResult.Unresolved) { waiting = null; timeout = null; unresolved() }
        }
        drain()
    }
    fun drain() {
        if (input() != DrainResult.Complete) return
        val action = waiting ?: return
        waiting = null; timeout?.cancel(); timeout = null
        action()
    }
    fun cancel() { waiting = null; timeout?.cancel(); timeout = null }
    fun close() = cancel()
}
