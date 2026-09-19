package com.nexus.nx_canvas
import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files

class RecoveryContractTest {
    @Test fun adapterPreservesLegacyJournalAcrossRestartAndRequiresExactToken() {
        val directory=Files.createTempDirectory("canvas-recovery").toFile()
        try {
            val file=java.io.File(directory,"native-editor-journal.bin")
            val snapshot=InkSnapshot(listOf(NativeStroke("one",listOf(InkPoint(1.0,2.0)),0,3.0)),InkViewport(),emptyList(),null)
            val store:CanvasRecoveryStore=InkJournal(file)
            store.save("session","title",snapshot,"durable")
            val restarted:CanvasRecoveryStore=InkJournal(file)
            assertEquals(snapshot,restarted.recover()!!.drawing)
            assertFalse(restarted.acknowledge("old"));assertTrue(file.exists())
            assertTrue(restarted.acknowledge("durable"));assertNull(restarted.recover())
        } finally {directory.deleteRecursively()}
    }
}
