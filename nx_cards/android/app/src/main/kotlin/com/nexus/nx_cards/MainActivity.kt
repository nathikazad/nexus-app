package com.nexus.nx_cards

import android.content.Intent
import java.lang.ref.WeakReference
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
                        android.util.Log.i("NxCardsStartup", "stage=channel_received epoch_ms=${System.currentTimeMillis()}")
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
                "showFlutter", "resumeDrawing" -> {
                    val drawing = NativeDrawingBridge.activity?.get()
                    if (pending == null || drawing == null || drawing.isFinishing || drawing.isDestroyed) {
                        result.error("drawing_closed", "Drawing session is no longer open", null)
                    } else {
                        val destination = if (call.method == "showFlutter") MainActivity::class.java else NativeDrawingActivity::class.java
                        startActivity(Intent(this, destination).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT))
                        result.success(null)
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
    var activity: WeakReference<NativeDrawingActivity>? = null
    fun clear() { input = null; channel = null; activity = null }
}
