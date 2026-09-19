package com.nexus.nx_canvas

import android.content.Context
import android.os.Handler
import java.util.concurrent.Executors

class AndroidCanvasScheduler(private val handler: Handler) : CanvasScheduler {
    override fun execute(work: () -> Unit) {
        if (android.os.Looper.myLooper() == handler.looper) work() else handler.post(work)
    }
    override fun after(milliseconds: Long, work: () -> Unit): Cancellation {
        val task = Runnable(work); handler.postDelayed(task, milliseconds)
        return Cancellation { handler.removeCallbacks(task) }
    }
}
/** OS-created activity and Flutter plugin share this application-scoped repository.
 * All session state/queues belong to CanvasSessionResources, never this registry.
 */
class CanvasComponents(
    val input: (Context, DiagnosticSink) -> AndroidCanvasInput = { context, diagnostics -> TabletInputAdapter(context, diagnostics) },
    val renderer: (DiagnosticSink) -> CanvasRenderer<BitmapCanvasFrame> = { BitmapCanvasRenderer(InkMetrics(), it) },
    val overviewRenderer: CanvasOverviewRenderer = DefaultOverviewRenderer(),
    val diagnostics: DiagnosticSink = CanvasDiagnostics,
)
object CanvasServices {
    val components = CanvasComponents()
    private var repository: CanvasRepository? = null
    @Synchronized fun repository(context: Context): CanvasRepository = repository
        ?: CanvasRepository(context.applicationContext).also { repository = it }
}
/** Composition root. Replace ports here; neither the engine nor UI knows their internals. */
class CanvasSessionResources(
    engine: CanvasEngine, title: String, repository: CanvasRepository, scheduler: CanvasScheduler,
    components: CanvasComponents,
    changed: () -> Unit, settled: () -> Unit, failed: (Throwable) -> Unit,
    eligible: () -> Boolean, present: (BitmapCanvasFrame) -> Unit,
    renderSettled: () -> Unit, saveState: (CanvasSaveCoordinator.SaveState) -> Unit,
    diagnostics: DiagnosticSink = components.diagnostics,
    imported: (InkOperationKind) -> Unit = {},
) : AutoCloseable {
    private val importExecutor = Executors.newSingleThreadExecutor { Thread(it, "canvas-import") }
    private val renderExecutor = Executors.newSingleThreadExecutor { Thread(it, "canvas-render") }
    private val lease = repository.claim(engine.session)
    private var released = false
    val imports = CanvasInputCoordinator(engine, CanvasExecutor { importExecutor.execute(it) }, scheduler, diagnostics, changed, settled, failed, imported)
    val actions = CanvasActionGate({ imports.drain() }, scheduler, {imports.penPending})
    val renders = CanvasRenderCoordinator(components.renderer(diagnostics), CanvasExecutor { renderExecutor.execute(it) }, scheduler,
        {engine.snapshot()}, eligible, present, renderSettled, failed)
    val previews = CanvasPreviewCoordinator<CanvasOverviewPreview>(CanvasExecutor { renderExecutor.execute(it) }, scheduler,
        { it.image.recycle() }, failed)
    val saves = CanvasSaveCoordinator(engine.session, title, repository.journal(), CanvasExecutor { repository.io.execute(it) }, scheduler,
        {java.util.UUID.randomUUID().toString()}, diagnostics, saveState)
    fun releaseLease() { if (!released) { released = true; lease.close() } }
    override fun close() {
        actions.close(); previews.close(); renders.close(); renderExecutor.shutdown()
        imports.close { saves.close(); importExecutor.shutdown(); releaseLease() }
    }
}
