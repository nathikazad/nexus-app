package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class CanvasPreviewCoordinatorTest {
    private class Queue:CanvasExecutor {
        val tasks=java.util.ArrayDeque<()->Unit>()
        override fun execute(work:()->Unit){tasks.add(work)}
        fun run(){while(tasks.isNotEmpty())tasks.removeFirst()()}
    }
    @Test fun preparationRunsOnWorkerAndOnlyNewestResultReachesOwner() {
        val worker=Queue();val owner=Queue();val displayed=mutableListOf<Int>();val discarded=mutableListOf<Int>()
        val c=CanvasPreviewCoordinator<Int>(worker,owner,{discarded.add(it)},{throw it})
        var prepared=false
        c.request({prepared=true;1},{displayed.add(it)})
        assertFalse(prepared)
        c.request({2},{displayed.add(it)})
        worker.run();assertTrue(prepared);assertTrue(displayed.isEmpty())
        owner.run();assertEquals(listOf(1),discarded);assertEquals(listOf(2),displayed)
    }
    @Test fun dismissedOrClosedPreviewCannotPublishAndDiscardsItsImage() {
        val worker=Queue();val owner=Queue();val discarded=mutableListOf<Int>()
        val c=CanvasPreviewCoordinator<Int>(worker,owner,{discarded.add(it)},{throw it})
        c.request({1},{fail("dismissed preview")});c.cancel();worker.run();owner.run()
        c.request({2},{fail("closed preview")});worker.run();c.close();owner.run()
        assertEquals(listOf(1,2),discarded)
    }
    @Test fun failedCurrentPreparationIsReportedButCancelledFailureIsIgnored() {
        val worker=Queue();val owner=Queue();val errors=mutableListOf<Throwable>()
        val c=CanvasPreviewCoordinator<Int>(worker,owner,{}, {errors.add(it)})
        c.request({error("old")},{});c.cancel();worker.run();owner.run();assertTrue(errors.isEmpty())
        c.request({error("current")},{});worker.run();owner.run();assertEquals("current",errors.single().message)
    }
}
