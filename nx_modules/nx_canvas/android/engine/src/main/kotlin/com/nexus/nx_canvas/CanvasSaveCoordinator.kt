package com.nexus.nx_canvas

/** FIFO durability with stale-ack filtering. Owns retries, not the UI or the store. */
class CanvasSaveCoordinator(
    private val session: String, private val title: String,
    private val store: CanvasRecoveryStore, private val worker: CanvasExecutor,
    private val owner: CanvasScheduler, private val token: () -> String,
    private val diagnostics: DiagnosticSink = NoCanvasDiagnostics,
    private val state: (SaveState) -> Unit,
) {
    enum class SaveState { SAVING, SAVED, RETRYING }
    private var generation = 0L
    private var latest: InkSnapshot? = null
    private var retry: Cancellation? = null
    private var closed = false
    private val pending = java.util.concurrent.atomic.AtomicInteger()
    val pendingSaves get() = pending.get()
    fun checkpoint(revision: CanvasRevision) {
        check(revision.session == session)
        if (closed) return
        latest = revision.drawing
        val attempt = ++generation; val saveToken = token()
        retry?.cancel(); retry = null
        state(SaveState.SAVING); pending.incrementAndGet()
        worker.execute {
            val result = runCatching { diagnostics.measure("journal.save", mapOf("revision" to revision.number)) { store.save(session, title, revision.drawing, saveToken) } }
            pending.decrementAndGet()
            owner.execute {
                if (closed || generation != attempt) return@execute
                if (result.isSuccess) state(SaveState.SAVED)
                else { state(SaveState.RETRYING); retry = owner.after(2000) { checkpoint(revision) } }
            }
        }
    }
    fun barrier(done: (Boolean) -> Unit) {
        val expected = latest
        worker.execute {
            val result = runCatching { store.recover()?.let { it.session == session && it.drawing == expected } == true }
            owner.execute { if (!closed) done(result.getOrDefault(false)) }
        }
    }
    fun close() { closed = true; retry?.cancel(); retry = null }
}
