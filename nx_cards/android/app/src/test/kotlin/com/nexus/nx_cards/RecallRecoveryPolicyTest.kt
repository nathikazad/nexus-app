package com.nexus.nx_cards

import org.junit.Assert.*
import org.junit.Test

class RecallRecoveryPolicyTest {
    @Test fun idleScreenAndAWorkingFrameProbeAreNotStalls() {
        val idle = InputStallEvidence(true, 0, false, 60000, 0, 60000, false)
        assertFalse(idle.needsFrameProbe)
        assertFalse(idle.blocked)
        val batched = idle.copy(batched = true, frameProbeDelay = 0)
        assertTrue(batched.needsFrameProbe)
        assertFalse(batched.blocked)
        assertTrue(batched.copy(frameProbeDelay = 4000).blocked)
    }
    @Test fun backgroundAndRecentInputDoNotTriggerRecovery() {
        val pending = InputStallEvidence(true, 1, false, 4000, 0, 0, false)
        assertTrue(pending.blocked)
        assertFalse(pending.copy(focused = false).blocked)
        assertFalse(pending.copy(inputAge = 100).blocked)
    }
    @Test fun systemAnrStillCountsWhenAppQueueAppearsEmpty() {
        val observed = InputStallEvidence(true, 0, false, 6000, 0, 0, true)
        assertTrue(observed.blocked)
        assertFalse(observed.copy(newSystemAnr = false).blocked)
    }

    @Test fun inactivityDoesNotRestart() {
        val policy = RecallRecoveryPolicy()
        for (time in 0L..60000L step 2000) assertEquals(RecallRecoveryPolicy.Action.NONE, policy.observe(time, false, true))
        assertEquals(0, policy.automaticRestarts)
    }
    @Test fun requiresSustainedEvidenceAndWaitsForSave() {
        val policy = RecallRecoveryPolicy()
        assertEquals(RecallRecoveryPolicy.Action.NONE, policy.observe(0, true, true))
        assertEquals(RecallRecoveryPolicy.Action.NONE, policy.observe(5000, true, true))
        assertEquals(RecallRecoveryPolicy.Action.NONE, policy.observe(8000, true, false))
        assertEquals(0, policy.automaticRestarts)
        assertEquals(RecallRecoveryPolicy.Action.RESTART, policy.observe(10000, true, true))
        assertEquals(RecallRecoveryPolicy.Action.NONE, policy.observe(20000, true, true))
    }
    @Test fun oneAutomaticRestartThenOfferStandardWithoutLooping() {
        val policy = RecallRecoveryPolicy()
        policy.observe(0, true, true)
        assertEquals(RecallRecoveryPolicy.Action.RESTART, policy.observe(6000, true, true))
        policy.resetObservation()
        policy.observe(20000, true, true)
        assertEquals(RecallRecoveryPolicy.Action.OFFER_FALLBACK, policy.observe(26000, true, true))
        assertEquals(RecallRecoveryPolicy.Action.NONE, policy.observe(90000, true, true))
        assertEquals(1, policy.automaticRestarts)
    }
    @Test fun transientStallResetsTheTimer() {
        val policy = RecallRecoveryPolicy()
        policy.observe(0, true, true)
        policy.observe(5000, false, true)
        policy.observe(6000, true, true)
        assertEquals(RecallRecoveryPolicy.Action.NONE, policy.observe(11000, true, true))
    }
    @Test fun checkpointExcludesUnfinishedStrokeAndIsDetachedFromEdits() {
        val history = InkStrokeHistory()
        history.begin(.1f, .2f, false); history.move(.3f, .4f); history.end()
        history.begin(.5f, .6f, true)
        val checkpoint = history.completedSnapshot()
        assertEquals(1, checkpoint.size)
        history.clear()
        assertEquals(2, checkpoint.single().points.size)
        assertFalse(checkpoint.single().erasing)
    }
}
