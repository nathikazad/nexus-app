package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.io.RandomAccessFile
import java.nio.file.Files

class CanvasRuntimeTest {
    @Test(timeout=1000) fun diagnosticsDropOverflowWithoutBlockingInputAndPreserveOrder() {
        val buffer=InkDiagnosticBuffer(2)
        buffer.offer(mapOf("event" to "first"));buffer.offer(mapOf("event" to "second"))
        repeat(10000){buffer.offer(mapOf("event" to "overflow"))}
        assertEquals(10000L,buffer.dropped.get())
        assertEquals("first",buffer.take()["event"])
        assertEquals("second",buffer.take()["event"])
        buffer.offer(mapOf("event" to "recovered"))
        assertEquals("recovered",buffer.take()["event"])
    }

    private fun stroke(id:String,x:Double=10.0)=NativeStroke(id,listOf(InkPoint(x,10.0),InkPoint(x+30,20.0)),0xff000000L,4.0)
    private fun scene(strokes:List<NativeStroke>,view:InkViewport=InkViewport())=InkSnapshot(strokes,view,emptyList(),InkBoards(800.0,1000.0))
    @Test fun visibleIndexIncludesCrossingAndWideStrokesButSkipsOtherBoards() {
        val crossing=stroke("cross").copy(points=listOf(InkPoint(-800.0,20.0),InkPoint(1600.0,20.0)))
        val wide=stroke("wide",-3.0).copy(points=listOf(InkPoint(-3.0,40.0)),width=10.0)
        val index=InkSpatialIndex(listOf(stroke("local"),stroke("far",3000.0),crossing,wide))
        assertEquals(listOf("local","cross","wide"),index.query(InkBounds(0.0,0.0,800.0,1000.0)).map{it.id})
        assertEquals(listOf("far"),index.query(InkBounds(2900.0,0.0,3200.0,100.0)).map{it.id})
    }
    @Test fun replacingSameIdInvalidatesGeometryAndUndoRestoresIt() {
        val original=stroke("a");val index=InkSpatialIndex(listOf(original))
        index.update(listOf(original.copy(points=listOf(InkPoint(2000.0,20.0)))))
        assertTrue(index.query(InkBounds(0.0,0.0,800.0,1000.0)).isEmpty())
        index.update(listOf(original));assertEquals(listOf(original),index.query(InkBounds(0.0,0.0,800.0,1000.0)))
    }
    @Test fun journalRecoversStrokeEraseUndoAndViewportAcrossRestart()=withFile { file ->
        val journal=InkJournal(file);val a=stroke("a");val b=stroke("b",900.0)
        journal.save("doc","title",scene(listOf(a)),"1")
        journal.save("doc","title",scene(listOf(a,b)),"2")
        journal.save("doc","title",scene(listOf(b)),"3")
        journal.save("doc","title",scene(listOf(a,b),InkViewport(-200.0,0.0)),"4")
        val recovered=InkJournal(file).read()!!
        assertEquals("4",recovered.token);assertEquals(listOf(a,b),recovered.snapshot.strokes)
        assertEquals(-200.0,recovered.snapshot.view.x,0.0)
        assertFalse(journal.acknowledge("3"));assertTrue(file.exists())
        assertTrue(journal.acknowledge("4"));assertNull(InkJournal(file).read())
    }
    @Test fun truncatedTailRetainsPreviousSaveAndNextWriteRepairsIt()=withFile { file ->
        InkJournal(file).save("doc","title",scene(listOf(stroke("a"))),"1")
        RandomAccessFile(file,"rw").use{it.seek(it.length());it.writeInt(400);it.write(byteArrayOf(1,2,3))}
        assertEquals("1",InkJournal(file).read()!!.token)
        InkJournal(file).save("doc","title",scene(listOf(stroke("a"),stroke("b"))),"2")
        assertEquals("2",InkJournal(file).read()!!.token)
    }
    @Test fun journalRejectsOtherCanvasAndCompactsWithoutLosingRecovery()=withFile { file ->
        val journal=InkJournal(file,compactEvery=3)
        repeat(8){journal.save("doc","title",scene(listOf(stroke("$it"))),"$it")}
        assertEquals("7",InkJournal(file).read()!!.token)
        try {journal.save("other","title",scene(emptyList()),"8");fail("must reject different canvas")}catch(_:IllegalArgumentException){}
        assertEquals("7",journal.read()!!.token)
    }
    @Test fun cacheEvictsByBytes() {
        val disposed=mutableListOf<String>()
        val cache=InkLruCache<String,String>(10,{it.length.toLong()},{disposed.add(it)})
        cache.put("a","123456");cache.put("b","1234");assertEquals("123456",cache["a"])
        cache.put("c","12345");assertNull(cache["a"]);assertNull(cache["b"]);assertEquals(5L,cache.bytes)
        cache.clear();assertEquals(3,disposed.size);assertEquals(0L,cache.bytes)
    }
    @Test fun telemetryAggregatesAndResetsWithoutInkContent() {
        val metrics=InkMetrics();metrics.record("render_ms",12.0);metrics.record("render_ms",30.0)
        val batch=metrics.drain()
        assertEquals(2L,(batch["render_ms"] as Map<*,*>)["count"])
        assertEquals(30.0,(batch["render_ms"] as Map<*,*>)["max"])
        assertTrue(metrics.drain().isEmpty())
    }
    @Test fun queuedNavigationPreservesDistanceAndOrderWithoutDuplicateSteps() {
        val queue=InkNavigationQueue();val boards=InkBoards(800.0,1000.0)
        repeat(4){queue.add(1,0,false)}
        assertEquals(InkViewport(-800.0,0.0),queue.apply(boards,InkViewport(),800.0,1000.0))
        assertTrue(queue.isEmpty)
        queue.add(-1,0,true);queue.add(0,1,false)
        assertEquals(InkViewport(0.0,-250.0),queue.apply(boards,InkViewport(-800.0,0.0),800.0,1000.0))
    }
    @Test fun checksumFailureNeverAcknowledgesTornRevision()=withFile { file ->
        val first=InkJournal(file);first.save("doc","title",scene(listOf(stroke("a"))),"1")
        val boundary=file.length()
        first.save("doc","title",scene(listOf(stroke("a"),stroke("b"))),"2")
        RandomAccessFile(file,"rw").use{it.seek(boundary+12);it.writeByte(99)}
        val restarted=InkJournal(file)
        assertEquals("1",restarted.read()!!.token);assertFalse(restarted.acknowledge("2"))
    }
    @Test fun navigationWaitsForActualCompletionIncludingRapidConsecutiveStrokes() {
        val gate=InkDrainGate();assertFalse(gate.pending)
        gate.begin();gate.end();assertTrue(gate.pending)
        gate.begin();gate.complete();assertTrue(gate.pending)
        gate.end();assertTrue(gate.pending)
        gate.complete();assertFalse(gate.pending)
        gate.begin();gate.complete();assertTrue(gate.pending)
        gate.end();assertFalse(gate.pending)
        gate.begin();gate.cancel();assertFalse(gate.pending)
    }
    @Test fun completedRecordsDeduplicateByIdentityNotEqualCoordinates() {
        data class Record(val points:List<Int>)
        val a=Record(listOf(1,2));val b=Record(listOf(1,2));val records=InkRecordSet()
        assertTrue(records.add(a));assertFalse(records.add(a));assertTrue(records.add(b))
        records.clear();assertTrue(records.add(a))
    }
    @Test fun compactionFailureLeavesPreviouslyDurableInkIntact()=withFile { file ->
        val journal=InkJournal(file,compactEvery=1)
        journal.save("doc","title",scene(listOf(stroke("a"))),"1")
        File(file.path+".compact").mkdir()
        try {journal.save("doc","title",scene(listOf(stroke("b"))),"2");fail("Expected disk error")}catch(_:java.io.IOException){}
        assertEquals("1",InkJournal(file).read()!!.token)
        assertEquals(listOf(stroke("a")),InkJournal(file).read()!!.snapshot.strokes)
    }
    private fun withFile(block:(File)->Unit) {
        val directory=Files.createTempDirectory("canvas-journal").toFile()
        try {block(File(directory,"journal"))} finally {directory.deleteRecursively()}
    }
}
