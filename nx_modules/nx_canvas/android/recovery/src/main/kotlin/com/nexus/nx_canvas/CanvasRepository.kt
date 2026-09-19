package com.nexus.nx_canvas

import android.content.Context
import android.util.AtomicFile
import java.io.File
import org.json.JSONObject
import org.json.JSONArray

/** Durable handoff, separate from live handwriting. No large Intent extras. */
class CanvasRepository(private val context: Context) {
    // All journal writes, reads, and acknowledgments use the same FIFO executor.
    val io = java.util.concurrent.Executors.newSingleThreadExecutor{r->Thread(r,"canvas-save")}
    @Volatile private var lease: String? = null
    val active get() = lease != null
    @Synchronized fun claim(session: String): AutoCloseable {
        check(lease == null) { "Canvas session already active" }
        val id = java.util.UUID.randomUUID().toString()
        lease = id
        return AutoCloseable { synchronized(this) { if(lease == id)lease = null } }
    }
    // Same-process launch reuses the already decoded transport map, after its
    // durable file write succeeds. Process restart still reads the atomic file.
    @Volatile private var preparedScene: Map<*, *>? = null
    private var journal:InkJournal?=null
    @Synchronized fun journal():InkJournal {
        return journal ?: InkJournal(File(context.filesDir,"native-editor-journal.bin")).also{journal=it}
    }
    private fun file(context: Context, name: String) = AtomicFile(File(context.filesDir, "native-editor-$name.json"))
    fun write(name: String, value: Any) {
        val data = if (value is Map<*, *>) JSONObject(value).toString() else JSONArray(value as Collection<*>).toString()
        val target = file(context, name)
        val stream = target.startWrite()
        try {
            stream.write(data.toByteArray(Charsets.UTF_8)); target.finishWrite(stream)
            if (name == "input") preparedScene = value as? Map<*, *>
        }
        catch (error: Throwable) { target.failWrite(stream); throw error }
    }
    private fun unpack(value: Any?): Any? = when (value) {
        is JSONObject -> value.keys().asSequence().associateWith { unpack(value.get(it)) }
        is JSONArray -> (0 until value.length()).map { unpack(value.get(it)) }
        JSONObject.NULL -> null
        else -> value
    }
    fun scene(): Map<*, *> = preparedScene ?: unpack(JSONObject(String(file(context, "input").readFully(), Charsets.UTF_8))) as Map<*, *>
    fun pending(): List<*> {
        val target = file(context, "output")
        if (!target.baseFile.exists()) return emptyList<Any>()
        return unpack(JSONArray(String(target.readFully(), Charsets.UTF_8))) as List<*>
    }
    fun acknowledge() { file(context, "output").delete() }
    fun document(): Map<*, *>? {
        journal().read()?.let{return it.payload()}
        val target=file(context,"document-output")
        if(!target.baseFile.exists()) return null
        return unpack(JSONObject(String(target.readFully(),Charsets.UTF_8))) as Map<*,*>
    }
    fun acknowledgeDocument(token: String): Boolean {
        if(active)return false
        if(document()?.get("saveToken")!=token)return false
        if(journal().read()!=null)journal().acknowledge(token)
        file(context,"document-output").delete();return true
    }
}
