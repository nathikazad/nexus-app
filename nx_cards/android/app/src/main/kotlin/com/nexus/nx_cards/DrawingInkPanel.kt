package com.nexus.nx_cards

import android.view.View

interface DrawingInkPanel {
    fun getView(): View
    fun clear(complete: () -> Unit)
    fun undo()
    fun setResumed(value: Boolean) {}
    fun eraseButton(held: Boolean) {}
    fun dispose() {}
}

/** Ordered by capability, not brand: keep the proven NoteView path first. */
internal enum class InkBackend { NOTE_VIEW, BIGME, STANDARD }
internal fun inkBackends(hasClass: (String) -> Boolean): List<InkBackend> = buildList {
    if (hasClass("com.xrz.NoteView")) add(InkBackend.NOTE_VIEW)
    if (hasClass("com.xrz.HandwrittenClient") &&
        hasClass("com.xrz.HandwrittenClient\$InputListener")) add(InkBackend.BIGME)
    add(InkBackend.STANDARD)
}
