package com.nexus.nx_canvas

import android.graphics.Canvas

/** Worker-only ink raster port. The UI receives a finished preview bitmap. */
fun interface CanvasOverviewRenderer {
    fun draw(canvas: Canvas, snapshot: InkSnapshot)
}
