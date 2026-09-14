package com.nexus.nx_flutter_ink_test

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        engine.platformViewsController.registry.registerViewFactory("nx_ink_test/stock",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView = StockInk(context)
            })
    }
}

/** Exact stock widget from NX Ink Test. No subclass, rendering hooks, scene
 * restoration, stroke capture, channel traffic, polling or custom refreshes.
 */
private class StockInk(context: Context) : PlatformView {
    private var ink: View? = null
    private var api: Class<*>? = null
    private val view: View = try {
        val cls = Class.forName("com.xrz.NoteView")
        api = cls
        val widget = cls.getConstructor(Context::class.java).newInstance(context) as View
        ink = widget
        val pen = cls.getMethod("getPen").invoke(widget)
        pen.javaClass.getMethod("setStrokeWidth", Int::class.javaPrimitiveType).invoke(pen, 6)
        cls.getMethod("setInputEnabled", Boolean::class.javaPrimitiveType).invoke(widget, true)
        Log.i("NxFlutterInkTest", "Stock NoteView; default black, width 6, no ink callbacks")
        widget
    } catch (error: Throwable) {
        val cause = error.cause ?: error
        Log.e("NxFlutterInkTest", "Widget unavailable", cause)
        TextView(context).apply { text = "Stock handwriting unavailable: $cause" }
    }

    override fun getView(): View = view
    override fun dispose() {
        ink?.let { widget ->
            runCatching {
                api!!.getMethod("setInputEnabled", Boolean::class.javaPrimitiveType).invoke(widget, false)
            }
        }
        // NoteView owns its Surface lifecycle and releases the native service.
    }
}
