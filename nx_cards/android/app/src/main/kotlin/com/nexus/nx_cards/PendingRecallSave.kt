package com.nexus.nx_cards

/** One outstanding save keeps review ordering intact while the next card is usable. */
internal class PendingRecallSave {
    data class Answer(val index: Int, val correct: Boolean, val revealedAt: Long) {
        fun arguments(): Map<String, Any> = mapOf("index" to index, "correct" to correct, "revealedAt" to revealedAt)
    }
    var answer: Answer? = null
        private set
    fun begin(index: Int, correct: Boolean, revealedAt: Long): Answer? {
        if (answer != null) return null
        return Answer(index, correct, revealedAt).also { answer = it }
    }
    fun complete(saved: Answer) {
        check(answer === saved) { "Unexpected save completion" }
        answer = null
    }
}
