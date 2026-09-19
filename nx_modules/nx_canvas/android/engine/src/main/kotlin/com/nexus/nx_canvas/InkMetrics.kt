package com.nexus.nx_canvas

import kotlin.math.*

class InkMetrics {
    private data class Sample(var count:Long=0,var total:Double=0.0,var max:Double=0.0)
    private val values=mutableMapOf<String,Sample>()
    @Synchronized fun record(name:String,value:Double) {
        val sample=values.getOrPut(name){Sample()};sample.count++;sample.total+=value;sample.max=max(sample.max,value)
    }
    @Synchronized fun drain():Map<String,Any> {
        val batch=values.mapValues{(_,s)->mapOf("count" to s.count,"total" to s.total,"max" to s.max)}
        values.clear();return batch
    }
}
