package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class BigmeStrokeRecordTest {
    @Test fun selectsByFirmwareCapabilityAndPreservesLargerTabletBackend() {
        assertEquals(CanvasInkBackend.NOTE_VIEW, canvasInkBackend { true })
        assertEquals(CanvasInkBackend.BIGME, canvasInkBackend { it != "com.xrz.NoteView" })
        assertNull(canvasInkBackend { it == "com.xrz.HandwrittenClient" })
        assertNull(canvasInkBackend { false })
    }
    @Test fun cookedCoordinatesRespectZoomDensityAndPanWithoutDoubleRotation() {
        val record = BigmeStrokeRecord(NativeTool.PEN, 12.0, listOf(InkPoint(80.0, 120.0)))
        val op = record.decode(InputTransform(InkViewport(10.0, 20.0, 2.0), 90, 800, 1000, 2.0))!!
        assertEquals(InkOperationKind.DRAW, op.kind)
        assertEquals(15.0, op.stroke.points.single().x, .001)
        assertEquals(20.0, op.stroke.points.single().y, .001)
        assertEquals(3.0, op.stroke.width, .001)
        assertEquals(0xff000000L, op.stroke.color)
    }
    @Test fun erasersBecomeEditableGeometryOperationsInsteadOfWhiteStrokes() {
        val transform = InputTransform(InkViewport(), 0, 800, 1000, 1.0)
        val points = listOf(InkPoint(10.0, 20.0), InkPoint(20.0, 30.0))
        assertEquals(InkOperationKind.ERASE_PATH, BigmeStrokeRecord(NativeTool.RUB, 24.0, points).decode(transform)!!.kind)
        assertEquals(InkOperationKind.ERASE_REGION, BigmeStrokeRecord(NativeTool.REGION, 24.0, points).decode(transform)!!.kind)
    }
}
