package com.nexus.nx_canvas
import kotlin.math.*
import java.util.UUID

/** Frozen pre-optimization clipping oracle for differential tests. */
object ReferenceInkGeometry {
    private fun cross(a: InkPoint, b: InkPoint) = a.x*b.y-a.y*b.x
    fun inside(p: InkPoint, polygon: List<InkPoint>): Boolean {
        var inside = false
        for (i in polygon.indices) {
            val a = polygon[i]; val b = polygon[(i+1)%polygon.size]
            val d = b-a; val v = p-a; val length2 = d.x*d.x+d.y*d.y
            if (length2 > 1e-12) {
                val t = (v.x*d.x+v.y*d.y)/length2
                if (t in 0.0..1.0 && (p-a.lerp(b,t)).length < 1e-8) return true
            }
            if ((a.y>p.y)!=(b.y>p.y) && p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x) inside=!inside
        }
        return inside
    }
    private fun clip(stroke: NativeStroke, contains: (InkPoint)->Boolean,
                     intersections: (InkPoint,InkPoint)->List<Double>): List<NativeStroke> {
        if (stroke.points.size==1) return if (contains(stroke.points.first())) emptyList() else listOf(stroke)
        val fragments = mutableListOf<List<InkPoint>>()
        var current = mutableListOf<InkPoint>(); var changed=false
        for (i in 1 until stroke.points.size) {
            val a=stroke.points[i-1]; val b=stroke.points[i]
            val cuts=(listOf(0.0,1.0)+intersections(a,b).filter { it>0 && it<1 }).sorted()
            for (j in 1 until cuts.size) {
                if (cuts[j]-cuts[j-1]<1e-10) continue
                if (contains(a.lerp(b,(cuts[j]+cuts[j-1])/2))) {
                    changed=true
                    if (current.isNotEmpty()) fragments.add(current)
                    current=mutableListOf()
                } else {
                    if (current.isEmpty()) current.add(a.lerp(b,cuts[j-1]))
                    current.add(a.lerp(b,cuts[j]))
                }
            }
        }
        if (!changed) return listOf(stroke)
        if (current.isNotEmpty()) fragments.add(current)
        return fragments.map { stroke.copy(id=UUID.randomUUID().toString(),points=it) }
    }
    fun disk(stroke: NativeStroke, center: InkPoint, radius: Double): List<NativeStroke> {
        val r=radius+stroke.width/2
        return clip(stroke, { (it-center).length<=r }) { a,b ->
            val d=b-a;val f=a-center
            val aa=d.x*d.x+d.y*d.y;val bb=2*(f.x*d.x+f.y*d.y);val cc=f.x*f.x+f.y*f.y-r*r
            val discriminant=bb*bb-4*aa*cc
            if (aa>1e-12 && discriminant>0) listOf((-bb-sqrt(discriminant))/(2*aa),(-bb+sqrt(discriminant))/(2*aa)) else emptyList()
        }
    }
    fun region(stroke: NativeStroke, polygon: List<InkPoint>): List<NativeStroke> {
        if (polygon.size<3) return listOf(stroke)
        val origin=polygon.first()
        val direction=polygon.map { it-origin }.firstOrNull { it.length>1e-8 } ?: return listOf(stroke)
        if (polygon.none { abs(cross(direction,it-origin))>1e-8 }) return listOf(stroke)
        return clip(stroke, { inside(it,polygon) }) { a,b ->
            val cuts=mutableListOf<Double>();val d=b-a
            for (i in polygon.indices) {
                val start=polygon[i]; val edge=polygon[(i+1)%polygon.size]-start;val offset=start-a
                val denominator=cross(d,edge)
                if (abs(denominator)>1e-10) {
                    val t=cross(offset,edge)/denominator; val u=cross(offset,d)/denominator
                    if (u>=-1e-10 && u<=1+1e-10) cuts.add(t)
                } else if (abs(cross(offset,d))<1e-10) {
                    val length2=d.x*d.x+d.y*d.y
                    if (length2>1e-12) for (p in listOf(start,start+edge)) {
                        val v=p-a;cuts.add((v.x*d.x+v.y*d.y)/length2)
                    }
                }
            }
            cuts
        }
    }
}
