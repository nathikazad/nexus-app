package com.nexus.nx_canvas

import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import android.view.View
import kotlin.math.*

enum class NativeTool { PEN, RUB, REGION, SELECT, HAND, MAGNIFY }

object NativeInkPainter {
    fun panelBitmap(model:InkModel,density:Double,width:Int,height:Int,rotation:Int):Bitmap {
        val swapped=rotation==90 || rotation==270
        val image=Bitmap.createBitmap(if(swapped)height else width,if(swapped)width else height,Bitmap.Config.ARGB_8888)
        val canvas=Canvas(image)
        canvas.drawColor(Color.WHITE)
        val source=listOf(InkPoint(0.0,0.0),InkPoint(width.toDouble(),0.0),InkPoint(0.0,height.toDouble()))
        val destination=source.map{InkCoordinates.viewToPanel(it,rotation,width.toDouble(),height.toDouble())}
        fun coordinates(points:List<InkPoint>)=points.flatMap{listOf(it.x.toFloat(),it.y.toFloat())}.toFloatArray()
        val transform=Matrix()
        check(transform.setPolyToPoly(coordinates(source),0,coordinates(destination),0,3))
        canvas.concat(transform)
        draw(canvas,model,density)
        return image
    }

    fun draw(canvas:Canvas, model:InkModel, density:Double, offset:InkPoint=InkPoint(0.0,0.0), selection:Boolean=false) {
        canvas.save()
        canvas.translate((model.view.x*density).toFloat(),(model.view.y*density).toFloat())
        canvas.scale((model.view.scale*density).toFloat(),(model.view.scale*density).toFloat())
        val paint=Paint(Paint.ANTI_ALIAS_FLAG).apply { style=Paint.Style.STROKE;strokeCap=Paint.Cap.ROUND }
        for(stroke in model.strokes) {
            paint.color=stroke.color.toInt()
            val delta=if(stroke.id in model.selected)offset else InkPoint(0.0,0.0)
            var previous:InkPoint?=null
            for(raw in stroke.points) {
                val p=raw+delta; val before=previous?:p
                paint.strokeWidth=(stroke.width*(.5+(before.pressure+p.pressure)/4)).toFloat()
                if(previous!=null)canvas.drawLine(before.x.toFloat(),before.y.toFloat(),p.x.toFloat(),p.y.toFloat(),paint)
                else if(stroke.points.size==1)canvas.drawPoint(p.x.toFloat(),p.y.toFloat(),paint)
                previous=p
            }
        }
        if(selection) bounds(model)?.let { b ->
            paint.color=Color.BLACK;paint.strokeWidth=(1/(model.view.scale*density)).toFloat()
            paint.pathEffect=DashPathEffect(floatArrayOf((6/model.view.scale).toFloat(),(4/model.view.scale).toFloat()),0f)
            b.offset(offset.x.toFloat(),offset.y.toFloat());canvas.drawRect(b,paint)
        }
        canvas.restore()
    }
    fun bounds(model:InkModel):RectF? {
        val points=model.strokes.filter { it.id in model.selected }.flatMap { it.points }
        if(points.isEmpty())return null
        return RectF(points.minOf{it.x}.toFloat(),points.minOf{it.y}.toFloat(),points.maxOf{it.x}.toFloat(),points.maxOf{it.y}.toFloat())
    }
}

/** Used only for navigation and selection. Live pen/eraser ink stays in NoteView. */
class NativeEditingView(context:Context,val model:InkModel,val changed:()->Unit):View(context) {
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
        NativeInkPainter.draw(canvas,model,density,delta,tool==NativeTool.SELECT)
        if(path.isNotEmpty()) {
            canvas.save();canvas.translate((model.view.x*density).toFloat(),(model.view.y*density).toFloat())
            canvas.scale((model.view.scale*density).toFloat(),(model.view.scale*density).toFloat())
            val outline=Path().apply { moveTo(path.first().x.toFloat(),path.first().y.toFloat());path.drop(1).forEach{lineTo(it.x.toFloat(),it.y.toFloat())};close() }
            canvas.drawPath(outline,Paint().apply{color=0x22000000})
            canvas.drawPath(outline,Paint().apply{color=Color.BLACK;style=Paint.Style.STROKE;strokeWidth=(1/model.view.scale).toFloat()})
            canvas.restore()
        }
    }
    fun cancelGesture() { zoomTap=false; if(active && pan)model.view=base;active=false;path.clear();delta=InkPoint(0.0,0.0);invalidate() }
    override fun onTouchEvent(e:MotionEvent):Boolean {
        if(tool==NativeTool.MAGNIFY) {
            when(e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {anchor=center(e);zoomTap=true}
                MotionEvent.ACTION_MOVE -> if((center(e)-anchor).length>12)zoomTap=false
                MotionEvent.ACTION_POINTER_DOWN, MotionEvent.ACTION_CANCEL -> zoomTap=false
                MotionEvent.ACTION_UP -> {if(zoomTap){model.zoom(2.0,anchor);changed();performClick()};zoomTap=false}
            }
            invalidate();return true
        }
        when(e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                active=true;start=point(e);base=model.view;anchor=center(e);distance=1.0
                pan=tool==NativeTool.HAND || e.getToolType(0)==MotionEvent.TOOL_TYPE_FINGER
                if(pan)model.rememberView()
                else {
                    val bounds=NativeInkPainter.bounds(model)?.apply { inset((-12/model.view.scale).toFloat(),(-12/model.view.scale).toFloat()) }
                    moving=bounds?.contains(start.x.toFloat(),start.y.toFloat())==true
                    if(!moving){model.selected.clear();path.clear();path.add(start)}
                }
            }
            MotionEvent.ACTION_POINTER_DOWN -> if(pan){base=model.view;anchor=center(e);distance=spread(e)}
            MotionEvent.ACTION_MOVE -> if(active) {
                if(pan) {
                    val c=center(e);val world=base.world(anchor);val scale=(base.scale*spread(e)/distance).coerceIn(.05,8.0)
                    model.view=InkViewport(c.x-world.x*scale,c.y-world.y*scale,scale)
                } else if(moving) delta=point(e)-start else path.add(point(e))
            }
            MotionEvent.ACTION_POINTER_UP -> if(pan) {
                val remaining=if(e.actionIndex==0)1 else 0
                base=model.view;anchor=InkPoint(e.getX(remaining)/density,e.getY(remaining)/density);distance=1.0
            }
            MotionEvent.ACTION_UP -> if(active) {
                if(!pan){if(moving)model.moveSelection(delta) else {path.add(point(e));model.select(path)}}
                active=false;path.clear();delta=InkPoint(0.0,0.0);changed();performClick()
            }
            MotionEvent.ACTION_CANCEL -> cancelGesture()
        }
        invalidate();return true
    }
    override fun performClick():Boolean {super.performClick();return true}
}
