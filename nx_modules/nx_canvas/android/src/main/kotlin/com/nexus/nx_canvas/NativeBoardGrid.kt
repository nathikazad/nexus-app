package com.nexus.nx_canvas

import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import android.view.View
import kotlin.math.min

/** Read-only overview. Only populated boards are clickable. Never handles live ink. */
class NativeBoardGrid(context:Context,private val model:InkModel,private val choose:(InkBoard)->Unit):View(context) {
    private val boards=model.boards!!
    private val cells=boards.populated(model.strokes)
    private val hitBoxes=mutableMapOf<InkBoard,RectF>()
    private val density=resources.displayMetrics.density
    init { contentDescription="Populated boards. Tap a board to open it." }
    override fun onDraw(canvas:Canvas) {
        canvas.drawColor(Color.WHITE);hitBoxes.clear()
        val paint=Paint(Paint.ANTI_ALIAS_FLAG)
        if(cells.isEmpty()) {
            paint.color=Color.DKGRAY;paint.textSize=18*density;paint.textAlign=Paint.Align.CENTER
            canvas.drawText("No populated boards yet",width/2f,height/2f,paint);return
        }
        val left=cells.minOf{it.column}*boards.width;val top=cells.minOf{it.row}*boards.height
        val right=(cells.maxOf{it.column}+1)*boards.width;val bottom=(cells.maxOf{it.row}+1)*boards.height
        val pad=20*density
        val scale=min((width-2*pad)/(right-left),(height-2*pad)/(bottom-top)).coerceAtLeast(.000001)
        val view=InkViewport(width/2-(left+right)*scale/2,height/2-(top+bottom)*scale/2,scale)
        val snapshot=InkModel(model.strokes,view,emptyList())
        NativeInkPainter.draw(canvas,snapshot,1.0)
        val current=boards.at(model.view.world(InkPoint(boards.width*model.view.scale/2,boards.height*model.view.scale/2)))
        for(cell in cells) {
            val rect=RectF((view.x+cell.column*boards.width*scale).toFloat(),(view.y+cell.row*boards.height*scale).toFloat(),
                (view.x+(cell.column+1)*boards.width*scale).toFloat(),(view.y+(cell.row+1)*boards.height*scale).toFloat())
            hitBoxes[cell]=rect
            paint.color=if(cell==current)Color.BLACK else Color.GRAY
            paint.style=Paint.Style.STROKE;paint.strokeWidth=if(cell==current)2*density else density
            canvas.drawRect(rect,paint)
            paint.style=Paint.Style.FILL;paint.textSize=min(12*density,rect.width()/5);paint.color=Color.DKGRAY
            canvas.drawText("${cell.column}, ${cell.row}",rect.left+4*density,rect.top+paint.textSize+3*density,paint)
        }
    }
    private var downX=0f;private var downY=0f
    override fun onTouchEvent(event:MotionEvent):Boolean {
        when(event.actionMasked) {
            MotionEvent.ACTION_DOWN->{downX=event.x;downY=event.y;return true}
            MotionEvent.ACTION_UP->{
                if(kotlin.math.hypot(event.x-downX,event.y-downY)<20*density) {
                    hitBoxes.entries.firstOrNull{it.value.contains(event.x,event.y)}?.let{choose(it.key)}
                    performClick()
                }
                return true
            }
        }
        return true
    }
    override fun performClick():Boolean {super.performClick();return true}
}
