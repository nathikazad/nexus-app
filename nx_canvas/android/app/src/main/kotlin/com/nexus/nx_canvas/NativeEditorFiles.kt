package com.nexus.nx_canvas

import android.content.Context
import android.util.AtomicFile
import java.io.File
import org.json.JSONObject
import org.json.JSONArray

/** Durable handoff, separate from live handwriting. No large Intent extras. */
object NativeEditorFiles {
    private fun file(context: Context, name: String) = AtomicFile(File(context.filesDir, "native-editor-$name.json"))
    fun write(context: Context, name: String, value: Any) {
        val data = if (value is Map<*, *>) JSONObject(value).toString() else JSONArray(value as Collection<*>).toString()
        val target = file(context, name)
        val stream = target.startWrite()
        try { stream.write(data.toByteArray(Charsets.UTF_8)); target.finishWrite(stream) }
        catch (error: Throwable) { target.failWrite(stream); throw error }
    }
    private fun unpack(value: Any?): Any? = when (value) {
        is JSONObject -> value.keys().asSequence().associateWith { unpack(value.get(it)) }
        is JSONArray -> (0 until value.length()).map { unpack(value.get(it)) }
        JSONObject.NULL -> null
        else -> value
    }
    fun scene(context: Context) = unpack(JSONObject(String(file(context, "input").readFully(), Charsets.UTF_8))) as Map<*, *>
    fun pending(context: Context): List<*> {
        val target = file(context, "output")
        if (!target.baseFile.exists()) return emptyList<Any>()
        return unpack(JSONArray(String(target.readFully(), Charsets.UTF_8))) as List<*>
    }
    fun acknowledge(context: Context) { file(context, "output").delete() }
    fun document(context: Context): Map<*, *>? {
        val target=file(context,"document-output")
        if(!target.baseFile.exists()) return null
        return unpack(JSONObject(String(target.readFully(),Charsets.UTF_8))) as Map<*,*>
    }
    fun acknowledgeDocument(context: Context, token: String): Boolean {
        if(document(context)?.get("saveToken")!=token)return false
        file(context,"document-output").delete();return true
    }
}
