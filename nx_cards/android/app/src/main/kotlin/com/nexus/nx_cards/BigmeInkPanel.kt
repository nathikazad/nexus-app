package com.nexus.nx_cards

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.os.Handler
import android.os.Build
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import java.lang.reflect.Proxy
import org.lsposed.hiddenapibypass.HiddenApiBypass
import kotlin.math.ceil
import kotlin.math.floor

/** XRZ/Bigme firmware adapter. API reference: https://github.com/imedwei/inksdk
 * Live segments go directly to the firmware canvas on its callback thread.
 * Android's surface is updated only after pen-up or a toolbar/lifecycle action.
 * XRZ-only hidden API access is enabled in this app process on Android 9+.
 * No firmware binaries or per-point Flutter calls.
 */
internal class BigmeInkPanel(
    context: Context,
    private val onFailure: (Throwable) -> Unit,
) : DrawingInkPanel, SurfaceHolder.Callback {
    private val view = SurfaceView(context)
    private val main = Handler(Looper.getMainLooper())
    private val lock = Any()
    private val history = InkStrokeHistory()
    private val density = context.resources.displayMetrics.density
    private val paint = Paint().apply {
        isAntiAlias = false
        color = Color.BLACK
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val dirty = Rect()
    @Volatile private var client: Firmware? = null
    @Volatile private var accepting = false
    @Volatile private var failed = false
    @Volatile private var closed = false
    private var resumed = true
    private var attaching = false
    private var surfaceReady = false
    private var connectedWidth = 0
    private var connectedHeight = 0
    private var lastRefresh = 0L
    private var firstSegment = true
    private var paintStarted = 0L

    init { view.holder.addCallback(this) }
    override fun getView(): View = view
    fun snapshot(): List<InkStroke> = synchronized(lock) { history.snapshot() }

    override fun surfaceCreated(holder: SurfaceHolder) { surfaceReady = true }
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        surfaceReady = true
        if (attaching || closed || failed) return
        if (client != null && width == connectedWidth && height == connectedHeight) return
        disconnect()
        if (resumed && width > 0 && height > 0) attach()
    }
    override fun surfaceDestroyed(holder: SurfaceHolder) { surfaceReady = false; disconnect() }

    private fun attach() {
        if (closed || failed || attaching || client != null || !surfaceReady ||
            !resumed || view.width <= 0 || view.height <= 0) return
        attaching = true
        var opened: Firmware? = null
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                check(HiddenApiBypass.addHiddenApiExemptions("Lcom/xrz/")) {
                    "Could not enable app-local XRZ firmware API access"
                }
            }
            opened = Firmware(view.context)
            val firmware = opened
            var loggedSamples = 0
            val listener = Proxy.newProxyInstance(firmware.listenerType.classLoader,
                arrayOf(firmware.listenerType)) { proxy, method, args ->
                when (method.name) {
                    "onInputTouch" -> {
                        if (args != null && args.size >= 5) {
                            if (loggedSamples++ < 8) Log.i(TAG,
                                "Firmware input=${args.take(5)}; accepting=$accepting; current=${client === firmware}")
                            try {
                                input(firmware, (args[0] as Number).toInt(),
                                    (args[1] as Number).toFloat(), (args[2] as Number).toFloat(),
                                    (args[4] as Number).toInt())
                            } catch (error: Throwable) { fail(error) }
                        }
                        0
                    }
                    "hashCode" -> System.identityHashCode(proxy)
                    "equals" -> proxy === args?.getOrNull(0)
                    "toString" -> "RecallBigmeInput"
                    else -> null
                }
            }
            firmware.bind(view, listener)
            check(firmware.connect(view.width, view.height)) { "Bigme handwriting service refused connection" }
            firmware.updateLayout()
            Log.i(TAG, "Firmware layout: ${firmware.layout()}")
            client = firmware
            connectedWidth = view.width; connectedHeight = view.height
            synchronized(lock) {
                checkNotNull(firmware.canvas()) { "Bigme handwriting canvas unavailable" }
                history.end()
                dirty.setEmpty()
            }
            // Supply a normal surface for screenshots, occlusion and UI composition.
            paintSurface()
            synchronized(lock) { repaintFirmware(firmware) }
            accepting = resumed
            firmware.enable(resumed)
            Log.i(TAG, "Renderer=bigme; connected ${view.width}x${view.height}; device=${android.os.Build.MODEL}")
        } catch (error: Throwable) {
            accepting = false
            client = null
            opened?.close()
            fail(error)
        } finally { attaching = false }
    }

    private fun input(source: Firmware, action: Int, x: Float, y: Float, tool: Int) {
        synchronized(lock) {
            if (!accepting || closed || failed || client !== source) return
            val firmware = client ?: return
            // Cooked callbacks are already view-local; converting again offsets strokes.
            // Firmware tools: 0 pen, 1 rubber, 2 finger. Ignore palm/finger input.
            if (tool != 0 && tool != 1) return
            val w = connectedWidth.toFloat(); val h = connectedHeight.toFloat()
            if (w <= 0 || h <= 0) return
            if (action == 4) { finishStroke(firmware); return }
            if (x < 0 || y < 0 || x >= w || y >= h) {
                finishStroke(firmware)
                return
            }
            when (action) {
                1 -> {
                    history.begin(x / w, y / h, tool == 1)
                    dirty.setEmpty(); firstSegment = true
                    paintStarted = SystemClock.elapsedRealtimeNanos()
                    segment(firmware, x, y, x, y, tool == 1)
                    refresh(firmware, true)
                }
                2, 3 -> {
                    if (!history.active) return
                    val stroke = history.strokes.last()
                    val previous = stroke.points.last()
                    history.move(x / w, y / h)
                    segment(firmware, previous.x * w, previous.y * h, x, y, stroke.erasing)
                    refresh(firmware, action == 3)
                    if (action == 3) finishStroke(firmware)
                }
            }
        }
    }

    private fun segment(firmware: Firmware, ax: Float, ay: Float, bx: Float, by: Float, erase: Boolean) {
        val canvas = checkNotNull(firmware.canvas()) { "Bigme handwriting canvas lost" }
        paint.color = if (erase) Color.WHITE else Color.BLACK
        paint.strokeWidth = (if (erase) 24 else 3) * density
        val save = canvas.save()
        try {
            canvas.clipRect(0, 0, connectedWidth, connectedHeight)
            if (ax == bx && ay == by) canvas.drawPoint(bx, by, paint)
            else canvas.drawLine(ax, ay, bx, by, paint)
        } finally { canvas.restoreToCount(save) }
        val padding = paint.strokeWidth / 2 + 2
        dirty.union(floor(minOf(ax, bx) - padding).toInt().coerceAtLeast(0),
            floor(minOf(ay, by) - padding).toInt().coerceAtLeast(0),
            ceil(maxOf(ax, bx) + padding).toInt().coerceAtMost(connectedWidth),
            ceil(maxOf(ay, by) + padding).toInt().coerceAtMost(connectedHeight))
    }
    private fun refresh(firmware: Firmware, force: Boolean) {
        if (dirty.isEmpty) return
        val now = SystemClock.uptimeMillis()
        if (!force && !firstSegment && now - lastRefresh < 16) return
        val erasing = history.strokes.lastOrNull()?.erasing == true
        firmware.refresh(dirty, if (erasing) 1030 else 1029)
        dirty.setEmpty(); lastRefresh = now
        if (firstSegment) {
            firstSegment = false
            Log.d(TAG, "First paint submitted in ${(SystemClock.elapsedRealtimeNanos() - paintStarted) / 1_000_000}ms (not panel latency)")
        }
    }
    private fun finishStroke(firmware: Firmware) {
        if (!history.active) return
        refresh(firmware, true)
        history.end()
        main.post {
            if (!closed && !failed && client === firmware) {
                try { paintSurface() } catch (error: Throwable) { fail(error) }
            }
        }
    }
    private fun replay(canvas: Canvas, width: Int, height: Int) {
        canvas.drawColor(Color.WHITE)
        for (stroke in history.strokes) {
            paint.color = if (stroke.erasing) Color.WHITE else Color.BLACK
            paint.strokeWidth = (if (stroke.erasing) 24 else 3) * density
            val points = stroke.points
            if (points.size == 1) canvas.drawPoint(points[0].x * width, points[0].y * height, paint)
            for (i in 1 until points.size) canvas.drawLine(points[i-1].x * width,
                points[i-1].y * height, points[i].x * width, points[i].y * height, paint)
        }
    }
    private fun paintSurface() {
        if (!surfaceReady || !view.holder.surface.isValid) return
        synchronized(lock) {
            // An earlier pen-up task must never introduce ordinary redraws during a new stroke.
            if (history.active) return
            val canvas = view.holder.lockCanvas() ?: return
            try { replay(canvas, view.width, view.height) }
            finally { view.holder.unlockCanvasAndPost(canvas) }
        }
    }
    private fun repaintFirmware(firmware: Firmware) {
        val canvas = checkNotNull(firmware.canvas())
        val save = canvas.save()
        try {
            canvas.clipRect(0, 0, connectedWidth, connectedHeight)
            replay(canvas, connectedWidth, connectedHeight)
        } finally { canvas.restoreToCount(save) }
        // GU16 for toolbar edits; handwriting/rubber waveforms for live segments only.
        firmware.refresh(Rect(0, 0, connectedWidth, connectedHeight), 132)
    }
    private fun edit(clear: Boolean, complete: () -> Unit) {
        accepting = false
        try {
            client?.enable(false)
            synchronized(lock) { if (clear) history.clear() else history.undo(); dirty.setEmpty() }
            paintSurface()
            synchronized(lock) { client?.let { repaintFirmware(it) } }
            accepting = resumed && !closed && !failed && client != null
            client?.enable(accepting)
        } catch (error: Throwable) { fail(error) }
        finally { complete() }
    }
    override fun clear(complete: () -> Unit) = edit(true, complete)
    override fun undo() = edit(false) {}
    override fun setResumed(value: Boolean) {
        if (closed || failed) return
        resumed = value
        if (!value) {
            disconnect()
            runCatching { paintSurface() }.onFailure { fail(it) }
        } else if (client == null) attach()
    }
    private fun disconnect() {
        accepting = false
        val old: Firmware?
        synchronized(lock) {
            old = client; client = null
            history.end(); dirty.setEmpty()
        }
        // Never hold the ink lock across lifecycle Binder calls: callbacks can be in flight.
        old?.close()
    }
    private fun fail(error: Throwable) {
        if (failed || closed) return
        failed = true; accepting = false
        Log.e(TAG, "Bigme renderer unavailable; switching to standard ink", error)
        main.post { if (!closed) { disconnect(); onFailure(error) } }
    }
    override fun dispose() {
        closed = true
        disconnect()
        view.holder.removeCallback(this)
    }

    /** Resolve reflection once. Missing methods fail initialization, not each pen sample. */
    private class Firmware(context: Context) {
        private val type = Class.forName("com.xrz.HandwrittenClient")
        val listenerType = Class.forName("com.xrz.HandwrittenClient\$InputListener")
        private val instance = type.getConstructor(Context::class.java).newInstance(context)
        private val getCanvas = type.getMethod("getCanvas")
        private val invalidate = type.getMethod("inValidate", Rect::class.java, Int::class.javaPrimitiveType)
        private val input = type.getMethod("setInputEnabled", Boolean::class.javaPrimitiveType)
        private val overlay = type.getMethod("setOverlayEnabled", Boolean::class.javaPrimitiveType)
        fun bind(view: View, listener: Any) {
            type.getMethod("bindView", View::class.java).invoke(instance, view)
            type.getMethod("registerInputListener", listenerType).invoke(instance, listener)
            // Default cooked coordinates, explicitly selected when supported.
            runCatching { type.getMethod("setUseRawInputEvent", Boolean::class.javaPrimitiveType).invoke(instance, false) }
        }
        fun connect(w: Int, h: Int) = type.getMethod("connect", Int::class.javaPrimitiveType,
            Int::class.javaPrimitiveType).invoke(instance, w, h) == true
        fun updateLayout() {
            type.getMethod("updateLayout").invoke(instance)
            type.getMethod("updateRotation").invoke(instance)
            overlay.invoke(instance, true)
            runCatching { type.getMethod("setBlendEnabled", Boolean::class.javaPrimitiveType).invoke(instance, true) }
        }
        fun canvas() = getCanvas.invoke(instance) as? Canvas
        fun layout() = listOf("getViewLayout", "getPhyViewLayout", "getPhyRotation").joinToString { name ->
            "$name=${runCatching { type.getMethod(name).invoke(instance) }.getOrNull()}"
        }
        fun refresh(rect: Rect, mode: Int) { invalidate.invoke(instance, rect, mode) }
        fun enable(value: Boolean) { input.invoke(instance, value) }
        fun close() {
            runCatching { input.invoke(instance, false) }
            runCatching { overlay.invoke(instance, false) }
            runCatching { type.getMethod("disconnect").invoke(instance) }
            runCatching { type.getMethod("unBindView").invoke(instance) }
        }
    }
    companion object { private const val TAG = "NxCardsBigme" }
}
