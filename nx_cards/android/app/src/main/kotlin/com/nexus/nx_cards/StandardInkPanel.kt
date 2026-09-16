package com.nexus.nx_cards

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.view.MotionEvent
import android.view.View
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout

/** Native Android fallback for devices without the tablet firmware pen. */
class StandardInkPanel(context: Context) : LinearLayout(context) {
    private val drawing = Drawing(context)
    init {
        orientation = VERTICAL
        setBackgroundColor(Color.WHITE)
        val toolbar = LinearLayout(context).apply { gravity = Gravity.END }
        for (label in listOf("Undo", "Erase")) toolbar.addView(Button(context).apply {
            text = label; isAllCaps = false; setTextColor(Color.BLACK)
            setOnClickListener { if (label == "Erase") drawing.clear() else drawing.undo() }
        })
        addView(toolbar, LayoutParams(-1, -2))
        addView(drawing, LayoutParams(-1, 0, 1f))
    }
    fun clear() = drawing.clear()
    private class Drawing(context: Context) : View(context) {
        private val paths = mutableListOf<Path>()
        private var active = false
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.BLACK; strokeWidth = 3 * resources.displayMetrics.density
            style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
        }
        fun clear() { active = false; paths.clear(); invalidate() }
        fun undo() { active = false; if (paths.isNotEmpty()) paths.removeAt(paths.lastIndex); invalidate() }
        override fun onDraw(canvas: Canvas) { super.onDraw(canvas); paths.forEach { canvas.drawPath(it, paint) } }
        override fun onTouchEvent(event: MotionEvent): Boolean {
            when(event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    parent.requestDisallowInterceptTouchEvent(true)
                    paths.add(Path().apply { moveTo(event.x, event.y); lineTo(event.x + .01f, event.y + .01f) }); active = true
                }
                MotionEvent.ACTION_MOVE -> if (active) {
                    for (i in 0 until event.historySize) paths.last().lineTo(event.getHistoricalX(i), event.getHistoricalY(i))
                    paths.last().lineTo(event.x, event.y)
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> { active = false; parent.requestDisallowInterceptTouchEvent(false) }
            }
            invalidate(); return true
        }
    }
}
