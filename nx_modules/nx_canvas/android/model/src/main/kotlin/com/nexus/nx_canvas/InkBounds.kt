package com.nexus.nx_canvas

import kotlin.math.*

data class InkBounds(val left:Double,val top:Double,val right:Double,val bottom:Double) {
    fun intersects(other:InkBounds)=left<=other.right && right>=other.left && top<=other.bottom && bottom>=other.top
    companion object {
        fun of(stroke:NativeStroke):InkBounds {
            val radius=stroke.width/2
            return InkBounds(stroke.points.minOf{it.x}-radius,stroke.points.minOf{it.y}-radius,
                stroke.points.maxOf{it.x}+radius,stroke.points.maxOf{it.y}+radius)
        }
    }
}
