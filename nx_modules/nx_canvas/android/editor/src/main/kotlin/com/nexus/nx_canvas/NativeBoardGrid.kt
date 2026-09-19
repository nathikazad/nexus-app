package com.nexus.nx_canvas

import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import android.view.View
import kotlin.math.min

/** Read-only overview. Only populated boards are clickable. Never handles live ink. */
class NativeBoardGrid(context:Context,private val model:InkModel,private val previews:CanvasPreviewCoordinator<CanvasOverviewPreview>,private val diagnostics:DiagnosticSink = CanvasDiagnostics,private val renderer:CanvasOverviewRenderer = DefaultOverviewRenderer(),private val choose:(InkBoard)->Unit):View(context) {
    private val boards=model.boards!!
    private var preview:CanvasOverviewPreview?=null
    private val density=resources.displayMetrics.density
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG)
    init { contentDescription="Populated boards. Tap a board to open it." }
    override fun onSizeChanged(w:Int,h:Int,oldw:Int,oldh:Int) {
        super.onSizeChanged(w,h,oldw,oldh)
        if(w<=0 || h<=0)return
        preview=null
        previews.request({ CanvasOverviewPreview.prepare(model,w,h,density,renderer,diagnostics) }) {
            preview=it;invalidate()
        }
    }
    override fun onDetachedFromWindow() {
        previews.cancel()
        // Displayed bitmaps may still be referenced by RenderThread; let Android release them.
        preview=null
        super.onDetachedFromWindow()
    }
    override fun onDraw(canvas:Canvas) {
        val diagnosticSpan=diagnostics.begin("overview.draw")
        try {
            canvas.drawColor(Color.WHITE)
            val ready=preview
            if(ready==null || ready.layout.boxes.isEmpty()) {
                paint.style=Paint.Style.FILL;paint.color=Color.DKGRAY;paint.textSize=18*density;paint.textAlign=Paint.Align.CENTER
                canvas.drawText(if(ready==null)"Preparing boards…" else "No populated boards yet",width/2f,height/2f,paint)
                return
            }
            canvas.drawBitmap(ready.image,0f,0f,null)
            val current=boards.at(model.view.world(InkPoint(boards.width*model.view.scale/2,boards.height*model.view.scale/2)))
            paint.textAlign=Paint.Align.LEFT
            for((cell,bounds) in ready.layout.boxes) {
                val rect=RectF(bounds.left.toFloat(),bounds.top.toFloat(),bounds.right.toFloat(),bounds.bottom.toFloat())
                paint.color=if(cell==current)Color.BLACK else Color.GRAY
                paint.style=Paint.Style.STROKE;paint.strokeWidth=if(cell==current)2*density else density
                canvas.drawRect(rect,paint)
                paint.style=Paint.Style.FILL;paint.textSize=min(12*density,rect.width()/5);paint.color=Color.DKGRAY
                canvas.drawText("${cell.column}, ${cell.row}",rect.left+4*density,rect.top+paint.textSize+3*density,paint)
            }
        } finally {diagnosticSpan.end()}
    }
    private var downX=0f;private var downY=0f
    override fun onTouchEvent(event:MotionEvent):Boolean {
        when(event.actionMasked) {
            MotionEvent.ACTION_DOWN->{downX=event.x;downY=event.y;return true}
            MotionEvent.ACTION_UP->{
                if(kotlin.math.hypot(event.x-downX,event.y-downY)<20*density) {
                    preview?.layout?.hit(event.x.toDouble(),event.y.toDouble())?.let(choose)
                    performClick()
                }
                return true
            }
        }
        return true
    }
    override fun performClick():Boolean {super.performClick();return true}
}
