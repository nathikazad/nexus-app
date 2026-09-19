package com.nexus.nx_canvas

import android.content.Context
import android.graphics.*
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View

/** Small overlay, isolated from NoteView. Long holds fire once, never also tap. */
class NativeBoardControls(context:Context,private val navigate:(Int,Int,Boolean)->Unit,private val overview:()->Unit):View(context) {
    private val main=Handler(Looper.getMainLooper())
    private val gesture=BoardPressTracker()
    private var active:Int?=null
    private val centers=listOf(76f to 28f,28f to 76f,76f to 76f,124f to 76f,76f to 124f)
    private val directions=listOf(0 to -1,-1 to 0,0 to 0,1 to 0,0 to 1)
    private val hold=Runnable {
        val index=active
        if(index!=null && index!=2 && gesture.hold()) {
            val direction=directions[index];navigate(direction.first,direction.second,true)
            invalidate()
        }
    }
    init { contentDescription="Board navigation: tap an arrow for a quarter board, hold for the next board. Center dot opens overview." }
    private fun hit(x:Float,y:Float):Int? {
        val px=x*152/width;val py=y*152/height
        return centers.indexOfFirst{(cx,cy)->kotlin.math.abs(px-cx)<=24 && kotlin.math.abs(py-cy)<=24}.takeIf{it>=0}
    }
    override fun onDraw(canvas:Canvas) {
        canvas.save();canvas.scale(width/152f,height/152f)
        val paint=Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color=Color.WHITE;canvas.drawRoundRect(4f,4f,148f,148f,30f,30f,paint)
        paint.color=0xffd5d5d5.toInt();paint.style=Paint.Style.STROKE;paint.strokeWidth=1f
        canvas.drawRoundRect(4f,4f,148f,148f,30f,30f,paint)
        for((index,center) in centers.withIndex()) {
            val (x,y)=center
            if(active==index){paint.style=Paint.Style.FILL;paint.color=0xffe3e3e3.toInt();canvas.drawCircle(x,y,21f,paint)}
            paint.color=Color.BLACK;paint.strokeWidth=2.5f;paint.strokeCap=Paint.Cap.ROUND;paint.strokeJoin=Paint.Join.ROUND
            if(index==2){paint.style=Paint.Style.FILL;canvas.drawCircle(x,y,5f,paint)}
            else {
                paint.style=Paint.Style.STROKE
                val (dx,dy)=directions[index];val tipX=x+dx*8;val tipY=y+dy*8
                canvas.drawLine(x-dx*7,y-dy*7,tipX,tipY,paint)
                val path=Path().apply{
                    moveTo(tipX-dx*6-dy*6,tipY-dy*6+dx*6)
                    lineTo(tipX,tipY);lineTo(tipX-dx*6+dy*6,tipY-dy*6-dx*6)
                }
                canvas.drawPath(path,paint)
            }
        }
        canvas.restore()
    }
    override fun onTouchEvent(event:MotionEvent):Boolean {
        when(event.actionMasked) {
            MotionEvent.ACTION_DOWN->{
                active=hit(event.x,event.y);gesture.down();invalidate()
                if(active!=null && active!=2)main.postDelayed(hold,500)
            }
            MotionEvent.ACTION_MOVE->if(hit(event.x,event.y)!=active)cancelPress()
            MotionEvent.ACTION_POINTER_DOWN,MotionEvent.ACTION_CANCEL->cancelPress()
            MotionEvent.ACTION_UP->{
                main.removeCallbacks(hold)
                val index=active
                val tap=gesture.up();active=null;invalidate()
                if(index!=null && tap) {
                    if(index==2)overview() else directions[index].let{navigate(it.first,it.second,false)}
                    performClick()
                }
            }
        }
        return true
    }
    fun cancelPress(){main.removeCallbacks(hold);active=null;gesture.cancel();invalidate()}
    override fun onDetachedFromWindow(){cancelPress();super.onDetachedFromWindow()}
    override fun performClick():Boolean{super.performClick();return true}
}
