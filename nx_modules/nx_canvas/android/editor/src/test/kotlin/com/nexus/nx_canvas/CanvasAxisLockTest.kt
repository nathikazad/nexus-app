package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class CanvasAxisLockTest {
    @Test fun jitterDoesNotChooseAxis() {
        val lock=CanvasAxisLock(8.0)
        assertEquals(InkPoint(0.0,0.0),lock.movement(2.0,3.0))
        assertEquals(InkPoint(20.0,0.0),lock.movement(20.0,9.0))
    }
    @Test fun horizontalStaysHorizontalDespiteLaterDiagonalMotion() {
        val lock=CanvasAxisLock(8.0)
        assertEquals(InkPoint(-20.0,0.0),lock.movement(-20.0,9.0))
        assertEquals(InkPoint(-25.0,0.0),lock.movement(-25.0,100.0))
    }
    @Test fun verticalStaysVerticalUntilNextGesture() {
        val lock=CanvasAxisLock(8.0)
        assertEquals(InkPoint(0.0,-20.0),lock.movement(9.0,-20.0))
        assertEquals(InkPoint(0.0,-25.0),lock.movement(100.0,-25.0))
        lock.reset()
        assertEquals(InkPoint(20.0,0.0),lock.movement(20.0,9.0))
    }
}
