package com.nexus.nx_canvas

import kotlin.math.*

class InkNavigationQueue {
    private val steps=mutableListOf<Triple<Int,Int,Boolean>>()
    val isEmpty get()=steps.isEmpty()
    fun add(dx:Int,dy:Int,jump:Boolean){steps.add(Triple(dx,dy,jump))}
    fun clear(){steps.clear()}
    fun apply(boards:InkBoards,view:InkViewport,width:Double,height:Double):InkViewport {
        var next=view
        for((dx,dy,jump) in steps)next=boards.navigate(next,dx,dy,jump,width,height)
        steps.clear();return next
    }
}
