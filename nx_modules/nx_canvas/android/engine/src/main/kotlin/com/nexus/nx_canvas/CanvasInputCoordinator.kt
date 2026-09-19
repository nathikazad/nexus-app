package com.nexus.nx_canvas

/** Serial imports and explicit drain outcome; reconciles starts only after a confirmed firmware queue drain.
 * No timers, firmware classes, Android views, or disk access are hidden here.
 */
class CanvasInputCoordinator(
    private val engine: CanvasEngine,
    private val worker: CanvasExecutor,
    private val owner: CanvasExecutor,
    private val diagnostics: DiagnosticSink = NoCanvasDiagnostics,
    private val changed: () -> Unit,
    private val settled: () -> Unit,
    private val failed: (Throwable) -> Unit,
    private val imported: (InkOperationKind) -> Unit = {},
) {
    private val gate = InkDrainGate()
    private var boundarySequence = 0L
    private val queue = java.util.ArrayDeque<Pair<CanvasInputRecord, InputTransform>>()
    var pendingImports = 0; private set
    var importFailed = false; private set
    private var importing = false
    private var closed = false
    private var drained: (() -> Unit)? = null
    val penPending get() = gate.pending
    fun drain() = if (gate.pending || pendingImports > 0 || importFailed) DrainResult.Unresolved else DrainResult.Complete
    fun accept(event: InputEvent, transform: InputTransform) {
        if (closed) return
        when (event) {
            is InputEvent.Down -> { boundarySequence = event.sequence; gate.begin() }
            is InputEvent.Up -> { boundarySequence = event.sequence; gate.end(); settled() }
            is InputEvent.Quiescent -> {
                if(event.through >= boundarySequence) {
                    gate.reconcileReleased()
                    settled()
                }
            }
            InputEvent.Cancelled -> { gate.cancel(); settled() }
            is InputEvent.Completed -> {
                if (event.record.completesStroke) gate.complete()
                pendingImports++
                queue.add(event.record to transform)
                next()
            }
        }
    }
    private fun next() {
        if (importing || importFailed || queue.isEmpty()) return
        importing = true
        val (record, transform) = queue.first
        val before = engine.snapshot()
        worker.execute {
            val result = runCatching {
                diagnostics.measure("stroke.import") {
                    val operation = diagnostics.measure("stroke.decode") { record.decode(transform) }
                    operation?.let { diagnostics.measure("stroke.apply") { it.kind to before.drawing.model().also(it::apply).strokes } }
                }
            }
            owner.execute {
                try {
                    val applied=result.getOrThrow()
                    val strokes=applied?.second
                    strokes?.let { engine.dispatch(CanvasCommand.ReplaceInk(it)) }
                    queue.removeFirst();pendingImports--
                    if(strokes!=null) { changed(); imported(applied.first) }
                } catch (error: Throwable) { importFailed = true; failed(error) }
                finally { importing = false; next(); settled(); if(pendingImports == 0)drained?.invoke() }
            }
        }
    }
    fun retry() { if(!closed && importFailed){importFailed=false;next()} }
    fun close(done: () -> Unit = {}) { closed = true; drained = done; if(pendingImports == 0)done() }
}
