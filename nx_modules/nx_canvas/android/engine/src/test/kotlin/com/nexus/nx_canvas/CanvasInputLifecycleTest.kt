package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class CanvasInputLifecycleTest {
    private class Scheduler:CanvasScheduler {
        val timers=mutableListOf<()->Unit>()
        override fun execute(work:()->Unit)=work()
        override fun after(milliseconds:Long,work:()->Unit):Cancellation {timers.add(work);return Cancellation{timers.remove(work)}}
        fun expire(){val copy=timers.toList();timers.clear();copy.forEach{it()}}
    }
    private class Firmware:CanvasFirmwarePort {
        var idle=true
        var completionAttempts=0
        var failTool=false
        val sent=mutableListOf<String>()
        override fun send(packet:CanvasPenPacket){idle=false;sent.add("${packet.action}:${packet.x}")}
        override fun isDrained()=idle
        override fun finishPendingStroke(){completionAttempts++}
        override fun changeTool(tool:CanvasPenTool){check(idle);if(failTool)error("tool");sent.add(tool.tool.name)}
    }
    private fun point(action:Int,x:Int=10)=CanvasPenPacket(action,x,20,1024,1)
    @Test fun toolChangeSplitsActiveStrokeThenReplaysQueuedInputWithoutClearingIt() {
        val f=Firmware();val s=Scheduler();val c=CanvasInputLifecycle(f,s,fault={fail(it)})
        c.tool(CanvasPenTool(NativeTool.PEN,3.0));c.enable(true)
        c.submit(point(1));c.submit(point(2,11))
        c.tool(CanvasPenTool(NativeTool.REGION,20.0))
        c.submit(point(2,12));c.submit(point(3,13))
        assertEquals(listOf("PEN","1:10","2:11","3:11"),f.sent)
        f.idle=true;c.progressed()
        assertEquals(listOf("PEN","1:10","2:11","3:11","REGION","1:11","2:12","3:13"),f.sent)
        var done=false;c.drain{done=it};assertFalse(done)
        f.idle=true;c.progressed();assertTrue(done)
    }
    @Test fun rapidToolRequestsDoNotReorderPacketsOrMutateBusyFirmware() {
        val f=Firmware();val c=CanvasInputLifecycle(f,Scheduler(),fault={fail(it)})
        c.enable(true);c.submit(point(1));c.tool(CanvasPenTool(NativeTool.REGION,20.0))
        c.submit(point(2,12));c.tool(CanvasPenTool(NativeTool.PEN,3.0));c.submit(point(3,13))
        f.idle=true;c.progressed()
        assertEquals(listOf("1:10","3:10","REGION","1:10","2:12","3:12"),f.sent)
        f.idle=true;c.progressed()
        assertEquals(listOf("PEN","1:12","3:13"),f.sent.takeLast(3))
    }
    @Test fun drainFinishesStrokeEvenAfterIngressDisabledAndDoesNotResumeIt() {
        val f=Firmware();val c=CanvasInputLifecycle(f,Scheduler(),fault={fail(it)})
        c.enable(true);c.submit(point(1));c.enable(false)
        var done=false;c.drain{done=it};c.submit(point(2,99))
        assertEquals(listOf("1:10","3:10"),f.sent);assertFalse(done)
        f.idle=true;c.progressed();assertTrue(done)
        assertEquals(listOf("1:10","3:10"),f.sent)
    }
    @Test fun timeoutRetainsBarrierAndRetryCompletesOnlyAfterRealDrain() {
        val f=Firmware();val s=Scheduler();var faults=0
        val c=CanvasInputLifecycle(f,s,fault={faults++});val replies=mutableListOf<Boolean>()
        c.enable(true);c.submit(point(1));c.drain{replies.add(it)};s.expire()
        assertEquals(1,faults);assertEquals(listOf(false),replies)
        var retry=false;c.drain{retry=it};assertFalse(retry);assertEquals(1,f.completionAttempts)
        f.idle=true;c.progressed();assertTrue(retry)
        assertEquals(listOf(false),replies) // expired callback cannot run again and close a later UI
    }
    @Test fun toolFailureRetainsIntentAndCanBeRetriedWithoutLosingQueuedPoints() {
        val f=Firmware();val s=Scheduler();var faults=0
        val c=CanvasInputLifecycle(f,s,fault={faults++})
        f.failTool=true;c.tool(CanvasPenTool(NativeTool.PEN,3.0))
        assertEquals(1,faults)
        f.failTool=false;var recovered=false;c.drain{recovered=it}
        assertTrue(recovered);assertEquals(listOf("PEN"),f.sent)
    }
    @Test fun palmEventsDoNotRelocateOrEndTheActivePen() {
        val f=Firmware();val c=CanvasInputLifecycle(f,Scheduler(),fault={fail(it)})
        c.enable(true);c.submit(point(1));c.submit(point(3,99).copy(tool=2))
        c.drain{}
        assertEquals("3:10",f.sent.last())
    }
    @Test fun duplicateDownPreservesOldSegmentAndCloseDropsNoCommittedCallback() {
        val f=Firmware();val c=CanvasInputLifecycle(f,Scheduler(),fault={fail(it)})
        c.enable(true);c.submit(point(1));c.submit(point(1,11));c.submit(point(3,12))
        assertEquals(listOf("1:10","3:10","1:11","3:12"),f.sent)
        c.close();c.submit(point(1,99));assertEquals(4,f.sent.size)
    }
}
