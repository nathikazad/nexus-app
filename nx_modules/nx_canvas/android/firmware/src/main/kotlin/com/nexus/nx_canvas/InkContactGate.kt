package com.nexus.nx_canvas

/** A rejected contact stays rejected until a fresh down, even after navigation finishes. */
class InkContactGate {
    private var contact=false
    @Synchronized fun accept(action:Int, admitting:Boolean):Boolean = when(action) {
        1 -> { contact=admitting; contact }
        2 -> contact
        3,4 -> { val accepted=contact;contact=false;accepted }
        else -> false
    }
}
