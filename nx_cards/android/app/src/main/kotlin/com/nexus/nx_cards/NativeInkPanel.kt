package com.nexus.nx_cards

import android.content.Context
import android.graphics.*
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.LinearLayout
import android.widget.Button
import android.view.Gravity
import android.graphics.drawable.GradientDrawable
import java.util.IdentityHashMap
import kotlin.math.roundToInt

/** The tablet firmware owns all live pen samples and screen refreshes. Flutter
 * reads records only for toolbar/layout actions. No drawing-thread hooks or
 * live messages cross into Flutter. */
class NativeInkPanel(context: Context, private val onError: (Throwable) -> Unit) {
    private val main = Handler(Looper.getMainLooper())
    private val host = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        background = GradientDrawable().apply { setColor(Color.WHITE); setStroke(1, Color.LTGRAY); cornerRadius = 16 * context.resources.displayMetrics.density }
    }
    private val density = context.resources.displayMetrics.density.toDouble()
    private var ink: View? = null
    private var api: Class<*>? = null
    private val seen = IdentityHashMap<Any, Boolean>()
    private val strokes = mutableListOf<List<List<Double>>>()
    private var stopped = false
    private var started = false
    private var resumed = true
    private var busy = false
    private var foreground: Bitmap? = null

    init { start(context) }
    private fun start(context: Context) {
        if (started || stopped) return
        api = Class.forName("com.xrz.NoteView")
        val widget = api!!.getConstructor(Context::class.java).newInstance(context) as View
        ink = widget
        val toolbar = LinearLayout(context).apply { gravity = Gravity.END }
        for ((label, command) in listOf("Undo" to "undo", "Erase" to "clear")) {
            val button = Button(context).apply {
                text = label; contentDescription = label; isAllCaps = false; textSize = 13f
                setTextColor(Color.BLACK)
                setOnClickListener { if (!busy && !stopped) runCatching { edit(command) }.onFailure { fail(it) } }
            }
            toolbar.addView(button, LinearLayout.LayoutParams((72*density).roundToInt(), (48*density).roundToInt()))
        }
        host.addView(toolbar, LinearLayout.LayoutParams(-1, (48*density).roundToInt()))
        host.addView(widget, LinearLayout.LayoutParams(-1, 0, 1f))
        widget.addOnLayoutChangeListener { _, l, t, r, b, ol, ot, or, ob ->
            if ((r-l != or-ol || b-t != ob-ot) && !stopped) {
                widget.post { if (!stopped) runCatching { capture(); render() }.onFailure { fail(it) } }
            }
        }
        started = true
        Log.i("NxCardsInk", "Stock native pen mounted; no live Flutter callbacks")
    }
    private fun flag(enabled: Boolean) {
        ink?.let { api!!.getMethod("setInputEnabled", Boolean::class.javaPrimitiveType).invoke(it, enabled) }
    }
    fun setResumed(value: Boolean) {
        resumed = value
        runCatching { flag(value && started && !busy && !stopped) }.onFailure { fail(it) }
    }
    private fun rotation() = api!!.getMethod("getAbsoluteRotation").invoke(ink) as Int
    private fun local(x: Double, y: Double, rotation: Int): List<Double> {
        val w = ink!!.width.toDouble(); val h = ink!!.height.toDouble()
        val p = when (rotation) {
            90 -> listOf(y, h-x)
            180 -> listOf(w-x, h-y)
            270 -> listOf(w-y, x)
            else -> listOf(x, y)
        }
        return p.map { it / density }
    }
    private fun capture() {

        val records = api!!.getMethod("getRecordList").invoke(ink) as List<*>
        for (record in records.filterNotNull()) {
            if (seen.put(record, true) != null) continue
            val cls = record.javaClass
            if (cls.getField("type").getInt(record) != 101) continue
            val rotation = rotation()
            val points = (cls.getField("points").get(record) as List<*>).filterNotNull().map { p ->
                local((p.javaClass.getMethod("getX").invoke(p) as Number).toDouble(),
                    (p.javaClass.getMethod("getY").invoke(p) as Number).toDouble(), rotation)
            }
            if (points.isNotEmpty()) { strokes.add(points) }
        }

    }
    private fun edit(command: String, complete: (() -> Unit)? = null) {
        if (stopped) { complete?.invoke(); return }
        if (busy) { main.postDelayed({ edit(command, complete) }, 110); return }
        busy = true
        flag(false)
        api?.getMethod("finishPen")?.invoke(ink)
        // Finish the vendor's queued pen-up before undo/erase, including a
        // stroke completed immediately before the toolbar tap.
        main.postDelayed({
            try {
                if (!stopped) {
                    capture()
                    if (command == "clear") strokes.clear()
                    else if (strokes.isNotEmpty()) strokes.removeAt(strokes.lastIndex)
                    render()
                }
                complete?.invoke()
            } catch (e: Throwable) { fail(e) }
            finally { busy = false; if (!stopped) setResumed(resumed) }
        }, 100)
    }
    private fun render() {
        val widget = ink ?: return
        val w = widget.width; val h = widget.height
        if (w <= 0 || h <= 0 || stopped) return
        flag(false)
        val rotation = rotation()
        val image = Bitmap.createBitmap(if (rotation % 180 == 0) w else h,
            if (rotation % 180 == 0) h else w, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(image)
        canvas.drawColor(Color.WHITE)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.BLACK; strokeWidth = (3*density).toFloat()
            strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND; style = Paint.Style.STROKE
        }
        fun panel(p: List<Double>): PointF {
            val x = p[0]*density; val y = p[1]*density
            return when(rotation) {
                90 -> PointF((h-y).toFloat(), x.toFloat())
                180 -> PointF((w-x).toFloat(), (h-y).toFloat())
                270 -> PointF(y.toFloat(), (w-x).toFloat())
                else -> PointF(x.toFloat(), y.toFloat())
            }
        }
        for (stroke in strokes) {
            val pts = stroke.map(::panel)
            if (pts.size == 1) canvas.drawPoint(pts[0].x, pts[0].y, paint)
            for (i in 1 until pts.size) canvas.drawLine(pts[i-1].x, pts[i-1].y, pts[i].x, pts[i].y, paint)
        }
        val penClass = Class.forName("com.xrz.SimplePen")
        val pen = penClass.getConstructor().newInstance()
        penClass.getMethod("setStrokeWidth", Int::class.javaPrimitiveType).invoke(pen, (3*density).roundToInt())
        api!!.getMethod("setPen", Class.forName("com.xrz.BasePen")).invoke(widget, pen)
        api!!.getMethod("setDrawGroundMode", Int::class.javaPrimitiveType).invoke(widget, 0)
        api!!.getMethod("resetRecordList").invoke(widget)
        seen.clear()
        api!!.getMethod("setForeground", Bitmap::class.java).invoke(widget, image)
        foreground = image
        flag(resumed && !busy)
    }
    private fun fail(error: Throwable) {
        Log.e("NxCardsInk", "Native ink unavailable", error)
        runCatching { flag(false) }
        onError(error)
    }
    private fun stop() { stopped = true; flag(false) }
    fun getView(): View = host
    fun clear(complete: () -> Unit) = edit("clear", complete)
    fun dispose() {
        runCatching { stop() }
        seen.clear()
        foreground = null
    }
}
