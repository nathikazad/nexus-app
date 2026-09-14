package com.nexus.nx_canvas

/** Firmware records use panel-local pixels, before NoteView's display rotation.
 * Matches the firmware's generatePenPointForView conversion, without its
 * physical screen offset (records have already had that offset subtracted).
 */
object InkCoordinates {
    fun panelToView(p:InkPoint,rotation:Int,width:Double,height:Double):InkPoint = when(rotation) {
        0 -> p
        90 -> InkPoint(p.y,height-p.x,p.pressure)
        180 -> InkPoint(width-p.x,height-p.y,p.pressure)
        270 -> InkPoint(width-p.y,p.x,p.pressure)
        else -> error("Unsupported tablet rotation: $rotation")
    }
    fun viewToPanel(p:InkPoint,rotation:Int,width:Double,height:Double):InkPoint = when(rotation) {
        0 -> p
        90 -> InkPoint(height-p.y,p.x,p.pressure)
        180 -> InkPoint(width-p.x,height-p.y,p.pressure)
        270 -> InkPoint(p.y,width-p.x,p.pressure)
        else -> error("Unsupported tablet rotation: $rotation")
    }
}
