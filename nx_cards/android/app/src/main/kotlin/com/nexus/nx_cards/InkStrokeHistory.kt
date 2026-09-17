package com.nexus.nx_cards

/** Normalized coordinates preserve practice ink across surface resize/reconnect. */
internal data class InkPoint(val x: Float, val y: Float)
internal data class InkStroke(val erasing: Boolean, val points: MutableList<InkPoint>)
internal class InkStrokeHistory {
    val strokes = mutableListOf<InkStroke>()
    var active = false
        private set
    fun begin(x: Float, y: Float, erasing: Boolean) {
        strokes.add(InkStroke(erasing, mutableListOf(InkPoint(x, y))))
        active = true
    }
    fun move(x: Float, y: Float) {
        if (active) strokes.last().points.add(InkPoint(x, y))
    }
    fun end() { active = false }
    fun clear() { active = false; strokes.clear() }
    fun undo() { active = false; if (strokes.isNotEmpty()) strokes.removeAt(strokes.lastIndex) }
    fun snapshot() = strokes.map { InkStroke(it.erasing, it.points.toMutableList()) }
}
