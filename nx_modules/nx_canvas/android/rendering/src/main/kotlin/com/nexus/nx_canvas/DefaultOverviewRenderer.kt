package com.nexus.nx_canvas

import android.graphics.Canvas

class DefaultOverviewRenderer : CanvasOverviewRenderer {
    override fun draw(canvas: Canvas, snapshot: InkSnapshot) {
        NativeInkPainter.draw(canvas, snapshot.model(), 1.0)
    }
}
