package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class InkModelTest {
    private fun line()=NativeStroke("line",listOf(InkPoint(0.0,0.0,.2),InkPoint(100.0,0.0,.8)),0xff000000L,2.0)
    private val box=listOf(InkPoint(40.0,-20.0),InkPoint(60.0,-20.0),InkPoint(60.0,20.0),InkPoint(40.0,20.0))
    @Test fun regionSplitsSparseInkAndRetainsPressure() {
        val pieces=InkGeometry.region(line(),box)
        assertEquals(2,pieces.size);assertEquals(40.0,pieces[0].points.last().x,1e-8)
        assertEquals(60.0,pieces[1].points.first().x,1e-8)
        assertEquals(.44,pieces[0].points.last().pressure,1e-8)
        assertNotEquals(pieces[0].id,pieces[1].id)
    }
    @Test fun regionHandlesContainedDotsMissesAndDegenerateLoops() {
        assertTrue(InkGeometry.region(line().copy(points=listOf(InkPoint(50.0,0.0))),box).isEmpty())
        assertTrue(InkGeometry.region(line().copy(points=listOf(InkPoint(40.0,0.0))),box).isEmpty())
        val miss=line().copy(points=listOf(InkPoint(0.0,50.0),InkPoint(100.0,50.0)))
        assertEquals(listOf(miss),InkGeometry.region(miss,box))
        assertEquals(listOf(line()),InkGeometry.region(line(),listOf(InkPoint(0.0,0.0),InkPoint(50.0,0.0),InkPoint(100.0,0.0))))
    }
    @Test fun concaveRegionPreservesNotch() {
        val u=listOf(InkPoint(20.0,-20.0),InkPoint(80.0,-20.0),InkPoint(80.0,20.0),InkPoint(60.0,20.0),InkPoint(60.0,-10.0),InkPoint(40.0,-10.0),InkPoint(40.0,20.0),InkPoint(20.0,20.0))
        val pieces=InkGeometry.region(line(),u)
        assertEquals(3,pieces.size);assertEquals(40.0,pieces[1].points.first().x,1e-8);assertEquals(60.0,pieces[1].points.last().x,1e-8)
    }
    @Test fun rubCutsCrossedStrokeAndUndoIsOneGesture() {
        val model=InkModel(listOf(line()),InkViewport(scale=2.0),emptyList())
        model.erase(listOf(InkPoint(50.0,-100.0),InkPoint(50.0,100.0)),9.0)
        assertEquals(2,model.strokes.size)
        model.undo();assertEquals(listOf(line()),model.strokes);assertEquals(2.0,model.view.scale,0.0)
        model.redo();assertEquals(2,model.strokes.size)
    }
    @Test fun regionUndoAndCodecKeepEditableFragments() {
        val model=InkModel(listOf(line()),InkViewport(10.0,-50.0,.7),listOf(InkPlace("Opening",InkViewport())))
        model.eraseRegion(box);val encoded=InkCodec.encode(model)
        val restored=InkCodec.model(encoded);assertEquals(encoded,InkCodec.encode(restored))
        model.undo();assertEquals(listOf(line()),model.strokes)
        model.redo();assertEquals(2,model.strokes.size)
    }
    @Test fun selectionMovesInkAndViewHistoryIsIndependent() {
        val model=InkModel(listOf(line()),InkViewport(),emptyList())
        model.select(box);assertEquals(setOf("line"),model.selected)
        model.moveSelection(InkPoint(10.0,20.0));assertEquals(10.0,model.strokes.first().points.first().x,0.0)
        model.zoom(2.0,InkPoint(100.0,100.0));model.undo()
        assertEquals(listOf(line()),model.strokes);assertEquals(2.0,model.view.scale,0.0)
        model.back();assertEquals(InkViewport(),model.view)
    }
}
