package com.nexus.nx_canvas

import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import android.view.View
import kotlin.math.*

/** Used only for navigation and selection. Live pen/eraser ink stays in NoteView. */
class NativeEditingView(context:Context,private val engine:CanvasEngine,val changed:()->Unit):View(context) {
    private val model get()=engine.presentation()
    private val visibleIndex=InkSpatialIndex()
    var tool=NativeTool.HAND
    private val density=resources.displayMetrics.density.toDouble()
    private val path=mutableListOf<InkPoint>()
    private var start=InkPoint(0.0,0.0)
    private var delta=InkPoint(0.0,0.0)
    private var moving=false
    private var active=false
    private var pan=false
    private var base=model.view
    private var anchor=InkPoint(0.0,0.0)
    private var distance=1.0
    private var zoomTap=false
    private fun point(e:MotionEvent)=model.view.world(InkPoint(e.x/density,e.y/density))
    private fun center(e:MotionEvent)=if(e.pointerCount>1)InkPoint((e.getX(0)+e.getX(1))/2/density,(e.getY(0)+e.getY(1))/2/density) else InkPoint(e.x/density,e.y/density)
    private fun spread(e:MotionEvent)=if(e.pointerCount>1)max(1.0,hypot((e.getX(1)-e.getX(0)).toDouble(),(e.getY(1)-e.getY(0)).toDouble())) else 1.0
    override fun onDraw(canvas:Canvas) {
        canvas.drawColor(Color.WHITE)
        visibleIndex.update(model.strokes)
        val left=-model.view.x/model.view.scale;val top=-model.view.y/model.view.scale
        val visible=visibleIndex.query(InkBounds(left,top,left+width/density/model.view.scale,top+height/density/model.view.scale))
        // Selected strokes may move into view from outside the original viewport.
        val drawing=if(tool==NativeTool.SELECT)model else InkModel(visible,model.view,model.places,model.boards)
        NativeInkPainter.draw(canvas,drawing,density,delta,tool==NativeTool.SELECT)
        if(path.isNotEmpty()) {
            canvas.save();canvas.translate((model.view.x*density).toFloat(),(model.view.y*density).toFloat())
            canvas.scale((model.view.scale*density).toFloat(),(model.view.scale*density).toFloat())
            val outline=Path().apply { moveTo(path.first().x.toFloat(),path.first().y.toFloat());path.drop(1).forEach{lineTo(it.x.toFloat(),it.y.toFloat())};close() }
            canvas.drawPath(outline,Paint().apply{color=0x22000000})
            canvas.drawPath(outline,Paint().apply{color=Color.BLACK;style=Paint.Style.STROKE;strokeWidth=(1/model.view.scale).toFloat()})
            canvas.restore()
        }
    }
    fun cancelGesture() { zoomTap=false; if(active && pan)engine.dispatch(CanvasCommand.SetView(base));active=false;path.clear();delta=InkPoint(0.0,0.0);invalidate() }
    override fun onTouchEvent(e:MotionEvent):Boolean {
        if(tool==NativeTool.MAGNIFY) {
            when(e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {anchor=center(e);zoomTap=true}
                MotionEvent.ACTION_MOVE -> if((center(e)-anchor).length>12)zoomTap=false
                MotionEvent.ACTION_POINTER_DOWN, MotionEvent.ACTION_CANCEL -> zoomTap=false
                MotionEvent.ACTION_UP -> {if(zoomTap){engine.dispatch(CanvasCommand.Zoom(2.0,anchor));changed();performClick()};zoomTap=false}
            }
            invalidate();return true
        }
        when(e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                active=true;start=point(e);base=model.view;anchor=center(e);distance=1.0
                pan=tool==NativeTool.HAND
                if(pan)engine.dispatch(CanvasCommand.RememberView)
                else {
                    val bounds=NativeInkPainter.bounds(model)?.apply { inset((-12/model.view.scale).toFloat(),(-12/model.view.scale).toFloat()) }
                    moving=bounds?.contains(start.x.toFloat(),start.y.toFloat())==true
                    if(!moving){engine.dispatch(CanvasCommand.ClearSelection);path.clear();path.add(start)}
                }
            }
            MotionEvent.ACTION_POINTER_DOWN -> if(pan){base=model.view;anchor=center(e);distance=spread(e)}
            MotionEvent.ACTION_MOVE -> if(active) {
                if(pan) {
                    val c=center(e);val world=base.world(anchor);val scale=(base.scale*spread(e)/distance).coerceIn(.05,8.0)
                    engine.dispatch(CanvasCommand.SetView(InkViewport(c.x-world.x*scale,c.y-world.y*scale,scale)))
                } else if(moving) delta=point(e)-start else path.add(point(e))
            }
            MotionEvent.ACTION_POINTER_UP -> if(pan) {
                val remaining=if(e.actionIndex==0)1 else 0
                base=model.view;anchor=InkPoint(e.getX(remaining)/density,e.getY(remaining)/density);distance=1.0
            }
            MotionEvent.ACTION_UP -> if(active) {
                if(!pan){if(moving)engine.dispatch(CanvasCommand.MoveSelection(delta)) else {path.add(point(e));engine.dispatch(CanvasCommand.Select(path.toList()))}}
                active=false;path.clear();delta=InkPoint(0.0,0.0);changed();performClick()
            }
            MotionEvent.ACTION_CANCEL -> cancelGesture()
        }
        invalidate();return true
    }
    override fun performClick():Boolean {super.performClick();return true}
}
