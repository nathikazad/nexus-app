package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class InkOverviewLayoutTest {
    @Test fun negativeAndSparseBoardsFitAndOnlyPopulatedCellsAreClickable() {
        val cells=setOf(InkBoard(-2,-1),InkBoard(1,1))
        val layout=InkOverviewLayout.calculate(InkBoards(800.0,1000.0),cells,1000,800,20.0)
        for((cell,box) in layout.boxes) {
            assertTrue(box.left>=19.999 && box.right<=980.001)
            assertTrue(box.top>=19.999 && box.bottom<=780.001)
            assertEquals(cell,layout.hit((box.left+box.right)/2,(box.top+box.bottom)/2))
        }
        assertNull(layout.hit(500.0,400.0));assertNull(layout.hit(0.0,0.0))
    }
    @Test fun emptyCanvasHasNoHitTargets() {
        assertTrue(InkOverviewLayout.calculate(InkBoards(1.0,1.0),emptySet(),100,100,20.0).boxes.isEmpty())
    }
}
