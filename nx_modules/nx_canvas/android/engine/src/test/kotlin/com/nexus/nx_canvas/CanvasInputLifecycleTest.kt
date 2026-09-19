package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class CanvasInputLifecycleTest {
    private class Scheduler : CanvasScheduler {
        val timers = mutableListOf<() -> Unit>()
        override fun execute(work: () -> Unit) = work()
        override fun after(milliseconds: Long, work: () -> Unit): Cancellation {
            timers.add(work); return Cancellation { timers.remove(work) }
        }
        fun expire() { val copy = timers.toList(); timers.clear(); copy.forEach { it() } }
    }
    private class Firmware : CanvasFirmwarePort {
        var idle = true
        var admitting = false
        var failTool = false
        val tools = mutableListOf<NativeTool>()
        override fun admitNewStrokes(enabled: Boolean) { admitting = enabled }
        override fun isDrained() = idle
        override fun changeTool(tool: CanvasPenTool) {
            check(idle); check(!admitting)
            if (failTool) error("tool")
            tools.add(tool.tool)
        }
    }
    @Test fun toolWaitsForRealStrokeCompletionWithoutBlockingOrReopeningIngress() {
        val f = Firmware(); val c = CanvasInputLifecycle(f, Scheduler(), fault = { fail(it) })
        c.enable(true); f.idle = false
        c.tool(CanvasPenTool(NativeTool.REGION, 20.0))
        assertFalse(f.admitting); assertTrue(f.tools.isEmpty())
        c.enable(true); c.progressed()
        assertFalse(f.admitting); assertTrue(f.tools.isEmpty())
        f.idle = true; c.progressed()
        assertEquals(listOf(NativeTool.REGION), f.tools); assertTrue(f.admitting)
    }
    @Test fun queuedToolChangesAndNavigationCannotMutateUndrainedFirmware() {
        val f = Firmware(); val c = CanvasInputLifecycle(f, Scheduler(), fault = { fail(it) })
        c.enable(true); f.idle = false
        c.tool(CanvasPenTool(NativeTool.REGION, 20.0))
        c.tool(CanvasPenTool(NativeTool.RUB, 20.0))
        c.tool(CanvasPenTool(NativeTool.PEN, 3.0))
        var done = false; c.drain { done = it }
        assertFalse(done); assertTrue(f.tools.isEmpty())
        f.idle = true; c.progressed()
        assertTrue(done); assertFalse(f.admitting)
        assertEquals(listOf(NativeTool.REGION, NativeTool.PEN), f.tools)
    }
    @Test fun drainWaitsForFirmwareBatchAfterPenLiftAndOnlyRepliesOnce() {
        val f = Firmware(); val c = CanvasInputLifecycle(f, Scheduler(), fault = { fail(it) })
        c.enable(true); f.idle = false; c.enable(false)
        var replies = 0; c.drain { assertTrue(it); replies++ }
        c.progressed(); assertEquals(0, replies)
        f.idle = true; c.progressed(); c.progressed()
        assertEquals(1, replies); assertFalse(f.admitting)
    }
    @Test fun timeoutRetainsBarrierAndRetryCompletesOnlyAfterRealDrain() {
        val f = Firmware(); val s = Scheduler(); var faults = 0
        val c = CanvasInputLifecycle(f, s, fault = { faults++ })
        val replies = mutableListOf<Boolean>()
        c.enable(true); f.idle = false; c.drain { replies.add(it) }; s.expire()
        assertEquals(1, faults); assertEquals(listOf(false), replies); assertFalse(f.admitting)
        var retry = false; c.drain { retry = it }; assertFalse(retry)
        f.idle = true; c.progressed(); assertTrue(retry)
        assertEquals(listOf(false), replies)
    }
    @Test fun toolFailureRetainsIntentUntilExplicitRetry() {
        val f = Firmware(); var faults = 0
        val c = CanvasInputLifecycle(f, Scheduler(), fault = { faults++ })
        f.failTool = true; c.tool(CanvasPenTool(NativeTool.PEN, 3.0))
        assertEquals(1, faults); assertFalse(f.admitting)
        f.failTool = false; var recovered = false; c.drain { recovered = it }
        assertTrue(recovered); assertEquals(listOf(NativeTool.PEN), f.tools)
    }
    @Test fun reentrantDrainCompletionMayResumeWithoutOpeningBeforeQueuedTool() {
        val f = Firmware(); val c = CanvasInputLifecycle(f, Scheduler(), fault = { fail(it) })
        f.idle = false
        c.drain { c.enable(true); c.tool(CanvasPenTool(NativeTool.PEN, 3.0)) }
        f.idle = true; c.progressed()
        assertEquals(listOf(NativeTool.PEN), f.tools); assertTrue(f.admitting)
    }
    @Test fun closeRejectsPendingCallbacksAndNeverReadmitsInput() {
        val f = Firmware(); val c = CanvasInputLifecycle(f, Scheduler(), fault = { fail(it) })
        c.enable(true); f.idle = false
        val replies = mutableListOf<Boolean>(); c.drain { replies.add(it) }
        c.close(); c.enable(true); f.idle = true; c.progressed()
        assertFalse(f.admitting); assertEquals(listOf(false), replies)
    }
}
