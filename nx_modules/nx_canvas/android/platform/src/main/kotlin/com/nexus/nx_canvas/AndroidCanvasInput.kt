package com.nexus.nx_canvas

import android.graphics.Bitmap
import android.view.View
import android.view.SurfaceHolder

/** Android-only surface contract. Hardware implementation is selected at assembly. */
interface AndroidCanvasInput : CanvasInput {
    val view: View
    val rotation: Int
    val holder: SurfaceHolder
    fun present(bitmap: Bitmap)
    fun setPen(tool: NativeTool, width: Double)
}
