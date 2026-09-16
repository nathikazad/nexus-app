package com.nexus.nx_cards

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pending: MethodChannel.Result? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "nx_cards/drawing-session")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(true)
                "open" -> {
                    if (pending != null) { result.error("busy", "Drawing is already open", null); return@setMethodCallHandler }
                    try {
                        NativeDrawingBridge.input = call.arguments as Map<*, *>
                        NativeDrawingBridge.channel = channel
                        pending = result
                        startActivityForResult(Intent(this, NativeDrawingActivity::class.java), 7412)
                    } catch (error: Throwable) {
                        pending = null
                        NativeDrawingBridge.clear()
                        result.error("native_drawing", error.toString(), null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    @Deprecated("Legacy result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 7412) {
            val result = pending; pending = null
            NativeDrawingBridge.clear()
            val error = data?.getStringExtra("error")
            if (error == null) result?.success(null) else result?.error("native_drawing", error, null)
        }
    }
}

object NativeDrawingBridge {
    var input: Map<*, *>? = null
    var channel: MethodChannel? = null
    fun clear() { input = null; channel = null }
}
