package com.nexus.nx_canvas

/** Coalesces presentation-only work until handwriting has paused.
 * Never delays ink processing, durability, or navigation. Owner-thread API.
 */
class CanvasIdleUpdate(
    private val scheduler: CanvasScheduler,
    private val quietMs: Long = 300,
    private val update: () -> Unit,
) : AutoCloseable {
    private var penDown = false
    private var dirty = false
    private var closed = false
    private var timer: Cancellation? = null
    private var generation = 0L

    fun contact(down: Boolean) {
        if (closed) return
        penDown = down
        cancel()
        if (!down && dirty) schedule()
    }
    fun request() {
        if (closed) return
        dirty = true
        cancel()
        if (!penDown) schedule()
    }
    private fun cancel() { generation++; timer?.cancel(); timer = null }
    private fun schedule() {
        val expected = generation
        timer = scheduler.after(quietMs) {
            if (!closed && !penDown && dirty && generation == expected) {
                timer = null
                dirty = false
                update()
            }
        }
    }
    override fun close() { closed = true; dirty = false; cancel() }
}
