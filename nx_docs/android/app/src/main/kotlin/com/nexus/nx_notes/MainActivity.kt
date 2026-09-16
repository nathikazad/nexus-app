package com.nexus.nx_notes

import android.content.Intent
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import com.nexus.nx_canvas.NativeEditorActivity
import com.nexus.nx_canvas.NativeEditorFiles
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceFragmentActivity() {
    private var canvasResult:MethodChannel.Result?=null
    override fun configureFlutterEngine(engine:FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger,"nx_docs/canvas").setMethodCallHandler { call,result ->
            try {
                when(call.method) {
                    "available" -> result.success(runCatching{Class.forName("com.xrz.NoteView")}.isSuccess)
                    "recoverDocument" -> result.success(NativeEditorFiles.document(this))
                    "ackDocument" -> result.success(NativeEditorFiles.acknowledgeDocument(this,call.arguments as String))
                    "openDocument" -> {
                        check(canvasResult==null){"Canvas already open"}
                        check(NativeEditorFiles.document(this)==null){"Save the recovered canvas before opening another"}
                        Class.forName("com.xrz.NoteView")
                        val input=call.arguments as Map<*,*>
                        require(input["documentId"] is String && input["title"] is String)
                        NativeEditorFiles.write(this,"input",input)
                        canvasResult=result
                        try {startActivityForResult(Intent(this,NativeEditorActivity::class.java),7402)}
                        catch(error:Throwable){canvasResult=null;throw error}
                    }
                    else -> result.notImplemented()
                }
            } catch(error:Throwable){result.error("canvas",error.message,null)}
        }
    }
    @Deprecated("Legacy activity result callback")
    override fun onActivityResult(requestCode:Int,resultCode:Int,data:Intent?) {
        super.onActivityResult(requestCode,resultCode,data)
        if(requestCode==7402) {
            val result=canvasResult;canvasResult=null
            runCatching{NativeEditorFiles.document(this)}
                .onSuccess{result?.success(it)}
                .onFailure{result?.error("canvas",it.message,null)}
        }
    }
}
