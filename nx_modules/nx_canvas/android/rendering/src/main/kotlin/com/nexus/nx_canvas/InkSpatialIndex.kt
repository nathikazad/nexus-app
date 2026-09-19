package com.nexus.nx_canvas

import kotlin.math.*

class InkSpatialIndex(strokes:List<NativeStroke> = emptyList(),private val cellSize:Double=512.0) {
    private var source:List<NativeStroke>?=null
    private val cells=mutableMapOf<Pair<Int,Int>,MutableSet<String>>()
    private val entries=mutableMapOf<String,Pair<NativeStroke,InkBounds>>()
    private val oversized=mutableSetOf<String>()
    private var order=emptyMap<String,Int>()
    init {update(strokes)}
    private fun keys(b:InkBounds):List<Pair<Int,Int>>? {
        val l=floor(b.left/cellSize).toInt();val r=floor(b.right/cellSize).toInt()
        val t=floor(b.top/cellSize).toInt();val d=floor(b.bottom/cellSize).toInt()
        if((r.toLong()-l+1)*(d.toLong()-t+1)>4096)return null
        return (l..r).flatMap{x->(t..d).map{y->x to y}}
    }
    fun update(strokes:List<NativeStroke>) {
        if(source===strokes)return
        val next=strokes.associateBy{it.id}
        for((id,entry) in entries.toMap())if(next[id]!==entry.first) {
            keys(entry.second)?.forEach{key->cells[key]?.let{it.remove(id);if(it.isEmpty())cells.remove(key)}}
            oversized.remove(id);entries.remove(id)
        }
        for(stroke in strokes)if(stroke.id !in entries && stroke.points.isNotEmpty()) {
            val bounds=InkBounds.of(stroke);entries[stroke.id]=stroke to bounds
            val buckets=keys(bounds)
            if(buckets==null)oversized.add(stroke.id) else buckets.forEach{cells.getOrPut(it){mutableSetOf()}.add(stroke.id)}
        }
        order=strokes.mapIndexed{i,s->s.id to i}.toMap();source=strokes
    }
    fun query(bounds:InkBounds):List<NativeStroke> {
        val buckets=keys(bounds)
        val ids=if(buckets==null)entries.keys else (buckets.flatMap{cells[it].orEmpty()}+oversized).toSet()
        return ids.mapNotNull{entries[it]}.filter{it.second.intersects(bounds)}.map{it.first}.sortedBy{order[it.id]}
    }
}
