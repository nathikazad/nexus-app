package com.nexus.nx_canvas

import android.content.Context
import android.graphics.Canvas
import com.xrz.FlushInfo
import com.xrz.NoteView
import java.util.LinkedList

/** The stock widget still owns every live point and display refresh. This hook
 * only forwards completed records, after the firmware has drawn the batch.
 */
class RecordingNoteView(context: Context) : NoteView(context) {
    @Volatile var onRecord: ((Any) -> Unit)? = null

    override fun onDraw(canvases: Array<Canvas>, points: LinkedList<*>): FlushInfo? {
        val records = getRecordList() as LinkedList<*>
        val before = records.peekLast()
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
        return flush
    }
}
