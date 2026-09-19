package com.nexus.nx_canvas

import android.graphics.*
import kotlin.math.*

/** Confined to the render executor. Tiles contain ink only; guides are cheap vector overlays. */
class NativeTileRenderer(private val metrics:InkMetrics, private val diagnostics:DiagnosticSink = CanvasDiagnostics) {
    private data class Key(val x:Int,val y:Int,val scale:Double,val rotation:Int)
    private data class Tile(val image:Bitmap,val strokes:List<NativeStroke>)
    private val index=InkSpatialIndex()
    private val tiles=InkLruCache<Key,Tile>(32L*1024*1024,{it.image.allocationByteCount.toLong()},{it.image.recycle()})
    fun render(snapshot:InkSnapshot,density:Double,width:Int,height:Int,rotation:Int,reusable:Bitmap?):Bitmap {
        val started=System.nanoTime()
        val renderSpan=diagnostics.begin("render.total",mapOf("width" to width,"height" to height,"rotation" to rotation,"scale" to snapshot.view.scale,"density" to density,"reusable_buffer" to (reusable!=null)))
        try {
        diagnostics.measure("render.index_update"){index.update(snapshot.strokes)}
        var queryNs=0L;var compareNs=0L;var compositeNs=0L;var rasterNs=0L
        var hits=0;var misses=0;var pointsVisited=0L
        val swapped=rotation==90 || rotation==270
        val w=if(swapped)height else width;val h=if(swapped)width else height
        val image=if(reusable!=null && reusable.width==w && reusable.height==h)reusable else {
            reusable?.recycle();Bitmap.createBitmap(w,h,Bitmap.Config.ARGB_8888)
        }
        val canvas=Canvas(image);canvas.drawColor(Color.WHITE)
        val source=listOf(InkPoint(0.0,0.0),InkPoint(width.toDouble(),0.0),InkPoint(0.0,height.toDouble()))
        val destination=source.map{InkCoordinates.viewToPanel(it,rotation,width.toDouble(),height.toDouble())}
        fun points(p:List<InkPoint>)=p.flatMap{listOf(it.x.toFloat(),it.y.toFloat())}.toFloatArray()
        val matrix=Matrix();check(matrix.setPolyToPoly(points(source),0,points(destination),0,3));canvas.save();canvas.concat(matrix)
        val view=snapshot.view;val scale=view.scale*density;val size=512.0/scale
        val left=-view.x/view.scale;val top=-view.y/view.scale
        val right=left+width/scale;val bottom=top+height/scale
        NativeInkPainter.draw(canvas,InkModel(emptyList(),view,emptyList(),snapshot.boards),density)
        canvas.restore()
        // Tiles already contain scaled pixels. Composite by translation, avoiding a resampling matrix.
        for(y in floor(top/size).toInt()..floor(bottom/size).toInt())for(x in floor(left/size).toInt()..floor(right/size).toInt()) {
            val key=Key(x,y,scale,rotation)
            val bounds=InkBounds(x*size-1/scale,y*size-1/scale,(x+1)*size+1/scale,(y+1)*size+1/scale)
            val queryStart=System.nanoTime()
            val visible=index.query(bounds)
            queryNs+=System.nanoTime()-queryStart
            var tile=tiles[key]
            val compareStart=System.nanoTime()
            val dirty=tile==null || tile.strokes!=visible
            compareNs+=System.nanoTime()-compareStart
            if(dirty) {
                misses++
                val tileWork=drawingCounts(visible)
                pointsVisited+=visible.sumOf{it.points.size.toLong()}
                val tileSpan=diagnostics.begin("render.tile",tileWork)
                val rasterStart=System.nanoTime()
                val bitmap=Bitmap.createBitmap(512,512,Bitmap.Config.ARGB_8888)
                val local=Canvas(bitmap)
                // Rasterize vectors into panel orientation once. Every cached frame can then
                // use fast translation-only blits, even on tablets whose panel is rotated.
                val tileSource=listOf(InkPoint(0.0,0.0),InkPoint(512.0,0.0),InkPoint(0.0,512.0))
                val tileDestination=tileSource.map{InkCoordinates.viewToPanel(it,rotation,512.0,512.0)}
                val tileMatrix=Matrix();check(tileMatrix.setPolyToPoly(points(tileSource),0,points(tileDestination),0,3))
                local.concat(tileMatrix)
                NativeInkPainter.draw(local,InkModel(visible,InkViewport(-x*512.0,-y*512.0,scale),emptyList()),1.0)
                tile=Tile(bitmap,visible);tiles.put(key,tile);metrics.record("tile_miss",1.0)
                rasterNs+=System.nanoTime()-rasterStart
                tileSpan.end()
            } else {hits++;metrics.record("tile_hit",1.0)}
            val compositeStart=System.nanoTime()
            val viewLeft=x*512.0+view.x*density;val viewTop=y*512.0+view.y*density
            val a=InkCoordinates.viewToPanel(InkPoint(viewLeft,viewTop),rotation,width.toDouble(),height.toDouble())
            val b=InkCoordinates.viewToPanel(InkPoint(viewLeft+512,viewTop+512),rotation,width.toDouble(),height.toDouble())
            canvas.drawBitmap(tile!!.image,min(a.x,b.x).toFloat(),min(a.y,b.y).toFloat(),null)
            compositeNs+=System.nanoTime()-compositeStart
        }
        metrics.record("render_ms",(System.nanoTime()-started)/1e6)
        metrics.record("cache_bytes",tiles.bytes.toDouble())
        diagnostics.event("render.breakdown",mapOf("query_ms" to queryNs/1e6,"compare_ms" to compareNs/1e6,"raster_ms" to rasterNs/1e6,"composite_ms" to compositeNs/1e6,"hits" to hits,"misses" to misses,"replayed_points" to pointsVisited,"cache_bytes" to tiles.bytes,"panel_bytes" to image.allocationByteCount))
        return image
        } finally {renderSpan.end()}
    }
    fun close(){tiles.clear()}
}
