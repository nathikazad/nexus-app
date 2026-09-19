package com.nexus.nx_canvas

import android.graphics.Bitmap

class BitmapCanvasFrame(val bitmap: Bitmap) : CanvasFrame {
    override fun release() { if (!bitmap.isRecycled) bitmap.recycle() }
}
class BitmapCanvasRenderer(metrics: InkMetrics, diagnostics: DiagnosticSink = CanvasDiagnostics) : CanvasRenderer<BitmapCanvasFrame> {
    private val tiles = NativeTileRenderer(metrics, diagnostics)
    override fun render(request: CanvasRenderRequest, reusable: BitmapCanvasFrame?): BitmapCanvasFrame {
        val bitmap = tiles.render(request.revision.drawing, request.density, request.width, request.height, request.rotation, reusable?.bitmap)
        return if (bitmap === reusable?.bitmap) reusable else BitmapCanvasFrame(bitmap)
    }
    override fun close() = tiles.close()
}
