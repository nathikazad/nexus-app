package com.nexus.nx_canvas

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/** Host-neutral transport adapter. No document editor, database, or account dependencies. */
class NxCanvasPlugin : FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener {
    private lateinit var repository: CanvasRepository
    private lateinit var channel: MethodChannel
    private var binding: ActivityPluginBinding? = null
    private var pending: MethodChannel.Result? = null
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        repository = CanvasServices.repository(binding.applicationContext)
        CanvasDiagnostics.start(binding.applicationContext)
        channel = MethodChannel(binding.binaryMessenger, "nx_canvas/editor")
        channel.setMethodCallHandler { call, result ->
            try {
                when(call.method) {
                    // Legacy example recovery only; retain old files until explicitly acknowledged.
                    "recover" -> background(result, "legacyRecover") { repository.pending() }
                    "ack" -> background(result, "legacyAck") { repository.acknowledge(); null }
                    "available" -> result.success(runCatching { Class.forName("com.xrz.NoteView") }.isSuccess)
                    "recoverDocument" -> background(result, "recoverDocument") { repository.document() }
                    "peekDocument" -> background(result, "peekDocument") {
                        if(repository.active) repository.journal().read()?.takeIf { it.token != call.arguments }?.payload() else null
                    }
                    "ackDocument" -> background(result, "ackDocument") { repository.acknowledgeDocument(call.arguments as String) }
                    "openDocument" -> {
                        check(pending == null && !repository.active) { "Canvas already open" }
                        check(this.binding != null) { "Canvas requires a foreground activity" }
                        Class.forName("com.xrz.NoteView")
                        val input = call.arguments as Map<*, *>
                        require(input["documentId"] is String && input["title"] is String)
                        pending = result
                        val traceId = input["traceId"] as? String ?: "native-open"
                        CanvasDiagnostics.transitionStart(traceId)
                        CanvasDiagnostics.event("transition.open.received", mapOf("trace_id" to traceId))
                        repository.io.execute {
                            val prepared = runCatching {
                                check(repository.document() == null) { "Save the recovered canvas before opening another" }
                                CanvasDiagnostics.measure("open.prepare_file") { repository.write("input", input) }
                            }
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                if(pending !== result)return@post
                                try {
                                    prepared.getOrThrow()
                                    val activity = this.binding?.activity ?: error("Canvas host detached")
                                    CanvasDiagnostics.event("transition.open.launch", mapOf("trace_id" to traceId))
                                    activity.startActivityForResult(Intent(activity, NativeEditorActivity::class.java)
                                        .putExtra("traceId", traceId)
                                        .putExtra("openTappedAtMs", (input["openTappedAtMs"] as? Number)?.toLong() ?: System.currentTimeMillis()), REQUEST)
                                } catch(error: Throwable) { CanvasDiagnostics.event("transition.open.failed"); CanvasDiagnostics.transitionEnd(); pending = null; result.error("canvas", error.message, null) }
                            }
                        }
                    }
                    "diagnostic" -> {
                        val args = call.arguments as? Map<*, *>
                        val allowed = setOf("stage", "phase", "dart_time_ms", "duration_us", "trace_id")
                        if (args?.get("stage") == "transition.open.tap") CanvasDiagnostics.transitionStart(args["trace_id"] as? String ?: "open")
                        if (args?.get("stage") in listOf("transition.return.frame", "transition.error")) CanvasDiagnostics.transitionEnd()
                        CanvasDiagnostics.event("dart", args?.entries?.filter { it.key in allowed && (it.value is String || it.value is Number) }?.associate { it.key.toString() to it.value }.orEmpty())
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch(error: Throwable) { result.error("canvas", error.message, null) }
        }
    }
    private fun background(result: MethodChannel.Result, stage: String, work: () -> Any?) {
        repository.io.execute {
            val value = runCatching { CanvasDiagnostics.measure("bridge.$stage", work = work) }
            CanvasDiagnostics.measure("bridge.reply.$stage") { value.onSuccess(result::success).onFailure { result.error("canvas", it.message, null) } }
        }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if(requestCode != REQUEST)return false
        val result = pending; pending = null
        CanvasDiagnostics.event("transition.return.activity_result", mapOf("trace_id" to data?.getStringExtra("traceId")))
        if(result != null)background(result, "returnDocument") {
            repository.document()?.toMutableMap()?.apply {
                put("unchanged", data?.getBooleanExtra("unchanged", false) == true)
                data?.getStringExtra("traceId")?.let { put("traceId", it) }
                val tapped = data?.getLongExtra("returnTappedAtMs", 0L) ?: 0L
                if (tapped > 0) put("returnTappedAtMs", tapped)
            }
        }
        return true
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { this.binding = binding; binding.addActivityResultListener(this) }
    private fun detach() { binding?.removeActivityResultListener(this); binding = null }
    override fun onDetachedFromActivityForConfigChanges() = detach()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivity() { detach(); pending?.error("canvas", "Canvas host closed; recovery is retained", null); pending = null }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { channel.setMethodCallHandler(null); pending = null }
    companion object { private const val REQUEST = 7402 }
}
