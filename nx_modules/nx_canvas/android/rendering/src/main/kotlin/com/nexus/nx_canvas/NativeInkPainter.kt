package com.nexus.nx_canvas

import android.content.Context
import android.graphics.*
import android.view.MotionEvent
import android.view.View
import kotlin.math.*

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
        model.boards?.let { boards ->
            // Board guides are part of the static background, never live pen processing.
            val bounds=canvas.clipBounds
            paint.color=0xffdddddd.toInt();paint.strokeWidth=(1/(model.view.scale*density)).toFloat()
            for(column in ceil(bounds.left/boards.width).toInt()..floor(bounds.right/boards.width).toInt()) {
                val x=(column*boards.width).toFloat();canvas.drawLine(x,bounds.top.toFloat(),x,bounds.bottom.toFloat(),paint)
            }
            for(row in ceil(bounds.top/boards.height).toInt()..floor(bounds.bottom/boards.height).toInt()) {
                val y=(row*boards.height).toFloat();canvas.drawLine(bounds.left.toFloat(),y,bounds.right.toFloat(),y,paint)
            }
        }

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
