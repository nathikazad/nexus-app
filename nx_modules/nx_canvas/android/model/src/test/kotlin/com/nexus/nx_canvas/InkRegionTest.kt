package com.nexus.nx_canvas

import kotlin.math.*
import org.junit.Assert.*
import org.junit.Test

class InkRegionTest {
    @Test fun optimizedClippingMatchesOriginalAcrossRandomPolygonsAndStrokeSegments() {
        val random=java.util.Random(83)
        repeat(150) { iteration ->
            val polygon=(0 until 12).map { i ->
                val angle=i*2*PI/12;val radius=10+random.nextDouble()*90
                InkPoint(cos(angle)*radius,sin(angle)*radius)
            }
            val region=InkRegion(polygon)
            repeat(12) { n ->
                val stroke=NativeStroke("$iteration:$n",(0 until 8).map {
                    InkPoint(random.nextDouble()*600-300,random.nextDouble()*600-300,random.nextDouble())
                },0xff000000,3.0)
                val expected=ReferenceInkGeometry.region(stroke,polygon)
                val actual=region.erase(stroke)
                assertEquals(expected.size,actual.size)
                expected.zip(actual).forEach { (a,b) ->
                    assertEquals(a.points.size,b.points.size)
                    a.points.zip(b.points).forEach { (p,q) ->
                        assertEquals(p.x,q.x,1e-7);assertEquals(p.y,q.y,1e-7);assertEquals(p.pressure,q.pressure,1e-7)
                    }
                }
            }
        }
    }
    @Test fun distantDenseBoardsRetainOriginalStrokeObjects() {
        val region=InkRegion(listOf(InkPoint(10.0,10.0),InkPoint(50.0,10.0),InkPoint(50.0,50.0),InkPoint(10.0,50.0)))
        repeat(875) { n ->
            val stroke=NativeStroke("$n",(0 until 89).map{InkPoint(1000.0+it,n.toDouble())},0,3.0)
            assertSame(stroke,region.erase(stroke).single())
        }
    }
    @Test fun rubBoundsPreserveOriginalClipping() {
        val s=NativeStroke("s",listOf(InkPoint(-100.0,0.0,.2),InkPoint(100.0,0.0,.8)),0,4.0)
        for(center in listOf(InkPoint(0.0,0.0),InkPoint(0.0,12.0),InkPoint(0.0,100.0))) {
            assertEquals(ReferenceInkGeometry.disk(s,center,10.0).map{it.points},InkGeometry.disk(s,center,10.0).map{it.points})
        }
    }
}
