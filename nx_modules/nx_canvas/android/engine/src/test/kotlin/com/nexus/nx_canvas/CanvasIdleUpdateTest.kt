package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class CanvasIdleUpdateTest {
    private class Scheduler : CanvasScheduler {
        var now = 0L
        data class Task(val due: Long, val work: () -> Unit)
        val tasks = mutableListOf<Task>()
        override fun execute(work: () -> Unit) = work()
        override fun after(milliseconds: Long, work: () -> Unit): Cancellation {
            val task = Task(now + milliseconds, work)
            tasks.add(task)
            return Cancellation { tasks.remove(task) }
        }
        fun advance(ms: Long) {
            now += ms
            val due = tasks.filter { it.due <= now }
            tasks.removeAll(due.toSet()); due.forEach { it.work() }
        }
    }
    @Test fun rapidWritingDoesNotPublishStatusBetweenStrokes() {
        val s = Scheduler(); var updates = 0
        val u = CanvasIdleUpdate(s) { updates++ }
        repeat(10) {
            u.contact(true); u.request(); s.advance(1000)
            assertEquals(0, updates)
            u.contact(false); u.request(); s.advance(100)
        }
        s.advance(200)
        assertEquals(1, updates)
    }
    @Test fun saveCompletionCoalescesToLatestStateWithoutDelayingSaveWork() {
        val s = Scheduler(); val shown = mutableListOf<String>(); var state = "saving"
        val u = CanvasIdleUpdate(s) { shown.add(state) }
        u.request(); s.advance(50)
        state = "saved"; u.request(); s.advance(299)
        assertTrue(shown.isEmpty())
        s.advance(1); assertEquals(listOf("saved"), shown)
    }
    @Test fun staleCallbackCannotRedrawDuringNewContactOrAfterClose() {
        val s = Scheduler(); var updates = 0
        val u = CanvasIdleUpdate(s) { updates++ }
        u.request(); val stale = s.tasks.single().work
        u.contact(true); stale(); assertEquals(0, updates)
        u.contact(false); val closing = s.tasks.single().work
        u.close(); closing(); u.request(); u.contact(false); s.advance(1000)
        assertEquals(0, updates); assertTrue(s.tasks.isEmpty())
    }
    @Test fun latestFailureRemainsVisibleAfterWritingStops() {
        val s = Scheduler(); var displayed = "saved"; var state = "saving"
        val u = CanvasIdleUpdate(s) { displayed = state }
        u.contact(true); u.request(); state = "retrying"; u.request()
        s.advance(1000); assertEquals("saved", displayed)
        u.contact(false); s.advance(300); assertEquals("retrying", displayed)
    }
}
