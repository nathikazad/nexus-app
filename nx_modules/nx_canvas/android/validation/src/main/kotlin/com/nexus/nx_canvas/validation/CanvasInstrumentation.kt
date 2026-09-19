package com.nexus.nx_canvas.validation

import android.app.Instrumentation
import android.app.Activity
import android.os.Bundle
import com.nexus.nx_canvas.*

/** Runs in a separate package; never opens or alters the user's Docs library. */
class CanvasInstrumentation:Instrumentation() {
    class Point { fun getX()=30.0;fun getY()=30.0;fun getPressure()=1.0 }
    class Record {
        @JvmField val type=101
        @JvmField val points=listOf(Point(),Point())
        @JvmField val maxPressure=1.0
        @JvmField val minPressure=0.0
        @JvmField val strokeWidth=3
        @JvmField val color=0xff000000.toInt()
    }
    private val repository get()=CanvasServices.repository(targetContext)
    private fun waitSaved(count:Int) {
        val deadline=System.currentTimeMillis()+10000
        while(System.currentTimeMillis()<deadline) {
            val saved=repository.io.submit<InkJournal.Saved?>{repository.journal().read()}.get()
            if(saved?.snapshot?.strokes?.size==count)return
            Thread.sleep(25)
        }
        error("Stroke autosave did not become durable: $count")
    }
    override fun onCreate(arguments:Bundle?) {super.onCreate(arguments);start()}
    override fun onStart() {
        val output=Bundle()
        try {
            java.io.File(targetContext.getExternalFilesDir(null),"canvas-diagnostics").deleteRecursively()
            CanvasDiagnostics.start(targetContext)
            CanvasDiagnostics.transitionStart("validation")
            runOnMainSync { CanvasDiagnostics.measure("validation.main_stall") { Thread.sleep(1600) } }
            Thread.sleep(500)
            val diagnosticFile=java.io.File(targetContext.getExternalFilesDir(null),"canvas-diagnostics/events.jsonl")
            val records=diagnosticFile.readLines().map{org.json.JSONObject(it)}
            check(records.any{it.optString("event")=="main.stall" && (it.optJSONArray("main_stack")?.length() ?: 0) > 0}){"Watchdog did not capture blocked main thread"}
            check(records.any{it.optString("event")=="main.recovered"}){"Watchdog did not capture recovery"}
            check(records.any{it.optString("stage")=="validation.main_stall" && it.optDouble("wall_ms")>=1500}){"Timing span missing"}
            CanvasDiagnostics.transitionEnd()
            val strokes=(0..2).flatMap{board->(0..199).map{line->
                NativeStroke("$board-$line",listOf(InkPoint(board*800.0+10,line*3.0+20),InkPoint(board*800.0+700,line*3.0+21)),0xff000000L,3.0)
            }} + NativeStroke("crossing",listOf(InkPoint(-300.0,400.0),InkPoint(1900.0,500.0)),0xff000000L,4.0)
            val metrics=InkMetrics();val renderer=NativeTileRenderer(metrics)
            for(rotation in listOf(0,90,180,270)) for(zoom in listOf(1.0,2.134)) for(fraction in listOf(0.0,0.25)) {
                val snapshot=InkSnapshot(strokes,InkViewport(-200.0-fraction,-50.0-fraction,zoom),emptyList(),InkBoards(800.0,1000.0))
                val expected=NativeInkPainter.panelBitmap(snapshot.model(),1.0,800,1000,rotation)
                val actual=renderer.render(snapshot,1.0,800,1000,rotation,null)
                val a=IntArray(actual.width*actual.height);val b=IntArray(a.size)
                actual.getPixels(a,0,actual.width,0,0,actual.width,actual.height)
                expected.getPixels(b,0,expected.width,0,0,expected.width,expected.height)
                // Tile clipping and fractional placement change antialias coverage at edges.
                // Keep the original strict 1x comparison; at zoom/fractional positions
                // compare ink coverage within one pixel, in both directions.
                fun matches(source:IntArray,target:IntArray,i:Int):Boolean {
                    if(kotlin.math.abs((source[i] and 255)-(target[i] and 255))<=24)return true
                    if(fraction==0.0 && zoom==1.0)return false
                    val x=i%actual.width;val y=i/actual.width
                    return (-1..1).any{dy->(-1..1).any{dx->
                        val nx=x+dx;val ny=y+dy
                        nx in 0 until actual.width && ny in 0 until actual.height &&
                            ((source[i] and 255)<128) == ((target[ny*actual.width+nx] and 255)<128)
                    }}
                }
                val different=a.indices.count{!matches(a,b,it) || !matches(b,a,it)}
                check(different<a.size/200){"Raster mismatch at $rotation / $zoom / $fraction: $different pixels"}
                metrics.drain()
                check(renderer.render(snapshot,1.0,800,1000,rotation,actual)===actual)
                check("tile_miss" !in metrics.drain()){"Unchanged tiles rerendered"}
                actual.recycle();expected.recycle()
            }
            // Compare the former full-scene renderer with cold and cached tile renders
            // at this tablet's actual pixel size. Timing is reported, not a flaky assertion.
            val dm=targetContext.resources.displayMetrics
            val bench=InkSnapshot(strokes,InkViewport(),emptyList(),null)
            val oldStart=System.nanoTime()
            val old=NativeInkPainter.panelBitmap(bench.model(),1.0,dm.widthPixels,dm.heightPixels,0)
            val oldMs=(System.nanoTime()-oldStart)/1e6;old.recycle()
            val coldStart=System.nanoTime()
            var frame=renderer.render(bench,1.0,dm.widthPixels,dm.heightPixels,0,null)
            val coldMs=(System.nanoTime()-coldStart)/1e6
            val warmStart=System.nanoTime()
            frame=renderer.render(bench.copy(view=InkViewport(-100.0,0.0)),1.0,dm.widthPixels,dm.heightPixels,0,frame)
            val warmMs=(System.nanoTime()-warmStart)/1e6;frame.recycle()
            output.putString("benchmark","Full redraw: $oldMs ms; cold tiles: $coldMs ms; nearby cached pan: $warmMs ms")
            renderer.close()
            // Dense overview uses software rasterization off main; UI only composites the result.
            val dense=(0 until 875).map { n -> NativeStroke("dense-$n",(0 until 89).map { i ->
                InkPoint((n%3)*800.0+20+i*8.0,(n/3%290)*3.0+20+kotlin.math.sin(i.toDouble())*3)
            },0xff000000L,3.0) }
            val overviewStart=System.nanoTime()
            val overview=CanvasOverviewPreview.prepare(InkModel(dense,InkViewport(),emptyList(),InkBoards(800.0,1000.0)),
                dm.widthPixels,dm.heightPixels,dm.density,DefaultOverviewRenderer(),CanvasDiagnostics)
            val overviewMs=(System.nanoTime()-overviewStart)/1e6
            check(overview.layout.boxes.size==3)
            val display=android.graphics.Bitmap.createBitmap(dm.widthPixels,dm.heightPixels,android.graphics.Bitmap.Config.ARGB_8888)
            var compositeMs=0.0
            runOnMainSync {
                val start=System.nanoTime()
                android.graphics.Canvas(display).drawBitmap(overview.image,0f,0f,null)
                compositeMs=(System.nanoTime()-start)/1e6
            }
            overview.image.recycle();display.recycle()
            val regionPath=(0 until 150).map { i -> val a=i*2*Math.PI/150; InkPoint(40+20*kotlin.math.cos(a),45+20*kotlin.math.sin(a)) }
            val erasure=InkModel(dense,InkViewport(),emptyList(),InkBoards(800.0,1000.0))
            val eraseStart=System.nanoTime();erasure.eraseRegion(regionPath)
            output.putString("eraseBenchmark","77,875 points / 150-point eraser: ${(System.nanoTime()-eraseStart)/1e6} ms")
            output.putString("overviewBenchmark","77,875 points: worker preview $overviewMs ms; main composite $compositeMs ms")
            // Exercise the real firmware activity with synthetic, isolated input.
            repository.document()?.get("saveToken")?.let{repository.acknowledgeDocument(it as String)}
            repository.write("input",mapOf("documentId" to "validation","title" to "Canvas validation")+InkCodec.encode(InkModel(strokes,InkViewport(),emptyList(),InkBoards(800.0,1000.0))))
            // Same-process handoff and restart fallback must decode identical ink.
            val cachedScene = InkCodec.model(repository.scene())
            val diskScene = InkCodec.model(CanvasRepository(targetContext).scene())
            check(InkSnapshot.of(cachedScene) == InkSnapshot.of(diskScene)) { "Prepared scene differs from durable fallback" }
            val activity=startActivitySync(android.content.Intent(targetContext,NativeEditorActivity::class.java).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK))
            waitForIdleSync()
            val screen=NativeEditorActivity::class.java.getDeclaredField("screen").apply{isAccessible=true}.get(activity)
            val deadline=System.currentTimeMillis()+10000
            val ready=CanvasEditorScreen::class.java.getDeclaredField("ready").apply{isAccessible=true}
            while(!ready.getBoolean(screen) && System.currentTimeMillis()<deadline)Thread.sleep(50)
            check(ready.getBoolean(screen)){"Firmware surface did not initialize"}
            // The firmware callback is the boundary: simulate completed vendor records,
            // then verify the real async import + per-stroke durable journal, including deduplication.
            val ink=CanvasEditorScreen::class.java.getDeclaredField("ink").apply{isAccessible=true}.get(screen) as RecordingNoteView
            // Use the actual firmware input queue and drawing thread for one stroke.
            Thread.sleep(2000)
            val input=Class.forName("com.xrz.NoteView").getMethod("onInputTouch", *Array(5){Int::class.javaPrimitiveType})
            runOnMainSync {
                input.invoke(ink,1,500,700,1024,1)
                input.invoke(ink,2,550,750,1024,1)
                input.invoke(ink,3,600,800,0,1)
            }
            waitSaved(strokes.size+1)
            val vendorPoints=ink.getRecordList().let { list ->
                val record=(list as java.util.LinkedList<*>).last!!
                record.javaClass.getField("points").get(record)
            }
            // Two real contacts must remain separate without synthetic stroke edges.
            // Use firmware tool 0 (pen), matching the physical tablet trace.
            runOnMainSync {
                input.invoke(ink,1,620,820,1024,0)
                input.invoke(ink,2,622,822,1024,0)
                input.invoke(ink,3,622,822,0,0)
                input.invoke(ink,1,625,825,1024,0)
                input.invoke(ink,2,650,850,1024,0)
                input.invoke(ink,3,680,880,0,0)
            }
            waitSaved(strokes.size+3)
            val first=Record();val second=Record()
            runOnMainSync { ink.onRecord!!.invoke(first) }
            waitSaved(strokes.size+4)
            runOnMainSync { ink.onRecord!!.invoke(first);ink.onRecord!!.invoke(second) }
            waitSaved(strokes.size+5)
            val navigate=CanvasEditorScreen::class.java.getDeclaredMethod("navigateBoard",Int::class.javaPrimitiveType,Int::class.javaPrimitiveType,Boolean::class.javaPrimitiveType).apply{isAccessible=true}
            runOnMainSync { repeat(8){navigate.invoke(screen,1,0,false)} }
            Thread.sleep(1500);waitForIdleSync()
            var model: InkModel? = null
            runOnMainSync { model=(CanvasEditorScreen::class.java.getDeclaredField("engine").apply{isAccessible=true}.get(screen) as CanvasEngine).presentation() }
            check(model!!.view.x < -1000){"Rapid board taps were lost: ${model!!.view}"}
            val saved=repository.io.submit<InkJournal.Saved?>{repository.journal().read()}.get()!!
            check(saved.snapshot.strokes.size==strokes.size+5){"Navigation changed ink"}
            output.putString("stream","${output.getString("benchmark")}\n${output.getString("overviewBenchmark")}\nPASS: local diagnostic spans, stalled main-thread stacks and recovery, four rotations, tile cache reuse, firmware launch, queued navigation, firmware pen-up autosave, duplicate completion, durable background saves\nMetrics: ${"session-owned metrics"}")
            // Actual vendor eraser records inherit geometry but have no color field.
            for(name in listOf("Rubber","RegionRubber")) {
                val outer=Class.forName("com.xrz.$name")
                val recordClass=Class.forName("com.xrz.$name\$${name}Record")
                val record=recordClass.getConstructor(outer).newInstance(outer.getConstructor().newInstance())
                recordClass.getField("points").set(record,vendorPoints)
                check(NativeStrokeCapture.decode(record,InputTransform(InkViewport(),0,800,1000,1.0))!=null)
                runOnMainSync { ink.onRecord!!.invoke(record) }
            }
            val session=CanvasEditorScreen::class.java.getDeclaredField("session").apply{isAccessible=true}.get(screen) as CanvasSessionResources
            val importDeadline=System.currentTimeMillis()+10000
            var drained=false
            while(!drained && System.currentTimeMillis()<importDeadline) {
                runOnMainSync { drained=session.imports.drain()==DrainResult.Complete }
                Thread.sleep(25)
            }
            check(drained){"Eraser import blocked navigation/document return"}
            Thread.sleep(600);waitForIdleSync()
            check(diagnosticFile.readLines().any { org.json.JSONObject(it).optString("event") == "overlay.repair" }) {
                "Completed eraser did not request navigation overlay repair"
            }
            // Reproduce the actual two-stream race: firmware down can precede the
            // Android stylus-button event. Then release/toggle while points are queued.
            fun button(held:Boolean) {
                val properties=android.view.MotionEvent.PointerProperties().apply { id=0;toolType=android.view.MotionEvent.TOOL_TYPE_STYLUS }
                val coords=android.view.MotionEvent.PointerCoords().apply { x=500f;y=700f;pressure=1f }
                val now=android.os.SystemClock.uptimeMillis()
                val event=android.view.MotionEvent.obtain(now,now,android.view.MotionEvent.ACTION_MOVE,1,arrayOf(properties),arrayOf(coords),0,
                    if(held)android.view.MotionEvent.BUTTON_STYLUS_PRIMARY else 0,1f,1f,0,0,android.view.InputDevice.SOURCE_STYLUS,0)
                (screen as CanvasEditorScreen).dispatchGenericMotionEvent(event){false};event.recycle()
            }
            fun waitInput() {
                val until=System.currentTimeMillis()+10000
                var idle=false
                while(!idle && System.currentTimeMillis()<until) {
                    runOnMainSync { idle=session.imports.drain()==DrainResult.Complete && ink.isDrained() }
                    Thread.sleep(25)
                }
                check(idle){"Input remained blocked after stylus tool transition"}
                check(!session.imports.importFailed)
            }
            Thread.sleep(1200)
            repeat(4) { iteration ->
                runOnMainSync {
                    if(iteration%2==0)button(true) // button before firmware down
                    input.invoke(ink,1,500,700,1024,1)
                    input.invoke(ink,2,520,710,1024,1)
                    if(iteration%2==1)button(true) // firmware down before button
                    input.invoke(ink,2,560,710,1024,1)
                    input.invoke(ink,2,560,760,1024,1)
                    button(false) // release while still drawing, before raw up
                    input.invoke(ink,2,500,760,1024,1)
                    input.invoke(ink,3,500,700,0,1)
                }
                waitInput()
            }
            val switch=CanvasEditorScreen::class.java.getDeclaredMethod("switchTool",NativeTool::class.java).apply{isAccessible=true}
            runOnMainSync { switch.invoke(screen,NativeTool.REGION) }
            waitInput()
            runOnMainSync {
                input.invoke(ink,1,500,700,1024,1);input.invoke(ink,2,600,700,1024,1)
                input.invoke(ink,2,600,800,1024,1);input.invoke(ink,2,500,800,1024,1)
                input.invoke(ink,3,500,700,0,1)
                (screen as CanvasEditorScreen).onBackPressed() // close before worker has processed region
            }
            val closeDeadline=System.currentTimeMillis()+10000
            while(!activity.isFinishing && System.currentTimeMillis()<closeDeadline)Thread.sleep(25)
            check(activity.isFinishing){"Document button did not finish after eraser input"}
            output.putString("stream",output.getString("stream")+"\n${output.getString("eraseBenchmark")}\nPASS: real erasers, both stylus/firmware event orders, mid-stroke toggles, toolbar region erase and immediate document return")
            finish(Activity.RESULT_OK,output)
        } catch(error:Throwable) {
            output.putString("stream","FAIL: ${error.stackTraceToString()}")
            finish(Activity.RESULT_CANCELED,output)
        }
    }
}
