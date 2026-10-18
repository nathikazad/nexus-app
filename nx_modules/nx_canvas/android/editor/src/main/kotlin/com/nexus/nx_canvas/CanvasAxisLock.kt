package com.nexus.nx_canvas

import kotlin.math.abs
import kotlin.math.hypot

/** Choose once from the initial swipe angle, after ignoring touch jitter. */
class CanvasAxisLock(private val slop: Double) {
    private var horizontal: Boolean? = null
    fun reset() { horizontal = null }
    fun movement(dx: Double, dy: Double): InkPoint {
        if (horizontal == null) {
            if (hypot(dx, dy) < slop) return InkPoint(0.0, 0.0)
            horizontal = abs(dx) > abs(dy)
        }
        return if (horizontal == true) InkPoint(dx, 0.0) else InkPoint(0.0, dy)
    }
}
