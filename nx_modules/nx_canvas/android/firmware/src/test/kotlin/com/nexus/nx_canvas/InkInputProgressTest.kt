package com.nexus.nx_canvas
import org.junit.Assert.*
import org.junit.Test
class InkInputProgressTest {
    @Test fun onlyTheFullyProcessedReleasedQueueHasAWatermark() {
        val p=InkInputProgress()
        p.submit(true);p.submit(null)
        assertNull(p.processed(2)) // live stroke
        p.submit(true);p.submit(false) // abandoned first start, then release
        assertNull(p.processed(1))
        assertEquals(4L,p.processed(1))
    }
    @Test fun laterQueuedStrokePreventsEarlierBatchFromSignallingIdle() {
        val p=InkInputProgress()
        p.submit(true);p.submit(false);p.submit(true);p.submit(false)
        assertNull(p.processed(2));assertEquals(4L,p.processed(2))
    }
}
