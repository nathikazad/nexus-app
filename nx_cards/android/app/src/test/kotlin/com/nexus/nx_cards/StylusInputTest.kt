package com.nexus.nx_cards

import android.view.MotionEvent
import org.junit.Assert.*
import org.junit.Test

class StylusInputTest {
    @Test fun barrelButtonsEraseOnlyWhileHeld() {
        for (button in listOf(MotionEvent.BUTTON_STYLUS_PRIMARY, MotionEvent.BUTTON_STYLUS_SECONDARY)) {
            assertTrue(StylusInput.erasing(MotionEvent.TOOL_TYPE_STYLUS, button))
            assertFalse(StylusInput.erasing(MotionEvent.TOOL_TYPE_STYLUS, 0))
        }
    }
    @Test fun eraserTipErasesButFingerAndMouseDoNot() {
        assertTrue(StylusInput.erasing(MotionEvent.TOOL_TYPE_ERASER, 0))
        assertFalse(StylusInput.erasing(MotionEvent.TOOL_TYPE_FINGER, MotionEvent.BUTTON_STYLUS_PRIMARY))
        assertFalse(StylusInput.erasing(MotionEvent.TOOL_TYPE_MOUSE, MotionEvent.BUTTON_SECONDARY))
    }
}
