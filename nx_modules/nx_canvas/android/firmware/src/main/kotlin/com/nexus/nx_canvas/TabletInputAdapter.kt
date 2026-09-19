package com.nexus.nx_canvas

import android.content.Context
import android.graphics.Bitmap
import android.view.SurfaceHolder
import kotlin.math.roundToInt

/** All vendor reflection and record identities are confined to this adapter. */
class TabletInputAdapter(context: Context, private val diagnostics: DiagnosticSink = CanvasDiagnostics) : AndroidCanvasInput {
    private val widget = RecordingNoteView(context, diagnostics)
    override val view: android.view.View get() = widget
    private val api = Class.forName("com.xrz.NoteView")
    private val seen = InkRecordSet()
    override var onEvent: ((InputEvent) -> Unit)? = null
    private val handler=android.os.Handler(android.os.Looper.getMainLooper())
    private val scheduler=object:CanvasScheduler {
        override fun execute(work:()->Unit) { if(android.os.Looper.myLooper()==handler.looper)work() else handler.post(work) }
        override fun after(milliseconds:Long,work:()->Unit):Cancellation {
            val task=Runnable(work);handler.postDelayed(task,milliseconds);return Cancellation{handler.removeCallbacks(task)}
        }
    }
    override var onFault:((String)->Unit)?=null
    private val lifecycle=CanvasInputLifecycle(object:CanvasFirmwarePort {
        override fun send(packet:CanvasPenPacket)=widget.sendPacket(packet)
        override fun isDrained()=widget.isDrained()
        override fun finishPendingStroke()=widget.finishPendingStroke()
        override fun changeTool(tool:CanvasPenTool)=applyPen(tool.tool,tool.width)
    },scheduler,diagnostics,{onFault?.invoke(it)})
    init {
        widget.onPacket={packet->scheduler.execute{lifecycle.submit(packet)}}
        widget.onStrokeBoundary = { down, sequence -> onEvent?.invoke(if(down) InputEvent.Down(sequence) else InputEvent.Up(sequence)) }
        widget.onQuiescent = { sequence -> scheduler.execute {
            onEvent?.invoke(InputEvent.Quiescent(sequence));lifecycle.progressed()
        } }
        widget.onRecord = { deliver(it) }
    }
    private fun deliver(raw: Any) {
        synchronized(seen) { if (!seen.add(raw)) return }
        val record = object : CanvasInputRecord {
            override val completesStroke = raw.javaClass.getField("type").getInt(raw) in listOf(101,201,202)
            override fun decode(transform: InputTransform) = diagnostics.measure("firmware.decode_record", mapOf(
                "record_class" to raw.javaClass.name, "record_type" to raw.javaClass.getField("type").getInt(raw))) {
                NativeStrokeCapture.decode(raw, transform)
            }
        }
        onEvent?.invoke(InputEvent.Completed(record))
    }
    override val rotation get() = api.getMethod("getAbsoluteRotation").invoke(view) as Int
    override val holder get() = api.getMethod("getHolder").invoke(view) as SurfaceHolder
    override fun enable(enabled: Boolean) {
        // Gate ingress, not NoteView: firmware must still accept the final up packet.
        lifecycle.enable(enabled)
    }
    override fun drain(done:(Boolean)->Unit)=lifecycle.drain { ok -> if(ok)capture();done(ok) }
    private fun capture() { diagnostics.measure("firmware.capture_records") { (api.getMethod("getRecordList").invoke(view) as List<*>).filterNotNull().forEach(::deliver) } }
    private fun resetRecords() { diagnostics.measure("firmware.resetRecordList") { api.getMethod("resetRecordList").invoke(view); synchronized(seen) { seen.clear() } } }
    override fun present(bitmap: Bitmap) {
        check(widget.isDrained()) { "Foreground replacement requires confirmed firmware drain" }
        diagnostics.measure("firmware.setDrawGroundMode") { api.getMethod("setDrawGroundMode", Int::class.javaPrimitiveType).invoke(view, 0) }
        resetRecords()
        diagnostics.measure("firmware.setForeground", mapOf("bitmap_bytes" to bitmap.allocationByteCount)) { api.getMethod("setForeground", Bitmap::class.java).invoke(view, bitmap) }
    }
    override fun setPen(tool: NativeTool, width: Double)=lifecycle.tool(CanvasPenTool(tool,width))
    private fun applyPen(tool: NativeTool, width: Double) {
        check(widget.isDrained()) { "Tool mutation requires confirmed firmware drain" }
        diagnostics.measure("firmware.setPen") {
            val cls = Class.forName(when(tool) { NativeTool.RUB -> "com.xrz.Rubber"; NativeTool.REGION -> "com.xrz.RegionRubber"; else -> "com.xrz.SimplePen" })
            val pen = cls.getConstructor().newInstance()
            cls.getMethod("setStrokeWidth", Int::class.javaPrimitiveType).invoke(pen, width.roundToInt().coerceAtLeast(1))
            api.getMethod("setPen", Class.forName("com.xrz.BasePen")).invoke(view, pen)
        }
    }
    override fun close() { lifecycle.close();widget.onPacket=null;onFault=null; onEvent = null; widget.onRecord = null; widget.onStrokeBoundary = null; widget.onQuiescent = null }
}
