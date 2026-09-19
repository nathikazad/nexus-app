package com.nexus.nx_canvas

import android.content.Context
import android.graphics.Canvas
import com.xrz.FlushInfo
import com.xrz.NoteView
import com.xrz.PenPoint
import java.util.LinkedList

/** The stock widget still owns every live point and display refresh. This hook
 * only forwards completed records, after the firmware has drawn the batch.
 */
class RecordingNoteView(context: Context, private val diagnostics: DiagnosticSink = CanvasDiagnostics) : NoteView(context) {
    private val progress = InkInputProgress()
    fun admitNewStrokes(enabled: Boolean) = progress.admitNewStrokes(enabled)
    fun isDrained() = progress.isDrained()
    override fun onInputTouch(action: Int, x: Int, y: Int, pressure: Int, tool: Int): Int {
        // Direct firmware path: no queue, scheduler, packet copies or synthetic edges.
        // A transition can refuse a new stroke, but must never swallow the real up.
        if (!progress.acceptsInput()) return 0
        return super.onInputTouch(action, x, y, pressure, tool)
    }
    @Volatile var onStrokeBoundary:((Boolean,Long)->Unit)?=null
    @Volatile var onQuiescent:((Long)->Unit)?=null

    override fun onInputPoint(point:PenPoint) {
        super.onInputPoint(point)
        // Firmware input bypasses Activity touch dispatch. Only stroke edges
        // cross this hook; no points, rendering or IO are sent to Flutter.
        val boundary = if(point.toolType==2)null else when(point.eventType) {
            1 -> if(!point.isOutside)true else null
            3 -> false
            else -> null
        }
        val sequence = progress.submit(boundary)
        if(boundary != null) {
            onStrokeBoundary?.invoke(boundary,sequence)
        }
    }
    @Volatile var onRecord: ((Any) -> Unit)? = null

    override fun onDraw(canvases: Array<Canvas>, points: LinkedList<*>): FlushInfo? {
        val records = getRecordList() as LinkedList<*>
        val before = records.peekLast()
        val batchPoints=points.size
        val flush = super.onDraw(canvases, points)
        if (records.peekLast() !== before) {
            val added = mutableListOf<Any>()
            val iterator = records.descendingIterator()
            while (iterator.hasNext()) {
                val record = iterator.next() ?: continue
                if (record === before) break
                added.add(record)
            }
            for (record in added.asReversed()) onRecord?.invoke(record)
        }
        progress.processed(batchPoints)?.let { onQuiescent?.invoke(it) }
        return flush
    }
}
