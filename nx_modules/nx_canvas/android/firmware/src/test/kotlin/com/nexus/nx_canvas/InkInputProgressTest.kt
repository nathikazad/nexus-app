package com.nexus.nx_canvas
import org.junit.Assert.*
import org.junit.Test
class InkInputProgressTest {
    @org.junit.Test fun closingAdmissionPreservesRealStrokeUntilUpAndWorkerDrain() {
        val p = InkInputProgress()
        p.admitNewStrokes(true)
        org.junit.Assert.assertTrue(p.acceptsInput())
        p.submit(true)
        p.admitNewStrokes(false)
        repeat(100) {
            org.junit.Assert.assertTrue(p.acceptsInput())
            p.submit(null)
        }
        org.junit.Assert.assertTrue(p.acceptsInput()) // real up still admitted
        p.submit(false)
        org.junit.Assert.assertFalse(p.acceptsInput()) // next contact waits
        org.junit.Assert.assertFalse(p.isDrained())
        p.processed(102)
        org.junit.Assert.assertTrue(p.isDrained())
        p.admitNewStrokes(true)
        org.junit.Assert.assertTrue(p.acceptsInput())
    }

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
