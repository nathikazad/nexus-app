package com.nexus.nx_canvas

/** Serial worker preparation; only the newest request may reach the UI. Owner-thread API. */
class CanvasPreviewCoordinator<T>(
    private val worker: CanvasExecutor, private val owner: CanvasExecutor,
    private val discard: (T) -> Unit, private val failed: (Throwable) -> Unit,
) : AutoCloseable {
    private var generation=0L
    private var closed=false
    fun request(prepare: () -> T, present: (T) -> Unit) {
        check(!closed)
        val token=++generation
        worker.execute {
            val result=runCatching(prepare)
            owner.execute {
                result.fold({ value -> if(closed || token!=generation)discard(value) else present(value) },
                    { error -> if(!closed && token==generation)failed(error) })
            }
        }
    }
    fun cancel() { generation++ }
    override fun close() { closed=true; cancel() }
}
