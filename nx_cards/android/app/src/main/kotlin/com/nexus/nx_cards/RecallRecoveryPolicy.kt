package com.nexus.nx_cards

/** Pure policy: silence alone is never a failure; require evidence of blocked work. */
internal class RecallRecoveryPolicy {
    enum class Action { NONE, RESTART, OFFER_FALLBACK }
    var automaticRestarts = 0
        private set
    private var suspectSince: Long? = null
    private var reported = false

    fun observe(now: Long, blocked: Boolean, safe: Boolean): Action {
        if (!blocked) {
            suspectSince = null
            reported = false
            return Action.NONE
        }
        val since = suspectSince ?: now.also { suspectSince = it }
        if (!safe || reported || now - since < 6000) return Action.NONE
        reported = true
        return if (automaticRestarts == 0) {
            automaticRestarts++
            Action.RESTART
        } else Action.OFFER_FALLBACK
    }
    fun resetObservation() { suspectSince = null; reported = false }
}

/** Missing frames only count when something is actually waiting for them. */
internal data class InputStallEvidence(
    val focused: Boolean, val outstanding: Int, val batched: Boolean,
    val inputAge: Long, val syncDelay: Long, val frameProbeDelay: Long,
    val newSystemAnr: Boolean
) {
    val needsFrameProbe get() = focused &&
        ((outstanding > 0 || batched) && inputAge >= 2000 || syncDelay >= 2000)
    val blocked get() = focused && (newSystemAnr ||
        outstanding > 0 && inputAge >= 4000 || needsFrameProbe && frameProbeDelay >= 4000)
}
