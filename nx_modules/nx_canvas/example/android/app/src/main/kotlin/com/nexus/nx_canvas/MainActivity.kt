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
    private var editorResult: MethodChannel.Result? = null
    private var documentMode=false
    @Deprecated("Legacy activity result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 7401) {
            val result = editorResult; editorResult = null
            runCatching { if(documentMode) NativeEditorFiles.document(this) else NativeEditorFiles.pending(this) }
                .onSuccess { result?.success(it) }
                .onFailure { result?.error("native_editor", it.toString(), null) }
        }
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "nx_canvas/editor").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "recoverDocument" -> result.success(NativeEditorFiles.document(this))
                    "ackDocument" -> result.success(NativeEditorFiles.acknowledgeDocument(this, call.arguments as String))
                    "openDocument" -> {
                        check(editorResult == null) { "Canvas already open" }
                        check(NativeEditorFiles.document(this)==null) { "Recover the previous drawing before opening another" }
                        Class.forName("com.xrz.NoteView")
                        val input=call.arguments as Map<*,*>
                        require(input["documentId"] is String && input["title"] is String)
                        NativeEditorFiles.write(this,"input",input)
                        editorResult=result;documentMode=true
                        try { startActivityForResult(Intent(this,NativeEditorActivity::class.java),7401) }
                        catch(error:Throwable){editorResult=null;throw error}
                    }
                    "recover" -> result.success(NativeEditorFiles.pending(this))
                    "ack" -> { NativeEditorFiles.acknowledge(this); result.success(null) }
                    "open" -> {
                        check(editorResult == null) { "Handwriting already open" }
                        check(NativeEditorFiles.pending(this).isEmpty()) { "Save recovered handwriting before opening a new session" }
                        Class.forName("com.xrz.NoteView")
                        NativeEditorFiles.write(this, "input", call.arguments as Map<*, *>)
                        editorResult = result; documentMode=false
                        try { startActivityForResult(Intent(this, NativeEditorActivity::class.java), 7401) }
                        catch (error: Throwable) { editorResult = null; throw error }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) { result.error("native_editor", error.toString(), null) }
        }

        engine.platformViewsController.registry.registerViewFactory("nx_canvas/native",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
                    NativeInkView(context, engine.dartExecutor.binaryMessenger, viewId)
            })
    }
}
