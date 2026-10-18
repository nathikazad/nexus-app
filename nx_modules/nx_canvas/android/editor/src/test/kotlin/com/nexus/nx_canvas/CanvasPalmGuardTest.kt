package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class CanvasPalmGuardTest {
    @Test fun palmAlreadyDownStaysBlockedAfterCooldown() {
        var now=0L
        val guard=CanvasPalmGuard { now }
        guard.fingersDown(true)
        guard.stylusDown()
        guard.stylusUp()
        now=1000
        assertFalse(guard.fingerSequenceEligible)
        guard.fingersUp()
        guard.fingersDown(true)
        assertTrue(guard.fingerSequenceEligible)
    }
    @Test fun palmLandingDuringWritingRemainsBlocked() {
        var now=0L
        val guard=CanvasPalmGuard { now }
        guard.stylusDown()
        guard.fingersDown(true)
        guard.stylusUp()
        now=2000
        assertFalse(guard.fingerSequenceEligible)
    }
    @Test fun requiresFullSecondAndFreshContact() {
        var now=0L
        val guard=CanvasPalmGuard { now }
        guard.stylusDown()
        guard.stylusUp()
        now=999
        guard.fingersDown(true)
        assertFalse(guard.fingerSequenceEligible)
        now=1000
        assertFalse(guard.fingerSequenceEligible)
        guard.fingersUp()
        guard.fingersDown(true)
        assertTrue(guard.fingerSequenceEligible)
    }
    @Test fun anotherPenStrokeRestartsCooldown() {
        var now=0L
        val guard=CanvasPalmGuard { now }
        guard.stylusDown()
        guard.stylusUp()
        now=900
        guard.stylusDown()
        now=1200
        guard.stylusUp()
        now=2000
        guard.fingersDown(true)
        assertFalse(guard.fingerSequenceEligible)
        guard.fingersUp()
        now=2200
        guard.fingersDown(true)
        assertTrue(guard.fingerSequenceEligible)
    }
}
