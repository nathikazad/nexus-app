package com.nexus.nx_canvas
import org.junit.Assert.*
import org.junit.Test
class InkContactGateTest {
    @Test fun rejectedContactCannotResumeAfterNavigation() {
        val gate=InkContactGate()
        assertFalse(gate.accept(1,false))
        assertFalse(gate.accept(2,true))
        assertFalse(gate.accept(3,true))
        assertTrue(gate.accept(1,true))
        assertTrue(gate.accept(2,true))
        assertTrue(gate.accept(3,true))
        assertFalse(gate.accept(2,true))
    }
    @Test fun alreadyAdmittedStrokeRetainsItsRealUp() {
        val gate=InkContactGate()
        assertTrue(gate.accept(1,true))
        assertTrue(gate.accept(2,false))
        assertTrue(gate.accept(3,false))
        assertFalse(gate.accept(2,true))
    }
}
