package com.nexus.nx_canvas

import kotlin.math.*

data class InkBoard(val column:Int,val row:Int)

/** Stable world-space board sizes; navigation never modifies ink. */
data class InkBoards(val width:Double,val height:Double) {
    init { require(width.isFinite() && height.isFinite() && width>0 && height>0) }
    fun at(p:InkPoint)=InkBoard(floor(p.x/width).toInt(),floor(p.y/height).toInt())
    fun current(view:InkViewport,screenWidth:Double,screenHeight:Double)=
        at(view.world(InkPoint(screenWidth/2,screenHeight/2)))
    fun view(board:InkBoard,screenWidth:Double,screenHeight:Double):InkViewport {
        val scale=min(screenWidth/width,screenHeight/height)
        return InkViewport(screenWidth/2-(board.column+.5)*width*scale,
            screenHeight/2-(board.row+.5)*height*scale,scale)
    }
    fun navigate(base:InkViewport,dx:Int,dy:Int,jump:Boolean,sw:Double,sh:Double):InkViewport {
        if(jump) {
            val board=current(base,sw,sh)
            return view(InkBoard(board.column+dx,board.row+dy),sw,sh)
        }
        return base.copy(x=base.x-dx*width*base.scale/4,y=base.y-dy*height*base.scale/4)
    }
    fun populated(strokes:List<NativeStroke>):Set<InkBoard> {
        val result=linkedSetOf<InkBoard>()
        for(stroke in strokes) {
            if(stroke.points.size==1)result.add(at(stroke.points.first()))
            for(i in 1 until stroke.points.size) {
                val a=stroke.points[i-1];val b=stroke.points[i]
                val cuts=mutableListOf(0.0,1.0)
                fun boundaries(start:Double,end:Double,size:Double) {
                    if(start==end)return
                    val first=floor(min(start,end)/size).toInt()+1
                    val last=ceil(max(start,end)/size).toInt()-1
                    for(n in first..last)cuts.add((n*size-start)/(end-start))
                }
                boundaries(a.x,b.x,width);boundaries(a.y,b.y,height)
                val sorted=cuts.sorted()
                for(j in 1 until sorted.size) result.add(at(a.lerp(b,(sorted[j-1]+sorted[j])/2)))
            }
        }
        return result
    }
}

/** Shared press state for touch and stylus navigation. */
class BoardPressTracker {
    private var pressed=false
    private var held=false
    fun down(){pressed=true;held=false}
    fun hold():Boolean {
        if(!pressed || held)return false
        held=true;return true
    }
    fun up():Boolean {val tap=pressed && !held;cancel();return tap}
    fun cancel(){pressed=false;held=false}
}
