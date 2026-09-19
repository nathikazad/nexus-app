package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class InkBoardsTest {
    private val boards=InkBoards(800.0,1000.0)
    @Test fun quarterStepsAndAdjacentJumpsWorkInAllDirections() {
        for((dx,dy) in listOf(1 to 0,-1 to 0,0 to 1,0 to -1)) {
            val quarter=boards.navigate(InkViewport(),dx,dy,false,800.0,1000.0)
            assertEquals(-dx*200.0,quarter.x,0.0);assertEquals(-dy*250.0,quarter.y,0.0)
            val jump=boards.navigate(InkViewport(),dx,dy,true,800.0,1000.0)
            assertEquals(InkBoard(dx,dy),boards.current(jump,800.0,1000.0))
            assertEquals(-dx*800.0,jump.x,0.0);assertEquals(-dy*1000.0,jump.y,0.0)
        }
    }
    @Test fun jumpAlignsToBoardFromQuarterOffsetAndFitsChangedScreen() {
        val base=InkViewport(-200.0,0.0)
        assertEquals(InkViewport(-800.0,0.0),boards.navigate(base,1,0,true,800.0,1000.0))
        val fitted=boards.view(InkBoard(-2,-3),400.0,500.0)
        assertEquals(.5,fitted.scale,0.0)
        assertEquals(InkBoard(-2,-3),boards.current(fitted,400.0,500.0))
    }
    @Test fun sparseSegmentsPopulateOnlyCrossedBoardsIncludingNegatives() {
        val stroke=NativeStroke("a",listOf(InkPoint(-1200.0,500.0),InkPoint(2000.0,500.0)),0xff000000L,3.0)
        assertEquals((-2..2).map{InkBoard(it,0)}.toSet(),boards.populated(listOf(stroke)))
        val diagonal=stroke.copy(points=listOf(InkPoint(10.0,10.0),InkPoint(1590.0,1990.0)))
        assertEquals(setOf(InkBoard(0,0),InkBoard(1,1)),boards.populated(listOf(diagonal)))
        assertTrue(boards.populated(emptyList()).isEmpty())
    }
    @Test fun erasingAndUndoChangePopulationWithoutStoringEmptyBoards() {
        val dot=NativeStroke("a",listOf(InkPoint(-20.0,-20.0)),0xff000000L,3.0)
        val model=InkModel(listOf(dot),InkViewport(),emptyList(),boards)
        model.erase(listOf(InkPoint(-20.0,-20.0)),20.0)
        assertTrue(boards.populated(model.strokes).isEmpty())
        model.undo();assertEquals(setOf(InkBoard(-1,-1)),boards.populated(model.strokes))
        assertEquals(boards,InkCodec.model(InkCodec.encode(model)).boards)
    }
    @Test fun tapAndHoldAreExclusiveAndHoldFiresOnlyOnce() {
        val press=BoardPressTracker()
        press.down();assertTrue(press.up());assertFalse(press.hold())
        press.down();assertTrue(press.hold());assertFalse(press.hold());assertFalse(press.up())
        press.down();press.cancel();assertFalse(press.hold());assertFalse(press.up())
        press.down();assertTrue(press.up())
    }
}
