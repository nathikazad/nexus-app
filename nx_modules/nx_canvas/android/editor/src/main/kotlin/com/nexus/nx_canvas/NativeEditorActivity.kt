package com.nexus.nx_canvas

import android.app.Activity
import android.os.Bundle
import android.view.MotionEvent

/** Android lifecycle entry point; session logic is owned by injected coordinators. */
class NativeEditorActivity : Activity() {
    private lateinit var screen: CanvasEditorScreen
    override fun onCreate(state: Bundle?) { super.onCreate(state); screen = CanvasEditorScreen(this); screen.onCreate(state) }
    override fun onResume() { super.onResume(); screen.onResume() }
    override fun onPause() { screen.onPause(); super.onPause() }
    override fun onDestroy() { screen.onDestroy(); super.onDestroy() }
    @Deprecated("Legacy Android back callback") override fun onBackPressed() = screen.onBackPressed()
    override fun dispatchTouchEvent(event: MotionEvent) = if(::screen.isInitialized) screen.dispatchTouchEvent(event) { super.dispatchTouchEvent(event) } else super.dispatchTouchEvent(event)
    override fun dispatchGenericMotionEvent(event: MotionEvent) = if(::screen.isInitialized) screen.dispatchGenericMotionEvent(event) { super.dispatchGenericMotionEvent(event) } else super.dispatchGenericMotionEvent(event)
}
