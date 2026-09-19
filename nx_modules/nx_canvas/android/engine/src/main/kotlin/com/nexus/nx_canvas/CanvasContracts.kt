package com.nexus.nx_canvas

/** Ports are platform independent. Callbacks return to the owning session scheduler. */
fun interface CanvasExecutor { fun execute(work: () -> Unit) }
interface CanvasScheduler : CanvasExecutor {
    fun after(milliseconds: Long, work: () -> Unit): Cancellation
}
fun interface Cancellation { fun cancel() }
data class CanvasRevision(val session: String, val number: Long, val drawing: InkSnapshot)
data class CanvasRecovery(val session: String, val title: String, val drawing: InkSnapshot, val token: String)
interface CanvasRecoveryStore {
    fun save(session: String, title: String, drawing: InkSnapshot, token: String)
    fun recover(): CanvasRecovery?
    fun acknowledge(token: String): Boolean
}
interface CanvasFrame { fun release() }
data class CanvasRenderRequest(val revision: CanvasRevision, val density: Double, val width: Int, val height: Int, val rotation: Int)
interface CanvasRenderer<F : CanvasFrame> : AutoCloseable {
    fun render(request: CanvasRenderRequest, reusable: F?): F
}
interface DiagnosticSpan { fun end(fields: Map<String, Any?> = emptyMap()) }
interface DiagnosticSink {
    fun event(name: String, fields: Map<String, Any?> = emptyMap())
    fun begin(name: String, fields: Map<String, Any?> = emptyMap()): DiagnosticSpan
}
object NoCanvasDiagnostics : DiagnosticSink {
    override fun event(name: String, fields: Map<String, Any?>) {}
    override fun begin(name: String, fields: Map<String, Any?>) = object : DiagnosticSpan { override fun end(fields: Map<String, Any?>) {} }
}
fun <T> DiagnosticSink.measure(name: String, fields: Map<String, Any?> = emptyMap(), work: () -> T): T {
    val span = begin(name, fields)
    try { return work() }
    catch(error: Throwable) { event("stage.error", mapOf("stage" to name, "error_type" to error.javaClass.name)); throw error }
    finally { span.end() }
}
/** The raw vendor record never crosses this interface. Decoding runs on the import worker. */
interface CanvasInputRecord {
    val completesStroke: Boolean
    fun decode(transform: InputTransform): InkOperation?
}
data class InputTransform(val view: InkViewport, val rotation: Int, val width: Int, val height: Int, val density: Double)
sealed class InputEvent {
    data class Down(val sequence: Long = 0) : InputEvent()
    data class Up(val sequence: Long = 0) : InputEvent()
    data class Quiescent(val through: Long) : InputEvent()
    object Cancelled : InputEvent()
    data class Completed(val record: CanvasInputRecord) : InputEvent()
}
sealed class DrainResult { object Complete : DrainResult(); object Unresolved : DrainResult() }
interface CanvasInput {
    var onEvent: ((InputEvent) -> Unit)?
    fun enable(enabled: Boolean)
    fun drain(done:(Boolean)->Unit)
    var onFault:((String)->Unit)?
    fun close()
}
enum class InkOperationKind { DRAW, ERASE_PATH, ERASE_REGION }

data class InkOperation(val kind: InkOperationKind, val stroke: NativeStroke) {
    fun apply(model: InkModel) {
        when(kind) {
            InkOperationKind.DRAW -> model.add(stroke)
            InkOperationKind.ERASE_PATH -> model.erase(stroke.points, stroke.width / 2)
            InkOperationKind.ERASE_REGION -> model.eraseRegion(stroke.points)
        }
    }
}
