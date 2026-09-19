package com.nexus.nx_canvas

import kotlin.math.*

class InkDiagnosticBuffer(capacity:Int) {
    private val queue=java.util.concurrent.ArrayBlockingQueue<Map<String,Any?>>(capacity)
    val dropped=java.util.concurrent.atomic.AtomicLong()
    fun offer(value:Map<String,Any?>){if(!queue.offer(value))dropped.incrementAndGet()}
    fun take():Map<String,Any?> = queue.take()
}
