package com.nexus.nx_canvas

import kotlin.math.min

/** Pure overview geometry, calculated once off the UI thread. Coordinates are pixels. */
data class InkOverviewLayout(val view: InkViewport, val boxes: Map<InkBoard, InkBounds>) {
    fun hit(x: Double, y: Double) = boxes.entries.firstOrNull {
        x >= it.value.left && x < it.value.right && y >= it.value.top && y < it.value.bottom
    }?.key
    companion object {
        fun calculate(boards: InkBoards, cells: Set<InkBoard>, width: Int, height: Int, padding: Double): InkOverviewLayout {
            if(cells.isEmpty()) return InkOverviewLayout(InkViewport(), emptyMap())
            val left=cells.minOf{it.column}*boards.width; val top=cells.minOf{it.row}*boards.height
            val right=(cells.maxOf{it.column}+1)*boards.width; val bottom=(cells.maxOf{it.row}+1)*boards.height
            val scale=min((width-2*padding)/(right-left),(height-2*padding)/(bottom-top)).coerceAtLeast(.000001)
            val view=InkViewport(width/2.0-(left+right)*scale/2,height/2.0-(top+bottom)*scale/2,scale)
            return InkOverviewLayout(view,cells.associateWith { cell -> InkBounds(
                view.x+cell.column*boards.width*scale,view.y+cell.row*boards.height*scale,
                view.x+(cell.column+1)*boards.width*scale,view.y+(cell.row+1)*boards.height*scale) })
        }
    }
}
