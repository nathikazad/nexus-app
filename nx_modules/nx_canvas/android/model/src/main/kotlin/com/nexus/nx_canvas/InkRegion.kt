package com.nexus.nx_canvas

import kotlin.math.*

/** Prepared exact polygon query. Broad-phase bounds reject untouched strokes and segments.
 * Geometry remains unchanged: no polygon simplification or approximate erasure.
 */
class InkRegion(private val polygon:List<InkPoint>) {
    private val bounds=if(polygon.isEmpty())null else InkBounds(polygon.minOf{it.x},polygon.minOf{it.y},polygon.maxOf{it.x},polygon.maxOf{it.y})
    private val valid:Boolean=run {
        if(polygon.size<3)false else {
            val o=polygon.first()
            val d=polygon.firstOrNull{hypot(it.x-o.x,it.y-o.y)>1e-8}
            d!=null && polygon.any{abs((d.x-o.x)*(it.y-o.y)-(d.y-o.y)*(it.x-o.x))>1e-8}
        }
    }
    private data class Edge(val a:InkPoint,val b:InkPoint) {
        val minX=min(a.x,b.x);val maxX=max(a.x,b.x)
        val minY=min(a.y,b.y);val maxY=max(a.y,b.y)
    }
    private val edges=if(valid)polygon.indices.map{Edge(polygon[it],polygon[(it+1)%polygon.size])} else emptyList()
    fun erase(stroke:NativeStroke):List<NativeStroke> {
        if(!valid || stroke.bounds?.intersects(bounds!!)!=true)return listOf(stroke)
        return InkGeometry.clip(stroke,::contains,::intersections)
    }
    private fun contains(p:InkPoint):Boolean {
        val box=bounds?:return false
        if(p.x<box.left-1e-8 || p.x>box.right+1e-8 || p.y<box.top-1e-8 || p.y>box.bottom+1e-8)return false
        var inside=false
        for(e in edges) {
            val dx=e.b.x-e.a.x;val dy=e.b.y-e.a.y
            val vx=p.x-e.a.x;val vy=p.y-e.a.y;val length2=dx*dx+dy*dy
            if(length2>1e-12) {
                val t=(vx*dx+vy*dy)/length2
                if(t in 0.0..1.0 && hypot(vx-dx*t,vy-dy*t)<1e-8)return true
            }
            if((e.a.y>p.y)!=(e.b.y>p.y) && p.x<dx*(p.y-e.a.y)/dy+e.a.x)inside=!inside
        }
        return inside
    }
    private fun intersections(a:InkPoint,b:InkPoint):List<Double> {
        val box=bounds!!
        val left=min(a.x,b.x);val right=max(a.x,b.x);val top=min(a.y,b.y);val bottom=max(a.y,b.y)
        if(right<box.left || left>box.right || bottom<box.top || top>box.bottom)return emptyList()
        val cuts=mutableListOf<Double>();val dx=b.x-a.x;val dy=b.y-a.y
        for(e in edges) {
            // Epsilon matches the exact intersection test at shared boundaries.
            if(right<e.minX-1e-8 || left>e.maxX+1e-8 || bottom<e.minY-1e-8 || top>e.maxY+1e-8)continue
            val ex=e.b.x-e.a.x;val ey=e.b.y-e.a.y;val ox=e.a.x-a.x;val oy=e.a.y-a.y
            val denominator=dx*ey-dy*ex
            if(abs(denominator)>1e-10) {
                val t=(ox*ey-oy*ex)/denominator;val u=(ox*dy-oy*dx)/denominator
                if(u>=-1e-10 && u<=1+1e-10)cuts.add(t)
            } else if(abs(ox*dy-oy*dx)<1e-10) {
                val length2=dx*dx+dy*dy
                if(length2>1e-12) {
                    cuts.add((ox*dx+oy*dy)/length2)
                    cuts.add(((e.b.x-a.x)*dx+(e.b.y-a.y)*dy)/length2)
                }
            }
        }
        return cuts
    }
}
