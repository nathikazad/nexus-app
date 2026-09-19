package com.nexus.nx_canvas

/** Owns the render queue and both frame leases. A presented frame is never reused
 * until its replacement is submitted. Obsolete frames never reach the display.
 */
class CanvasRenderCoordinator<F : CanvasFrame>(
    private val renderer: CanvasRenderer<F>, private val worker: CanvasExecutor,
    private val owner: CanvasExecutor, private val current: () -> CanvasRevision,
    private val eligible: () -> Boolean, private val present: (F) -> Unit,
    private val settled: () -> Unit, private val failed: (Throwable) -> Unit,
) {
    var rendering = false; private set
    private var closed = false
    private var next: CanvasRenderRequest? = null
    private var front: F? = null
    private var spare: F? = null
    fun request(request: CanvasRenderRequest) {
        if (closed) return
        if (rendering) { next = request; return }
        rendering = true
        val reusable = spare; spare = null
        worker.execute {
            val result = runCatching { renderer.render(request, reusable) }
            owner.execute {
                rendering = false
                if (closed) { result.getOrNull()?.release(); return@execute }
                val frame = result.getOrElse { failed(it); val pending = next; next = null; if(pending != null)request(pending) else settled(); return@execute }
                val pending = next; next = null
                if (pending != null || request.revision != current() || !eligible()) {
                    spare = frame
                    if (eligible()) request(pending ?: request.copy(revision = current())) else settled()
                    return@execute
                }
                try { present(frame); spare = front; front = frame }
                catch(error: Throwable) { frame.release(); failed(error) }
                settled()
            }
        }
    }
    /** Caller detaches the surface before releasing the displayed frame. */
    fun close() {
        closed = true; next = null
        front?.release(); front = null; spare?.release(); spare = null
        worker.execute { renderer.close() }
    }
}
