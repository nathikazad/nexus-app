package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class InkCoordinatesTest {
    @Test fun foregroundAndCapturedInkRoundTripAcrossEveryOrientation() {
        // Non-square canvas, corners and an asymmetric shape catch rotations
        // and width/height exchanges in the foreground-to-record round trip.
        val shape=listOf(InkPoint(0.0,0.0),InkPoint(1000.0,0.0),InkPoint(0.0,2000.0),InkPoint(120.0,300.0,.6),InkPoint(450.0,320.0,.4))
        for(rotation in listOf(0,90,180,270))for(p in shape) {
            val panel=InkCoordinates.viewToPanel(p,rotation,1000.0,2000.0)
            assertEquals(p,InkCoordinates.panelToView(panel,rotation,1000.0,2000.0))
            assertTrue(panel.x in 0.0..(if(rotation==90||rotation==270)2000.0 else 1000.0))
            assertTrue(panel.y in 0.0..(if(rotation==90||rotation==270)1000.0 else 2000.0))
        }
        assertEquals(InkPoint(1700.0,120.0,.6),InkCoordinates.viewToPanel(InkPoint(120.0,300.0,.6),90,1000.0,2000.0))
    }

    @Test fun firmwarePanelPointsMatchTheSameVisiblePointInEveryOrientation() {
        val expected=InkPoint(120.0,300.0,.6)
        val panelPoints=mapOf(0 to expected,90 to InkPoint(1700.0,120.0,.6),180 to InkPoint(880.0,1700.0,.6),270 to InkPoint(300.0,880.0,.6))
        panelPoints.forEach { (rotation,p) ->
            assertEquals(expected,InkCoordinates.panelToView(p,rotation,1000.0,2000.0))
        }
    }
    @Test fun convertedPointsKeepTheirWorldPositionAtNonDefaultZoom() {
        val local=InkCoordinates.panelToView(InkPoint(300.0,880.0),270,1000.0,2000.0)
        val world=InkViewport(10.0,-20.0,2.0).world(InkPoint(local.x/2,local.y/2))
        assertEquals(25.0,world.x,1e-9);assertEquals(85.0,world.y,1e-9)
    }
    @Test fun magnifierKeepsTappedWorldPointFixedAndPreviousRestoresView() {
        val model=InkModel(emptyList(),InkViewport(40.0,-20.0,.8),emptyList())
        val before=model.view;val tap=InkPoint(150.0,300.0);val world=before.world(tap)
        model.zoom(2.0,tap)
        assertEquals(1.6,model.view.scale,1e-9)
        assertEquals(world,model.view.world(tap))
        model.back();assertEquals(before,model.view)
    }
}
