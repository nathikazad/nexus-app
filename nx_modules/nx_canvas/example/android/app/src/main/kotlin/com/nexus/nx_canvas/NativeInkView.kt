package com.nexus.nx_canvas

import android.content.Context
import android.graphics.*
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.util.UUID
import java.util.concurrent.ConcurrentLinkedQueue
import kotlin.math.roundToInt

/** Hosts the same firmware NoteView proven by NX Ink Test. No live rasterizer,
 * per-point bridge, polling, custom refresh mode or surface buffer copies.
 */
class NativeInkView(context: Context, messenger: BinaryMessenger, id: Int) : PlatformView {
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "nx_canvas/native/$id")
    private val host = FrameLayout(context)
    private var ink: RecordingNoteView? = null
    private var api: Class<*>? = null
    private var scene: Map<*, *>? = null
    private var renderedScene: Map<*, *>? = null
    private var renderedWidth = 0
    private var renderedHeight = 0
    private var stopped = false
    private var bitmap: Bitmap? = null
    private val pending = linkedMapOf<String, Map<String, Any>>()
    private val completed = ConcurrentLinkedQueue<Pair<Any, Transform>>()
    @Volatile private var transform = Transform(context.resources.displayMetrics.density.toDouble())
    private data class Transform(val density: Double, val zoom: Double = 1.0,
        val panX: Double = 0.0, val panY: Double = 0.0, val topInset: Double = 82.0)

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "scene" -> {
                        drainRecords()
                        scene = call.arguments as Map<*, *>
                        ensureWidget(context)
                        renderScene()
                        result.success(null)
                    }
                    "style" -> { applyStyle(call.arguments as Map<*, *>); result.success(null) }
                    "stop" -> {
                        stop()
                        // Includes unacknowledged deliveries, deduplicated in Dart.
                        result.success(pending.values.toList())
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                val cause = error.cause ?: error
                Log.e("NxNoteView", "Widget bridge failed", cause)
                result.error("native_ink", cause.toString(), null)
            }
        }
        host.addOnLayoutChangeListener { _, l, t, r, b, ol, ot, or, ob ->
            if ((r-l != or-ol || b-t != ob-ot) && !stopped) {
                host.post { runCatching { renderScene() }.onFailure { fail(it) } }
            }
        }
    }

    private fun ensureWidget(context: Context) {
        if (ink != null) return
        api = Class.forName("com.xrz.NoteView")
        val widget = RecordingNoteView(context)
        ink = widget
        widget.onRecord = { record ->
            // The record's point list is complete and owned by the firmware.
            // Enqueue a reference; reflection/serialization happen off its draw thread.
            completed.add(Pair(record, transform))
            main.post { drainRecords() }
        }
        host.addView(widget, FrameLayout.LayoutParams(-1, -1))
        widget.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
            if (!stopped) widget.post { runCatching { renderScene() }.onFailure { fail(it) } }
        }
        flag("setInputEnabled", true)
        Log.i("NxNoteView", "Stock NoteView loaded; completed-record hook only")
    }

    private fun flag(name: String, enabled: Boolean) {
        ink?.let { api!!.getMethod(name, Boolean::class.javaPrimitiveType).invoke(it, enabled) }
    }
    private fun number(map: Map<*, *>, key: String, default: Double) =
        (map[key] as? Number)?.toDouble() ?: default

    private fun drainRecords() {
        while (true) {
            val (record, view) = completed.poll() ?: break
            try {
                val cls = record.javaClass
                // Clear/eraser records must never turn into new pen strokes.
                if (cls.getField("type").getInt(record) != 101) {
                    Log.w("NxNoteView", "Non-pen record ignored: ${cls.name}; use Canvas eraser")
                    continue
                }
                val maxPressure = (cls.getField("maxPressure").get(record) as Number).toDouble()
                val minPressure = (cls.getField("minPressure").get(record) as Number).toDouble()
                val pts = cls.getField("points").get(record) as List<*>
                val points = pts.filterNotNull().map { p ->
                    val pc = p.javaClass
                    val x = (pc.getMethod("getX").invoke(p) as Number).toDouble()
                    val y = (pc.getMethod("getY").invoke(p) as Number).toDouble()
                    val pressure = (pc.getMethod("getPressure").invoke(p) as Number).toDouble()
                    val normalized = if (maxPressure > minPressure)
                        ((pressure-minPressure)/(maxPressure-minPressure)).coerceIn(.1, 1.0) else 1.0
                    listOf((x/view.density-view.panX)/view.zoom,
                        (y/view.density+view.topInset-view.panY)/view.zoom, normalized)
                }
                if (points.isEmpty()) continue
                val token = UUID.randomUUID().toString()
                val payload = mapOf<String, Any>("id" to token, "points" to points,
                    "color" to (cls.getField("color").getInt(record).toLong() and 0xffffffffL),
                    "width" to (cls.getField("strokeWidth").getInt(record)/view.density/view.zoom))
                pending[token] = payload
                channel.invokeMethod("stroke", payload, object : MethodChannel.Result {
                    override fun success(result: Any?) { pending.remove(token) }
                    override fun error(code: String, message: String?, details: Any?) {
                        Log.e("NxNoteView", "Stroke delivery failed: $message")
                    }
                    override fun notImplemented() {}
                })
                Log.i("NxNoteView", "Saved native record: ${points.size} points")
            } catch (error: Throwable) { fail(error) }
        }
    }

    private fun applyStyle(state: Map<*, *>) {
        val widget = ink ?: return
        val pen = api!!.getMethod("getPen").invoke(widget)
        val view = transform
        val width = (number(state, "width", 3.0)*view.density*view.zoom).roundToInt().coerceAtLeast(1)
        pen.javaClass.getMethod("setStrokeWidth", Int::class.javaPrimitiveType).invoke(pen, width)
        // Preserve the stock pure-black paint. Applying the palette's graphite
        // color caused the measured latency regression on this e-ink tablet.
    }

    private fun renderScene() {
        val state = scene ?: return
        val widget = ink ?: return
        val width = widget.width; val height = widget.height
        if (stopped || width <= 0 || height <= 0) return
        if (renderedScene === state && renderedWidth == width && renderedHeight == height) return
        val view = state["view"] as Map<*, *>
        val density = number(state, "density", transform.density)
        val topInset = number(state, "topInset", 82.0)
        val panX = number(view, "x", 0.0); val panY = number(view, "y", 0.0)
        val zoom = number(view, "scale", 1.0)
        transform = Transform(density, zoom, panX, panY, topInset)
        applyStyle(state)
        // Only for mounting, navigation, undo or edits. Never on a native stroke ACK.
        val previous = bitmap
        bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val base = Canvas(bitmap!!)
        base.drawColor(Color.rgb(248, 248, 243))
        base.save()
        base.translate((panX * density).toFloat(), ((panY - topInset) * density).toFloat())
        base.scale((density * zoom).toFloat(), (density * zoom).toFloat())
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { strokeCap = Paint.Cap.ROUND; style = Paint.Style.STROKE }
        for (item in state["strokes"] as? List<*> ?: emptyList<Any>()) {
            val stroke = item as Map<*, *>
            val pts = stroke["points"] as List<*>
            paint.color = (stroke["color"] as Number).toInt()
            val w = number(stroke, "width", 3.0).toFloat()
            var previous: List<*>? = null
            for (p in pts) {
                val point = p as List<*>
                val x = (point[0] as Number).toFloat(); val y = (point[1] as Number).toFloat()
                val prev = previous
                paint.strokeWidth = w * (.5f + ((point[2] as Number).toFloat() +
                    ((prev ?: point)[2] as Number).toFloat()) / 4)
                if (prev == null && pts.size == 1) base.drawPoint(x, y, paint)
                if (prev != null) base.drawLine((prev[0] as Number).toFloat(), (prev[1] as Number).toFloat(), x, y, paint)
                previous = point
            }
        }
        base.restore()
        api!!.getMethod("setForeground", Bitmap::class.java).invoke(widget, bitmap)
        // The widget has copied the foreground into its own buffers.
        previous?.recycle()
        renderedScene = state; renderedWidth = width; renderedHeight = height
        Log.i("NxNoteView", "Restored scene: ${(state["strokes"] as List<*>).size} strokes, scale=$zoom")
    }

    private fun fail(error: Throwable) {
        val cause = error.cause ?: error
        Log.e("NxNoteView", "Native ink unavailable", cause)
        runCatching { flag("setInputEnabled", false) }
        channel.invokeMethod("unavailable", cause.toString())
    }
    private fun stop() {
        if (!stopped) {
            stopped = true
            runCatching { flag("setInputEnabled", false) }
        }
        drainRecords()
    }
    override fun getView(): View = host
    override fun dispose() {
        stop()
        // Surface teardown is owned by NoteView. Keep the bridge briefly so the
        // Dart disposal flush can collect a pen-up already queued on its thread.
        main.postDelayed({
            drainRecords()
            ink?.onRecord = null
            channel.setMethodCallHandler(null)
            bitmap = null
        }, 1000)
    }
}
