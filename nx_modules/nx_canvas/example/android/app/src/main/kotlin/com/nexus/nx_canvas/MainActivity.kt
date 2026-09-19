package com.nexus.nx_canvas

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        engine.platformViewsController.registry.registerViewFactory("nx_canvas/native",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
                    NativeInkView(context, engine.dartExecutor.binaryMessenger, viewId)
            })
    }
}
