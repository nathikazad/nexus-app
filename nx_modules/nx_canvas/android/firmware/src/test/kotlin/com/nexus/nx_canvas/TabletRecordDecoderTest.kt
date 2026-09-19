package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class TabletRecordDecoderTest {
    class Point { fun getX()=100.0;fun getY()=200.0;fun getPressure()=512.0 }
    class Record {
        @JvmField val type=101
        @JvmField val points=listOf(Point())
        @JvmField val maxPressure=1024.0
        @JvmField val minPressure=0.0
        @JvmField val strokeWidth=6
        @JvmField val color=0xff000000.toInt()
    }
    @Test fun recordDecoderOwnsFirmwareToWorldConversion() {
        val op=NativeStrokeCapture.decode(Record(),InputTransform(InkViewport(10.0,20.0,2.0),0,800,1000,2.0))!!
        assertEquals(InkOperationKind.DRAW,op.kind);assertEquals(1.5,op.stroke.width,0.0)
        assertEquals(InkPoint(20.0,40.0,.5),op.stroke.points.single())
        assertEquals(0xff000000L,op.stroke.color)
    }
}
