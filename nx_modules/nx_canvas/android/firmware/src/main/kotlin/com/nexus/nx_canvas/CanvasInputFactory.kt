package com.nexus.nx_canvas

import android.content.Context

enum class CanvasInkBackend { NOTE_VIEW, BIGME }
fun canvasInkBackend(hasClass: (String) -> Boolean): CanvasInkBackend? = when {
    hasClass("com.xrz.NoteView") -> CanvasInkBackend.NOTE_VIEW
    hasClass("com.xrz.HandwrittenClient") && hasClass("com.xrz.HandwrittenClient\$InputListener") -> CanvasInkBackend.BIGME
    else -> null
}
object CanvasInputFactory {
    fun backend() = canvasInkBackend { runCatching { Class.forName(it) }.isSuccess }
    fun create(context: Context, diagnostics: DiagnosticSink): AndroidCanvasInput = when (backend()) {
        CanvasInkBackend.NOTE_VIEW -> TabletInputAdapter(context, diagnostics)
        CanvasInkBackend.BIGME -> BigmeInputAdapter(context, diagnostics)
        null -> error("This device has no supported handwriting service")
    }
}
