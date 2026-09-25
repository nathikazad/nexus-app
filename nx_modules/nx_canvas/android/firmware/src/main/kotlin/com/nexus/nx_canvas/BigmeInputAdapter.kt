package com.nexus.nx_canvas

import android.content.Context
import android.graphics.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.SurfaceHolder
import android.view.SurfaceView
import java.lang.reflect.Proxy
import org.lsposed.hiddenapibypass.HiddenApiBypass
import kotlin.math.ceil
import kotlin.math.floor

/** Bigme's cooked XRZ input, matching NX Cards. Live samples stay native; only
 * completed immutable operations enter the canvas import/save pipeline. */
class BigmeInputAdapter(context: Context, private val diagnostics: DiagnosticSink = CanvasDiagnostics) : AndroidCanvasInput, SurfaceHolder.Callback {
    private val surface = SurfaceView(context)
    override val view get() = surface
    override val holder get() = surface.holder
    // Cooked callbacks and our foreground bitmap are already view-local.
    override val rotation = 0
    override val requiresErasureRepaint = true
    override var onEvent: ((InputEvent) -> Unit)? = null
    override var onFault: ((String) -> Unit)? = null
    private val main = Handler(Looper.getMainLooper())
    private val lock = Any()
    private val scheduler = object : CanvasScheduler {
        override fun execute(work: () -> Unit) { if (Looper.myLooper() == main.looper) work() else main.post(work) }
        override fun after(milliseconds: Long, work: () -> Unit): Cancellation {
            val task = Runnable(work); main.postDelayed(task, milliseconds)
            return Cancellation { main.removeCallbacks(task) }
        }
    }
    private var firmware: BigmeCanvasFirmware? = null
    private var bitmap: Bitmap? = null
    private var baseBeforeRegion: Bitmap? = null
    private var active: BigmeStroke? = null
    private var selected = CanvasPenTool(NativeTool.PEN, 3.0)
    private var sequence = 0L
    private var pendingDeliveries = 0
    private var admitted = false
    private var closed = false
    private var failed = false
    private var lastRefresh = 0L
    private val dirty = Rect()
    private val paint = Paint().apply {
        isAntiAlias = false; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
    }
    private val lifecycle = CanvasInputLifecycle(object : CanvasFirmwarePort {
        override fun isDrained() = synchronized(lock) { active == null && pendingDeliveries == 0 }
        override fun changeTool(tool: CanvasPenTool) { synchronized(lock) { selected = tool } }
        override fun admitNewStrokes(enabled: Boolean) {
            val connection: BigmeCanvasFirmware?
            val inputEnabled: Boolean
            synchronized(lock) {
                admitted = enabled && !closed && !failed
                connection = firmware
                inputEnabled = admitted || active != null
            }
            // Binder operations must not hold the callback's ink lock.
            runCatching { connection?.enable(inputEnabled) }.onFailure(::fail)
        }
    }, scheduler, diagnostics) { onFault?.invoke(it) }

