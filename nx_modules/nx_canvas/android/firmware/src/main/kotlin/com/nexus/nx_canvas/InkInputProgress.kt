package com.nexus.nx_canvas

/** Counts every point submitted to NoteView against batches completed by its worker.
 * An observed down is not proof that a stroke record will ever be created.
 * This watermark reconciles empty/abandoned starts without guessing a time delay.
 */
class InkInputProgress {
    private var submitted = 0L
    private var processed = 0L
    private var penDown = false
    @Synchronized fun isPenDown() = penDown
    @Synchronized fun isDrained() = processed == submitted && !penDown
    @Synchronized fun submit(boundary: Boolean?): Long {
        submitted++
        if(boundary != null)penDown = boundary
        return submitted
    }
    @Synchronized fun processed(count: Int): Long? {
        processed += count
        return if(processed == submitted && !penDown) submitted else null
    }
}
