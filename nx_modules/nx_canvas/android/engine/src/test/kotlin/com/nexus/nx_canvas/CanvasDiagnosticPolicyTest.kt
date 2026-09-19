package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class CanvasDiagnosticPolicyTest {
    @Test fun steadyInkAndPeriodicNoiseAreExcluded() {
        for (name in listOf("pen.down", "pen.up", "touch.dispatch", "input.quiescent", "canvas.state", "process.sample", "window.frames", "firmware.draw_batch"))
            assertFalse(name, CanvasDiagnosticPolicy.event(name))
        assertFalse(CanvasDiagnosticPolicy.span("stroke.import", 2.0))
    }
    @Test fun transitionsFailuresAndSlowWorkRemainVisible() {
        for (name in listOf("transition.open.presented", "transition.return.tap", "overlay.repair", "input.transition_timeout", "stage.error", "main.stall"))
            assertTrue(name, CanvasDiagnosticPolicy.event(name))
        assertTrue(CanvasDiagnosticPolicy.span("open.read_input", 1.0))
        assertTrue(CanvasDiagnosticPolicy.span("bridge.returnDocument", 1.0))
        assertTrue(CanvasDiagnosticPolicy.span("stroke.import", 70.0))
    }
}
