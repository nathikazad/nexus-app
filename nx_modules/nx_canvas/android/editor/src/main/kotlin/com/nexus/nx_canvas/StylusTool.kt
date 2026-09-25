package com.nexus.nx_canvas

import android.view.MotionEvent

internal fun stylusToolOverride(tool: Int, buttons: Int): NativeTool? = when {
    tool == MotionEvent.TOOL_TYPE_ERASER -> NativeTool.RUB
    tool == MotionEvent.TOOL_TYPE_STYLUS && buttons and
        (MotionEvent.BUTTON_STYLUS_PRIMARY or MotionEvent.BUTTON_STYLUS_SECONDARY) != 0 -> NativeTool.REGION
    else -> null
}
