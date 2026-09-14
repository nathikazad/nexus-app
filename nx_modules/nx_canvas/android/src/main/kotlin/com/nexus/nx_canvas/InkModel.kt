package com.nexus.nx_canvas

import kotlin.math.*
import java.util.UUID

data class InkPoint(val x: Double, val y: Double, val pressure: Double = 1.0) {
    operator fun plus(p: InkPoint) = InkPoint(x+p.x, y+p.y, pressure)
    operator fun minus(p: InkPoint) = InkPoint(x-p.x, y-p.y, pressure)
    val length get() = hypot(x, y)
    fun lerp(p: InkPoint, t: Double) = InkPoint(x+(p.x-x)*t, y+(p.y-y)*t, pressure+(p.pressure-pressure)*t)
}
data class NativeStroke(val id: String, val points: List<InkPoint>, val color: Long, val width: Double)
data class InkViewport(val x: Double = 0.0, val y: Double = 0.0, val scale: Double = 1.0) {
    fun world(p: InkPoint) = InkPoint((p.x-x)/scale, (p.y-y)/scale, p.pressure)
}
data class InkPlace(val name: String, val view: InkViewport)

object InkGeometry {
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

class InkModel(var strokes: List<NativeStroke>, var view: InkViewport, var places: List<InkPlace>) {
    private val undo=mutableListOf<List<NativeStroke>>()
    private val redo=mutableListOf<List<NativeStroke>>()
    private val views=mutableListOf<InkViewport>()
    val selected=mutableSetOf<String>()
    val canUndo get()=undo.isNotEmpty()
    val canRedo get()=redo.isNotEmpty()
    val canGoBack get()=views.isNotEmpty()
    fun replace(next: List<NativeStroke>) {
        if (next==strokes) return
        undo.add(strokes); if(undo.size>100) undo.removeAt(0)
        redo.clear();strokes=next;selected.clear()
    }
    fun add(stroke: NativeStroke) { if(strokes.none { it.id==stroke.id }) replace(strokes+stroke) }
    fun erase(path: List<InkPoint>, radius: Double) {
        if(path.isEmpty()) return
        var next=strokes
        var previous=path.first()
        for (point in path) {
            val steps=max(1,ceil((point-previous).length/max(.01,radius/2)).toInt())
            for(i in 0..steps) next=next.flatMap { InkGeometry.disk(it,previous.lerp(point,i.toDouble()/steps),radius) }
            previous=point
        }
        replace(next)
    }
    fun eraseRegion(path: List<InkPoint>) = replace(strokes.flatMap { InkGeometry.region(it,path) })
    fun undo() { if(canUndo) { redo.add(strokes);strokes=undo.removeAt(undo.lastIndex);selected.clear() } }
    fun redo() { if(canRedo) { undo.add(strokes);strokes=redo.removeAt(redo.lastIndex);selected.clear() } }
    fun select(path: List<InkPoint>) {
        selected.clear()
        if(path.size<3)return
        strokes.filter { InkGeometry.region(it,path)!=listOf(it) }.forEach { selected.add(it.id) }
    }
    fun moveSelection(delta: InkPoint) {
        val ids=selected.toSet()
        replace(strokes.map { if(it.id in ids) it.copy(points=it.points.map { p -> p+delta }) else it })
        selected.addAll(ids)
    }
    fun rememberView() { views.add(view);if(views.size>50)views.removeAt(0) }
    fun back() { if(views.isNotEmpty())view=views.removeAt(views.lastIndex) }
    fun zoom(factor: Double, anchor: InkPoint) {
        rememberView();val world=view.world(anchor);val scale=(view.scale*factor).coerceIn(.05,8.0)
        view=InkViewport(anchor.x-world.x*scale,anchor.y-world.y*scale,scale)
    }
    fun overview(width: Double,height: Double) {
        rememberView()
        val pts=strokes.flatMap { it.points }
        if(pts.isEmpty()){view=InkViewport();return}
        val left=pts.minOf{it.x};val right=pts.maxOf{it.x};val top=pts.minOf{it.y};val bottom=pts.maxOf{it.y}
        val scale=min((width-80).coerceAtLeast(1.0)/max(1.0,right-left),(height-80).coerceAtLeast(1.0)/max(1.0,bottom-top)).coerceIn(.05,2.0)
        view=InkViewport(width/2-(left+right)/2*scale,height/2-(top+bottom)/2*scale,scale)
    }
}

object InkCodec {
    private fun num(map: Map<*,*>, key:String, fallback:Double)=(map[key] as? Number)?.toDouble()?:fallback
    fun view(map:Map<*,*>)=InkViewport(num(map,"x",0.0),num(map,"y",0.0),num(map,"scale",1.0).coerceIn(.05,8.0))
    fun stroke(map:Map<*,*>)=NativeStroke(map["id"] as String,(map["points"] as List<*>).map {
        val p=it as List<*>;InkPoint((p[0] as Number).toDouble(),(p[1] as Number).toDouble(),(p[2] as Number).toDouble())
    },(map["color"] as Number).toLong(),num(map,"width",3.0))
    fun model(map:Map<*,*>):InkModel {
        require(map["format"]=="nx-canvas" && (map["version"] as Number).toInt()==1){"Unsupported canvas format"}
        return InkModel((map["strokes"] as List<*>).map { stroke(it as Map<*,*>) },view(map["view"] as Map<*,*>),
            (map["places"] as List<*>).map { val p=it as Map<*,*>;InkPlace(p["name"] as String,view(p["view"] as Map<*,*>)) })
    }
    fun encode(view:InkViewport)=mapOf("x" to view.x,"y" to view.y,"scale" to view.scale)
    fun encode(model:InkModel):Map<String,Any> = mapOf("format" to "nx-canvas","version" to 1,
        "strokes" to model.strokes.map { mapOf("id" to it.id,"points" to it.points.map { p->listOf(p.x,p.y,p.pressure) },"color" to it.color,"width" to it.width) },
        "view" to encode(model.view),"places" to model.places.map { mapOf("name" to it.name,"view" to encode(it.view)) })
}
