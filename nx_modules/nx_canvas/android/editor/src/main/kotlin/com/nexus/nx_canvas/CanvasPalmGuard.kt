package com.nexus.nx_canvas

/** A palm contact cannot become navigation merely because the pen lifts. */
class CanvasPalmGuard(private val nowMillis: () -> Long = { System.nanoTime() / 1_000_000 }) {
    private var lastStylusUp: Long? = null
    var stylusTouching = false
        private set
    var fingerSequenceEligible = false
        private set

    fun stylusDown() {
        stylusTouching = true
        fingerSequenceEligible = false
    }
    fun stylusUp() {
        stylusTouching = false
        lastStylusUp = nowMillis()
    }
    fun fingersDown(inCanvas: Boolean) {
        val cooledDown = lastStylusUp?.let { nowMillis() - it >= 1000 } ?: true
        fingerSequenceEligible = inCanvas && !stylusTouching && cooledDown
    }
    fun fingersUp() { fingerSequenceEligible = false }
    fun reset() { stylusTouching = false; fingerSequenceEligible = false; lastStylusUp = null }
}
