package com.nexus.nx_cards

import org.junit.Assert.*
import org.junit.Test

class PendingRecallSaveTest {
    @Test fun nextAnswerCannotOvertakePendingSave() {
        val state = PendingRecallSave()
        val first = state.begin(0, false, 123)!!
        assertNull(state.begin(1, true, 456))
        assertSame(first, state.answer)
        state.complete(first)
        assertEquals(1, state.begin(1, true, 456)!!.index)
    }
    @Test fun retryRetainsOriginalAnswerAndTimestamp() {
        val state = PendingRecallSave()
        val answer = state.begin(4, false, 987)!!
        assertEquals(mapOf("index" to 4, "correct" to false, "revealedAt" to 987L), state.answer!!.arguments())
        // Failure deliberately leaves the answer pending until acknowledged.
        assertNull(state.begin(4, true, 999))
        state.complete(answer)
        assertNull(state.answer)
    }
}
