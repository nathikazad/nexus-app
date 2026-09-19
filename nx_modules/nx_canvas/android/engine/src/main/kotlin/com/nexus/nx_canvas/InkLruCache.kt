package com.nexus.nx_canvas

import kotlin.math.*

class InkLruCache<K,V>(private val limit:Long,private val size:(V)->Long,private val dispose:(V)->Unit) {
    private val values=LinkedHashMap<K,V>(16,.75f,true)
    var bytes=0L;private set
    operator fun get(key:K)=values[key]
    fun put(key:K,value:V) {
        values.remove(key)?.let{bytes-=size(it);dispose(it)}
        values[key]=value;bytes+=size(value)
        while(bytes>limit && values.size>1) {
            val entry=values.entries.first();values.remove(entry.key);bytes-=size(entry.value);dispose(entry.value)
        }
    }
    fun clear(){values.values.forEach(dispose);values.clear();bytes=0}
}
