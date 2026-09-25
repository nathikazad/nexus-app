package com.nexus.nx_canvas

import android.view.MotionEvent
import org.junit.Assert.*
import org.junit.Test

class StylusToolTest {
    @Test fun rearTipRubErasesEvenWithButtonPressed() {
        assertEquals(NativeTool.RUB, stylusToolOverride(MotionEvent.TOOL_TYPE_ERASER, 0))
        assertEquals(NativeTool.RUB, stylusToolOverride(MotionEvent.TOOL_TYPE_ERASER, MotionEvent.BUTTON_STYLUS_PRIMARY))
    }
    @Test fun sideButtonUsesRegionAndPenTipRestoresSelection() {
        assertEquals(NativeTool.REGION, stylusToolOverride(MotionEvent.TOOL_TYPE_STYLUS, MotionEvent.BUTTON_STYLUS_PRIMARY))
        assertNull(stylusToolOverride(MotionEvent.TOOL_TYPE_STYLUS, 0))
        assertNull(stylusToolOverride(MotionEvent.TOOL_TYPE_FINGER, 0))
    }
}
