package com.nexus.nx_cards

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.view.MotionEvent
import android.view.View
import android.widget.LinearLayout

/** Native Android fallback for devices without the tablet firmware pen. */
class StandardInkPanel(context: Context) : LinearLayout(context) {
    private val drawing = Drawing(context)
    init {
        orientation = VERTICAL
        setBackgroundColor(Color.WHITE)
        addView(drawing, LayoutParams(-1, 0, 1f))
    }
    fun clear() = drawing.clear()
    fun undo() = drawing.undo()
    private class Drawing(context: Context) : View(context) {
        private data class Stroke(val path: Path, val erasing: Boolean)
        private val paths = mutableListOf<Stroke>()
        private var active = false
        private var lastX = 0f
        private var lastY = 0f
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.BLACK; strokeWidth = 3 * resources.displayMetrics.density
            style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
        }
        fun clear() { active = false; paths.clear(); invalidate() }
        fun undo() { active = false; if (paths.isNotEmpty()) paths.removeAt(paths.lastIndex); invalidate() }
        override fun onDraw(canvas: Canvas) { super.onDraw(canvas); paths.forEach {
            paint.color = if (it.erasing) Color.WHITE else Color.BLACK
            paint.strokeWidth = (if (it.erasing) 24 else 3) * resources.displayMetrics.density
            canvas.drawPath(it.path, paint)
        } }
        override fun onTouchEvent(event: MotionEvent): Boolean {
            when(event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    parent.requestDisallowInterceptTouchEvent(true)
                    paths.add(Stroke(Path().apply { moveTo(event.x, event.y); lineTo(event.x + .01f, event.y + .01f) }, StylusInput.erasing(event))); active = true
                }
                MotionEvent.ACTION_MOVE -> if (active) {
                    if (paths.last().erasing != StylusInput.erasing(event)) {
                        paths.add(Stroke(Path().apply { moveTo(lastX, lastY) }, StylusInput.erasing(event)))
                    }
                    for (i in 0 until event.historySize) paths.last().path.lineTo(event.getHistoricalX(i), event.getHistoricalY(i))
                    paths.last().path.lineTo(event.x, event.y)
                }
                MotionEvent.ACTION_UP -> {
                    if (active) paths.last().path.lineTo(event.x, event.y)
                    active = false; parent.requestDisallowInterceptTouchEvent(false)
                }
                MotionEvent.ACTION_CANCEL -> { active = false; parent.requestDisallowInterceptTouchEvent(false) }
            }
            lastX = event.x; lastY = event.y
            invalidate(); return true
        }
    }
}
