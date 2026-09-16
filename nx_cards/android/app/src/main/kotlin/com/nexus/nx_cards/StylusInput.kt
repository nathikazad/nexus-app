package com.nexus.nx_cards

import android.view.MotionEvent

internal object StylusInput {
    fun erasing(event: MotionEvent): Boolean = event.pointerCount > 0 &&
        erasing(event.getToolType(0), event.buttonState)

    fun erasing(tool: Int, buttons: Int): Boolean =
        tool == MotionEvent.TOOL_TYPE_ERASER ||
            (tool == MotionEvent.TOOL_TYPE_STYLUS && buttons and
                (MotionEvent.BUTTON_STYLUS_PRIMARY or MotionEvent.BUTTON_STYLUS_SECONDARY) != 0)
}