    init { holder.addCallback(this) }
    override fun surfaceCreated(holder: SurfaceHolder) {}
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        if (closed || failed || width <= 0 || height <= 0) return
        disconnect()
        var opened: BigmeCanvasFirmware? = null
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                check(HiddenApiBypass.addHiddenApiExemptions("Lcom/xrz/")) { "Could not enable XRZ APIs" }
            }
            val connection = BigmeCanvasFirmware(surface.context)
            opened = connection
            val listener = Proxy.newProxyInstance(connection.listenerType.classLoader, arrayOf(connection.listenerType)) { proxy, method, args ->
                when (method.name) {
                    "onInputTouch" -> {
                        if (args != null && args.size >= 5) runCatching {
                            input(connection, (args[0] as Number).toInt(), (args[1] as Number).toDouble(),
                                (args[2] as Number).toDouble(), (args[4] as Number).toInt())
                        }.onFailure(::fail)
                        0
                    }
                    "hashCode" -> System.identityHashCode(proxy)
                    "equals" -> proxy === args?.getOrNull(0)
                    "toString" -> "NxDocsBigmeInput"
                    else -> null
                }
            }
            connection.bind(surface, listener)
            check(connection.connect(width, height)) { "Bigme handwriting service refused connection" }
            connection.updateLayout()
            synchronized(lock) {
                firmware = connection
                checkNotNull(connection.canvas()) { "Bigme handwriting canvas unavailable" }
                if (bitmap?.width != width || bitmap?.height != height) {
                    bitmap?.recycle()
                    bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.WHITE) }
                }
                repaintFirmware(connection)
            }
            paintSurface()
            lifecycle.progressed()
            Log.i(TAG, "Renderer=bigme; connected ${width}x$height; device=${Build.MODEL}")
        } catch (error: Throwable) { opened?.close(); synchronized(lock) { firmware = null }; fail(error) }
    }
    override fun surfaceDestroyed(holder: SurfaceHolder) { disconnect() }
    override fun enable(enabled: Boolean) = lifecycle.enable(enabled)
    override fun drain(done: (Boolean) -> Unit) = lifecycle.drain(done)
    override fun setPen(tool: NativeTool, width: Double) = lifecycle.tool(CanvasPenTool(tool, width))

    private fun emit(vararg events: InputEvent) {
        // Called under lock. The pending count prevents a drain from overtaking delivery.
        pendingDeliveries++
        main.post {
            if (!closed) events.forEach { onEvent?.invoke(it) }
            synchronized(lock) { pendingDeliveries-- }
            if (!closed) lifecycle.progressed()
        }
    }
    private fun input(source: BigmeCanvasFirmware, action: Int, x: Double, y: Double, tool: Int) {
        synchronized(lock) {
            if (closed || failed || firmware !== source || tool !in 0..1) return
            val image = bitmap ?: return
            if (action == 4 || x < 0 || y < 0 || x >= image.width || y >= image.height) {
                finishStroke(source); return
            }
            val point = InkPoint(x, y)
            when (action) {
                1 -> {
                    if (!admitted) return
                    finishStroke(source)
                    val actual = if (tool == 1) CanvasPenTool(NativeTool.RUB, 24.0 * surface.resources.displayMetrics.density) else selected
                    active = BigmeStroke(actual.tool, actual.width, mutableListOf(point))
                    sequence++
                    if (actual.tool == NativeTool.REGION) baseBeforeRegion = image.copy(Bitmap.Config.ARGB_8888, true)
                    emit(InputEvent.Down(sequence))
                    segment(source, point, point)
                    refresh(source, true)
                }
                2, 3 -> {
                    val stroke = active ?: return
                    val previous = stroke.points.last()
                    stroke.points.add(point)
                    segment(source, previous, point)
                    refresh(source, action == 3)
                    if (action == 3) finishStroke(source)
                }
            }
        }
    }
    private fun segment(connection: BigmeCanvasFirmware, a: InkPoint, b: InkPoint) {
        val stroke = active ?: return
        paint.color = if (stroke.tool == NativeTool.RUB) Color.WHITE else Color.BLACK
        paint.strokeWidth = if (stroke.tool == NativeTool.REGION) 2f else stroke.width.toFloat()
        fun draw(canvas: Canvas) {
            val save = canvas.save()
            try {
                canvas.clipRect(0, 0, bitmap!!.width, bitmap!!.height)
                if (a == b) canvas.drawPoint(b.x.toFloat(), b.y.toFloat(), paint)
                else canvas.drawLine(a.x.toFloat(), a.y.toFloat(), b.x.toFloat(), b.y.toFloat(), paint)
            } finally { canvas.restoreToCount(save) }
        }
        draw(Canvas(bitmap!!))
        draw(checkNotNull(connection.canvas()))
        val padding = paint.strokeWidth / 2 + 2
        dirty.union(floor(minOf(a.x, b.x) - padding).toInt().coerceAtLeast(0),
            floor(minOf(a.y, b.y) - padding).toInt().coerceAtLeast(0),
            ceil(maxOf(a.x, b.x) + padding).toInt().coerceAtMost(bitmap!!.width),
            ceil(maxOf(a.y, b.y) + padding).toInt().coerceAtMost(bitmap!!.height))
    }
    private fun refresh(connection: BigmeCanvasFirmware, force: Boolean) {
        if (dirty.isEmpty) return
        val now = SystemClock.uptimeMillis()
        if (!force && now - lastRefresh < 16) return
        connection.refresh(dirty, if (active?.tool == NativeTool.RUB) 1030 else 1029)
        dirty.setEmpty(); lastRefresh = now
    }
    private fun finishStroke(connection: BigmeCanvasFirmware?) {
        val stroke = active ?: return
        if (connection != null) refresh(connection, true)
        if (stroke.tool == NativeTool.REGION) {
            baseBeforeRegion?.let { original ->
                val canvas = Canvas(bitmap!!)
                canvas.drawBitmap(original, 0f, 0f, null)
                if (stroke.points.size >= 3) {
                    val path = Path().apply {
                        moveTo(stroke.points.first().x.toFloat(), stroke.points.first().y.toFloat())
                        stroke.points.drop(1).forEach { lineTo(it.x.toFloat(), it.y.toFloat()) }; close()
                    }
                    paint.color = Color.WHITE; paint.style = Paint.Style.FILL
                    canvas.drawPath(path, paint)
                }
                original.recycle()
            }
            baseBeforeRegion = null
            if (connection != null) repaintFirmware(connection)
        }
        active = null
        emit(InputEvent.Up(sequence), InputEvent.Completed(BigmeStrokeRecord(stroke.tool, stroke.width, stroke.points.toList())), InputEvent.Quiescent(sequence))
        main.post { if (!closed && !failed) runCatching { paintSurface() }.onFailure(::fail) }
    }
    override fun present(bitmap: Bitmap) {
        synchronized(lock) {
            check(active == null && pendingDeliveries == 0) { "Foreground replacement requires drained Bigme input" }
            this.bitmap?.recycle()
            this.bitmap = bitmap.copy(Bitmap.Config.ARGB_8888, true)
            firmware?.let(::repaintFirmware)
        }
        paintSurface()
    }
    private fun repaintFirmware(connection: BigmeCanvasFirmware) {
        val image = bitmap ?: return
        val canvas = checkNotNull(connection.canvas())
        val save = canvas.save()
        try { canvas.clipRect(0, 0, image.width, image.height); canvas.drawBitmap(image, 0f, 0f, null) }
        finally { canvas.restoreToCount(save) }
        connection.refresh(Rect(0, 0, image.width, image.height), 132)
    }
    private fun paintSurface() {
        synchronized(lock) {
            if (active != null || !holder.surface.isValid) return
            val image = bitmap ?: return
            val canvas = holder.lockCanvas() ?: return
            try { canvas.drawBitmap(image, 0f, 0f, null) }
            finally { holder.unlockCanvasAndPost(canvas) }
        }
    }
    private fun disconnect() {
        val old: BigmeCanvasFirmware?
        synchronized(lock) {
            old = firmware
            // Surface loss still delivers a partial stroke for durable recovery.
            finishStroke(null)
            firmware = null
        }
        old?.close()
    }
    private fun fail(error: Throwable) {
        synchronized(lock) { if (failed || closed) return; failed = true; admitted = false }
        Log.e(TAG, "Bigme handwriting failed", error)
        main.post { if (!closed) { disconnect(); onFault?.invoke("Handwriting unavailable. Close and reopen this drawing.") } }
    }
    override fun close() {
        lifecycle.close()
        disconnect()
        synchronized(lock) { closed = true; bitmap?.recycle(); bitmap = null; baseBeforeRegion?.recycle(); baseBeforeRegion = null }
        onEvent = null; onFault = null
        holder.removeCallback(this)
    }
    private data class BigmeStroke(val tool: NativeTool, val width: Double, val points: MutableList<InkPoint>)
    companion object { private const val TAG = "NxDocsBigme" }
}
