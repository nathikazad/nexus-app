package com.nexus.nx_canvas

import kotlin.math.*

class InkRecordSet {
    private class IdentityRef(value:Any,queue:java.lang.ref.ReferenceQueue<Any>?=null):java.lang.ref.WeakReference<Any>(value,queue) {
        private val hash=System.identityHashCode(value)
        override fun hashCode()=hash
        override fun equals(other:Any?)=this===other || (other is IdentityRef && get()!=null && get()===other.get())
    }
    private val queue=java.lang.ref.ReferenceQueue<Any>()
    private val entries=mutableSetOf<IdentityRef>()
    fun add(record:Any):Boolean {
        while(true){val old=queue.poll()?:break;entries.remove(old)}
        return entries.add(IdentityRef(record,queue))
    }
    fun clear(){entries.clear()}
}
