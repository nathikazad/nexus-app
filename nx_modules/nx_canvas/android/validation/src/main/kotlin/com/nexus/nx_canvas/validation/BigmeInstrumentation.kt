package com.nexus.nx_canvas.validation

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import com.nexus.nx_canvas.*

/** Isolated hardware regression: its own library, never a user's Docs document. */
class BigmeInstrumentation : Instrumentation() {
    private val repository get() = CanvasServices.repository(targetContext)
    override fun onCreate(arguments: Bundle?) { super.onCreate(arguments); start() }
    private fun field(instance: Any, name: String): Any? = instance.javaClass.getDeclaredField(name).apply { isAccessible = true }.get(instance)
    private fun waitUntil(label: String, predicate: () -> Boolean) {
        val deadline = System.currentTimeMillis() + 15000
        while (System.currentTimeMillis() < deadline) { if (predicate()) return; Thread.sleep(30) }
        error("Timed out: $label")
    }
    override fun onStart() {
        val output = Bundle()
        var activity: Activity? = null
        try {
            check(CanvasInputFactory.backend() == CanvasInkBackend.BIGME) { "Expected Bigme firmware" }
            repository.document()?.get("saveToken")?.let { repository.acknowledgeDocument(it as String) }
            repository.write("input", mapOf("documentId" to "bigme-validation", "title" to "Bigme validation") + InkCodec.encode(InkModel(emptyList(), InkViewport(), emptyList())))
            activity = startActivitySync(Intent(targetContext, NativeEditorActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            val screen = field(activity, "screen")!!
            val adapter = field(screen, "input") as BigmeInputAdapter
            waitUntil("Bigme firmware connection and input enabled") { field(adapter, "firmware") != null && field(adapter, "admitted") == true }
            val connection = field(adapter, "firmware")!!
            val input = adapter.javaClass.getDeclaredMethod("input", connection.javaClass, Int::class.javaPrimitiveType, Double::class.javaPrimitiveType, Double::class.javaPrimitiveType, Int::class.javaPrimitiveType).apply { isAccessible = true }
            fun stroke(tool: Int, points: List<Pair<Double, Double>>) {
                points.forEachIndexed { i, p -> input.invoke(adapter, connection, if (i == 0) 1 else if (i == points.lastIndex) 3 else 2, p.first, p.second, tool) }
            }
            fun saved() = repository.io.submit<InkJournal.Saved?> { repository.journal().read() }.get()
            stroke(0, listOf(80.0 to 120.0, 120.0 to 140.0, 160.0 to 160.0))
            waitUntil("pen-up autosave") { saved()?.snapshot?.strokes?.size == 1 }
            val first = saved()!!.snapshot
            stroke(0, listOf(220.0 to 220.0, 240.0 to 250.0, 270.0 to 270.0))
            waitUntil("second stroke autosave") { saved()?.snapshot?.strokes?.size == 2 }
            runOnMainSync { (field(screen, "undoButton") as Button).performClick() }
            waitUntil("undo") { saved()?.snapshot?.strokes?.size == 1 && field(adapter, "admitted") == true }
            check(saved()!!.snapshot.strokes == first.strokes) { "Undo changed the retained stroke" }
            runOnMainSync { (field(screen, "redoButton") as Button).performClick() }
            waitUntil("redo") { saved()?.snapshot?.strokes?.size == 2 && field(adapter, "admitted") == true }
            val secondId = saved()!!.snapshot.strokes.last().id
            // Firmware rubber callbacks must import an erase operation, not a white stroke.
            stroke(1, listOf(110.0 to 110.0, 110.0 to 140.0, 110.0 to 180.0))
            waitUntil("eraser reconciliation") { saved()?.snapshot?.strokes?.none { it.id == first.strokes.single().id } == true && field(adapter, "admitted") == true }
            val switchTool = screen.javaClass.getDeclaredMethod("switchTool", NativeTool::class.java).apply { isAccessible = true }
            runOnMainSync { switchTool.invoke(screen, NativeTool.REGION) }
            waitUntil("region tool") { field(adapter, "admitted") == true && field(screen, "tool") == NativeTool.REGION }
            stroke(0, listOf(200.0 to 200.0, 300.0 to 200.0, 300.0 to 300.0, 200.0 to 300.0, 200.0 to 200.0))
            waitUntil("region erase") { saved()?.snapshot?.strokes?.none { it.id == secondId } == true && field(adapter, "admitted") == true }
            val beforeNavigation = saved()!!.snapshot
            val navigate = screen.javaClass.getDeclaredMethod("navigateBoard", Int::class.javaPrimitiveType, Int::class.javaPrimitiveType, Boolean::class.javaPrimitiveType).apply { isAccessible = true }
            runOnMainSync { navigate.invoke(screen, 1, 0, false) }
            waitUntil("board navigation") { saved()?.snapshot?.view != beforeNavigation.view && field(adapter, "admitted") == true }
            check(saved()!!.snapshot.strokes == beforeNavigation.strokes) { "Board navigation changed ink" }
            val afterErase = saved()!!.snapshot
            runOnMainSync { (activity as NativeEditorActivity).onBackPressed() }
            waitUntil("durable close") { activity!!.isFinishing }
            val reopened = startActivitySync(Intent(targetContext, NativeEditorActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            activity = reopened
            val restored = field(reopened, "screen")!!
            val restoredInput = field(restored, "input") as BigmeInputAdapter
            waitUntil("reopen") { field(restoredInput, "admitted") == true }
            val engine = field(restored, "engine") as CanvasEngine
            var snapshot: InkSnapshot? = null
            runOnMainSync { snapshot = engine.snapshot().drawing }
            check(snapshot!!.strokes == afterErase.strokes) { "Reopen changed ink" }
            output.putString("stream", "PASS: Bigme firmware connection, native surface, pen-up autosave, undo/redo, rubber and region erasers, board navigation, durable close and reopen. Synthetic callbacks; physical pen latency still needs hands-on validation.\n")
            finish(Activity.RESULT_OK, output)
        } catch (error: Throwable) {
            output.putString("stream", error.stackTraceToString()); finish(Activity.RESULT_CANCELED, output)
        } finally { activity?.let { runOnMainSync { it.finish() } } }
    }
}
