package com.nexus.nx_canvas

fun drawingCounts(strokes: List<NativeStroke>): Map<String, Any> = mapOf(
    "strokes" to strokes.size, "points" to strokes.sumOf { it.points.size.toLong() },
    "max_stroke_points" to (strokes.maxOfOrNull { it.points.size } ?: 0),
)
