package com.nexus.nx_cards

import android.graphics.*
import android.graphics.drawable.Drawable

/** Monochrome icons for both LCD and e-ink displays. */
internal class DrawingIcon(private val name: String) : Drawable() {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.BLACK; style = Paint.Style.STROKE; strokeWidth = 2f
        strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
    }
    override fun draw(canvas: Canvas) {
        canvas.save()
        canvas.translate(bounds.left.toFloat(), bounds.top.toFloat())
        canvas.scale(bounds.width()/24f, bounds.height()/24f)
        fun line(vararg xy: Float) {
            val path = Path().apply {
                moveTo(xy[0], xy[1])
                for (i in 2 until xy.size step 2) lineTo(xy[i], xy[i+1])
            }
            canvas.drawPath(path, paint)
        }
        when (name) {
            "undo" -> {
                line(8f, 4f, 3f, 9f, 8f, 14f)
                canvas.drawPath(Path().apply { moveTo(3f,9f); lineTo(14f,9f); cubicTo(23f,9f,23f,20f,14f,20f) }, paint)
            }
            "erase" -> { line(3f,14f,13f,4f,21f,12f,13f,20f,9f,20f,3f,14f); line(8f,9f,16f,17f); line(13f,20f,22f,20f) }
            "play" -> line(7f,3f,21f,12f,7f,21f,7f,3f)
            "next" -> { line(4f,12f,20f,12f); line(13f,5f,20f,12f,13f,19f) }
            "yes" -> line(4f,12f,9f,18f,21f,5f)
            "no" -> { line(5f,5f,19f,19f); line(19f,5f,5f,19f) }
            else -> {
                canvas.drawPath(Path().apply { moveTo(2f,12f); quadTo(12f,-1f,22f,12f); quadTo(12f,25f,2f,12f) }, paint)
                canvas.drawCircle(12f,12f,3f,paint)
                if (name == "hide") line(3f,3f,21f,21f)
            }
        }
        canvas.restore()
    }
    override fun setAlpha(alpha: Int) { paint.alpha = alpha; invalidateSelf() }
    override fun setColorFilter(filter: ColorFilter?) { paint.colorFilter = filter; invalidateSelf() }
    @Deprecated("Drawable API")
    override fun getOpacity() = PixelFormat.TRANSLUCENT
}
