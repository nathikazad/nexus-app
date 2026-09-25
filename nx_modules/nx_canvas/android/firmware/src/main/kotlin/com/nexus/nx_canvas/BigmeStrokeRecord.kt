package com.nexus.nx_canvas

import java.util.UUID

/** Cooked coordinates must not be rotated a second time on Bigme firmware. */
class BigmeStrokeRecord(private val tool: NativeTool, private val width: Double, private val points: List<InkPoint>) : CanvasInputRecord {
    override val completesStroke = true
    override fun decode(transform: InputTransform): InkOperation? {
        if (points.isEmpty()) return null
        val world = points.map { transform.view.world(InkPoint(it.x / transform.density, it.y / transform.density, it.pressure)) }
        return InkOperation(when (tool) {
            NativeTool.RUB -> InkOperationKind.ERASE_PATH
            NativeTool.REGION -> InkOperationKind.ERASE_REGION
            else -> InkOperationKind.DRAW
        }, NativeStroke(UUID.randomUUID().toString(), world, 0xff000000L, width / transform.density / transform.view.scale))
    }
}
