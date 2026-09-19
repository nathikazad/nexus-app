package com.nexus.nx_canvas

import android.graphics.Bitmap
import android.graphics.Canvas

/** Finished software raster and hit geometry; preparation must run on the render worker. */
data class CanvasOverviewPreview(val image: Bitmap, val layout: InkOverviewLayout) {
    companion object {
        fun prepare(model: InkModel, width: Int, height: Int, density: Float,
                    renderer: CanvasOverviewRenderer, diagnostics: DiagnosticSink): CanvasOverviewPreview {
            val boards=requireNotNull(model.boards)
            val cells=diagnostics.measure("overview.populate",drawingCounts(model.strokes)){boards.populated(model.strokes)}
            val layout=InkOverviewLayout.calculate(boards,cells,width,height,20.0*density)
            val image=Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888)
            try {
                diagnostics.measure("overview.raster",mapOf("boards" to cells.size,"width" to width,"height" to height)) {
                    renderer.draw(Canvas(image),InkSnapshot.of(InkModel(model.strokes,layout.view,emptyList())))
                }
                return CanvasOverviewPreview(image,layout)
            } catch(error: Throwable) { image.recycle(); throw error }
        }
    }
}
