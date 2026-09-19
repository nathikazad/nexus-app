package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class NativeStrokeCaptureTest {
    class Point(private val x:Double,private val y:Double) {
        fun getX()=x; fun getY()=y; fun getPressure()=512.0
    }
    open class BaseRecord(@JvmField val type:Int) {
        @JvmField val points=listOf(Point(0.0,0.0),Point(100.0,0.0),Point(100.0,100.0),Point(0.0,100.0),Point(0.0,0.0))
        @JvmField val maxPressure=1024.0
        @JvmField val minPressure=0.0
        @JvmField val strokeWidth=20
    }
    class PenRecord:BaseRecord(101) { @JvmField val color=0xff123456.toInt() }
    class RubberRecord:BaseRecord(201)
    class RegionRecord:BaseRecord(202)
    private val transform=InputTransform(InkViewport(),0,800,1000,1.0)
    @Test fun penKeepsColorAndPressure() {
        val op=NativeStrokeCapture.decode(PenRecord(),transform)!!
        assertEquals(InkOperationKind.DRAW,op.kind)
        assertEquals(0xff123456L,op.stroke.color)
        assertEquals(.5,op.stroke.points.first().pressure,0.0)
    }
    @Test fun bothErasersDecodeWithoutPenOnlyColorAndAllowDocumentClose() {
        for(record in listOf(RubberRecord(),RegionRecord())) {
            val engine=CanvasEngine("test",InkSnapshot(emptyList(),InkViewport(),emptyList(),null))
            val direct=CanvasExecutor { it() }
            val input=CanvasInputCoordinator(engine,direct,direct,changed={},settled={},failed={throw it})
            input.accept(InputEvent.Completed(object:CanvasInputRecord {
                override val completesStroke=true
                override fun decode(transform:InputTransform)=NativeStrokeCapture.decode(record,transform)
            }),transform)
            assertFalse(input.importFailed)
            assertEquals(DrainResult.Complete,input.drain())
            val scheduler=object:CanvasScheduler {
                override fun execute(work:()->Unit)=work()
                override fun after(milliseconds:Long,work:()->Unit)=Cancellation {}
            }
            var closed=false
            CanvasActionGate({input.drain()},scheduler).submit({closed=true},{fail("Blocked by eraser")})
            assertTrue(closed)
        }
    }
    @Test fun regionErasureActuallyRemovesEnclosedInk() {
        val model=InkModel(listOf(NativeStroke("inside",listOf(InkPoint(50.0,50.0)),0,3.0)),InkViewport(),emptyList())
        NativeStrokeCapture.decode(RegionRecord(),transform)!!.apply(model)
        assertTrue(model.strokes.isEmpty())
    }
}
