package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test

class CanvasEngineTest {
    private class Queue : CanvasScheduler {
        val tasks = java.util.ArrayDeque<() -> Unit>()
        val timers = mutableListOf<() -> Unit>()
        override fun execute(work: () -> Unit) { tasks.add(work) }
        override fun after(milliseconds: Long, work: () -> Unit): Cancellation { timers.add(work); return Cancellation { timers.remove(work) } }
        fun run() { while(tasks.isNotEmpty())tasks.removeFirst()() }
        fun tick() { val ready = timers.toList(); timers.clear(); ready.forEach { it() } }
    }
    private fun stroke(id: String) = NativeStroke(id, listOf(InkPoint(1.0, 2.0)), 0xff000000, 3.0)
    private fun initial() = InkSnapshot(emptyList(), InkViewport(), emptyList(), InkBoards(800.0,1000.0))
    private fun engine() = CanvasEngine("session", initial())
    @Test fun commandsOwnHistoryAndRevisionWithoutExposingMutableModel() {
        val engine = engine()
        engine.dispatch(CanvasCommand.ReplaceInk(listOf(stroke("a"))))
        assertTrue(engine.canUndo)
        val revision = engine.snapshot()
        val copy = engine.presentation(); copy.view = InkViewport(999.0); copy.replace(emptyList())
        assertEquals(revision, engine.snapshot())
        engine.dispatch(CanvasCommand.Undo); assertTrue(engine.snapshot().drawing.strokes.isEmpty())
        engine.dispatch(CanvasCommand.Redo); assertEquals("a", engine.snapshot().drawing.strokes.single().id)
        assertEquals(3L,engine.snapshot().number)
    }
    @Test fun engineRejectsWrongThread() {
        val e=engine();var failure:Throwable?=null
        val t=Thread { try { e.snapshot() } catch(error:Throwable) { failure=error } };t.start();t.join()
        assertTrue(failure is IllegalStateException)
    }
    private class Record(val id:String, val fail:Boolean=false): CanvasInputRecord {
        override val completesStroke=true
        override fun decode(transform:InputTransform):InkOperation {
            if(fail)error("decode")
            return InkOperation(InkOperationKind.DRAW,NativeStroke(id,listOf(InkPoint(1.0,2.0)),0,3.0))
        }
    }
    private val transform=InputTransform(InkViewport(),0,800,1000,1.0)
    @Test fun importsAreSerialAndDrainOnlyAfterLastAppliedRecord() {
        val e=engine();val worker=Queue();val owner=Queue();var changed=0
        val input=CanvasInputCoordinator(e,worker,owner,changed={changed++},settled={},failed={throw it})
        input.accept(InputEvent.Down(),transform);input.accept(InputEvent.Up(),transform)
        input.accept(InputEvent.Completed(Record("a")),transform)
        input.accept(InputEvent.Down(),transform);input.accept(InputEvent.Up(),transform)
        input.accept(InputEvent.Completed(Record("b")),transform)
        assertEquals(DrainResult.Unresolved,input.drain())
        worker.run();owner.run();assertEquals(1,changed)
        worker.run();owner.run();assertEquals(2,changed)
        assertEquals(listOf("a","b"),e.snapshot().drawing.strokes.map{it.id})
        assertEquals(DrainResult.Complete,input.drain())
    }
    @Test fun orphanDownReconcilesOnlyAfterQueueDrainAndImportCompletion() {
        val w=Queue();val o=Queue();val e=engine();val input=CanvasInputCoordinator(e,w,o,changed={},settled={},failed={})
        input.accept(InputEvent.Down(1),transform);input.accept(InputEvent.Down(2),transform)
        input.accept(InputEvent.Up(3),transform);input.accept(InputEvent.Completed(Record("one")),transform)
        assertEquals(DrainResult.Unresolved,input.drain())
        input.accept(InputEvent.Quiescent(3),transform)
        assertEquals(DrainResult.Unresolved,input.drain()) // decoded ink still must be applied
        w.run();o.run()
        assertEquals(DrainResult.Complete,input.drain())
        assertEquals("one",e.snapshot().drawing.strokes.single().id)
    }
    @Test fun staleQueueDrainCannotReleaseANewerStroke() {
        val q=Queue();val input=CanvasInputCoordinator(engine(),q,q,changed={},settled={},failed={})
        input.accept(InputEvent.Down(1),transform);input.accept(InputEvent.Up(2),transform)
        input.accept(InputEvent.Down(3),transform)
        input.accept(InputEvent.Quiescent(2),transform)
        assertTrue(input.penPending)
        input.accept(InputEvent.Up(4),transform)
        input.accept(InputEvent.Quiescent(2),transform)
        assertTrue(input.penPending)
        input.accept(InputEvent.Quiescent(4),transform)
        assertEquals(DrainResult.Complete,input.drain())
    }
    @Test fun cancellationReleasesAnUncompletedStart() {
        val q=Queue();val input=CanvasInputCoordinator(engine(),q,q,changed={},settled={},failed={})
        input.accept(InputEvent.Down(),transform);input.accept(InputEvent.Cancelled,transform)
        assertEquals(DrainResult.Complete,input.drain())
    }
    @Test fun importFailureBlocksDestructiveTransition() {
        val w=Queue();val o=Queue();var failure=false
        val input=CanvasInputCoordinator(engine(),w,o,changed={},settled={},failed={failure=true})
        input.accept(InputEvent.Completed(Record("bad",true)),transform);w.run();o.run()
        assertTrue(failure);assertEquals(DrainResult.Unresolved,input.drain())
    }
    @Test fun failedRecordAndFollowingInkAreRetainedInOrderUntilExplicitRetry() {
        val w=Queue();val o=Queue();val e=engine();var fail=true
        val input=CanvasInputCoordinator(e,w,o,changed={},settled={},failed={})
        val record=object:CanvasInputRecord {
            override val completesStroke=true
            override fun decode(transform:InputTransform):InkOperation {
                if(fail)error("temporary failure")
                return InkOperation(InkOperationKind.DRAW,stroke("first"))
            }
        }
        input.accept(InputEvent.Completed(record),transform)
        input.accept(InputEvent.Completed(Record("second")),transform)
        w.run();o.run();assertEquals(2,input.pendingImports);assertTrue(e.snapshot().drawing.strokes.isEmpty())
        fail=false;input.retry();w.run();o.run();w.run();o.run()
        assertEquals(listOf("first","second"),e.snapshot().drawing.strokes.map{it.id})
        assertEquals(DrainResult.Complete,input.drain())
    }
    @Test fun closingDrainsAlreadyAcceptedInkBeforeReleasingSession() {
        val w=Queue();val o=Queue();val e=engine();var closed=false
        val input=CanvasInputCoordinator(e,w,o,changed={},settled={},failed={throw it})
        input.accept(InputEvent.Completed(Record("a")),transform);input.close{closed=true}
        input.accept(InputEvent.Completed(Record("ignored")),transform)
        assertFalse(closed);w.run();o.run();assertTrue(closed)
        assertEquals(listOf("a"),e.snapshot().drawing.strokes.map{it.id})
    }
    @Test fun actionTimeoutReportsUnresolvedAndDoesNotExecuteOrResetInput() {
        val q=Queue();var drain:DrainResult=DrainResult.Unresolved;var ran=false;var timeout=false
        val gate=CanvasActionGate({drain},q)
        gate.submit({ran=true},{timeout=true});q.tick()
        assertFalse(ran);assertTrue(timeout)
        drain=DrainResult.Complete;gate.drain();assertFalse(ran)
        gate.submit({ran=true},{fail()});assertTrue(ran)
    }
    @Test fun actionCompletionCancelsItsTimeout() {
        val q=Queue();var drain:DrainResult=DrainResult.Unresolved;var count=0
        val gate=CanvasActionGate({drain},q);gate.submit({count++},{fail()})
        drain=DrainResult.Complete;gate.drain();q.tick();assertEquals(1,count)
    }
    private class Frame(val id:Long):CanvasFrame {var releases=0;override fun release(){releases++}}
    private class Renderer:CanvasRenderer<Frame> {
        val reused=mutableListOf<Frame?>();val frames=mutableListOf<Frame>();var closed=false
        override fun render(request:CanvasRenderRequest,reusable:Frame?):Frame {
            reused.add(reusable);return (reusable?:Frame(request.revision.number)).also{frames.add(it)}
        }
        override fun close(){closed=true}
    }
    @Test fun rendererSuppressesStaleFramesAndReusesOnlyUnpresentedBuffers() {
        val e=engine();val w=Queue();val o=Queue();val renderer=Renderer();val shown=mutableListOf<Frame>()
        val c=CanvasRenderCoordinator(renderer,w,o,{e.snapshot()},{true},{shown.add(it)},{},{throw it})
        fun request()=c.request(CanvasRenderRequest(e.snapshot(),1.0,800,1000,0))
        request();e.dispatch(CanvasCommand.SetView(InkViewport(1.0)));request()
        w.run();o.run();assertTrue(shown.isEmpty())
        w.run();o.run();assertEquals(1,shown.size)
        val front=shown.single();assertEquals(0,front.releases)
        e.dispatch(CanvasCommand.SetView(InkViewport(2.0)));request();w.run();o.run()
        assertNull(renderer.reused.last());assertEquals(0,front.releases)
        e.dispatch(CanvasCommand.SetView(InkViewport(3.0)));request();w.run();o.run()
        assertSame(front,renderer.reused.last())
        c.close();w.run();assertTrue(renderer.closed)
        assertTrue(renderer.frames.distinct().all{it.releases==1})
    }
    @Test fun closeDiscardsLateRenderAndDoesNotPresentIt() {
        val w=Queue();val o=Queue();val e=engine();val renderer=Renderer()
        val c=CanvasRenderCoordinator(renderer,w,o,{e.snapshot()},{true},{fail()},{},{throw it})
        c.request(CanvasRenderRequest(e.snapshot(),1.0,10,10,0));c.close();w.run();o.run()
        assertEquals(1,renderer.frames.single().releases)
    }
    private class Store:CanvasRecoveryStore {
        var saved:CanvasRecovery?=null;var fail=false
        override fun save(session:String,title:String,drawing:InkSnapshot,token:String){if(fail)error("disk");saved=CanvasRecovery(session,title,drawing,token)}
        override fun recover()=saved
        override fun acknowledge(token:String):Boolean {if(saved?.token!=token)return false;saved=null;return true}
    }
    @Test fun saveFailureRetriesAndBarrierReflectsActualDurability() {
        val w=Queue();val o=Queue();val store=Store();store.fail=true;val e=engine()
        val states=mutableListOf<CanvasSaveCoordinator.SaveState>()
        val c=CanvasSaveCoordinator("session","title",store,w,o,{"token"},state={states.add(it)})
        c.checkpoint(e.snapshot());w.run();o.run();assertEquals(CanvasSaveCoordinator.SaveState.RETRYING,states.last())
        var durable=true;c.barrier{durable=it};w.run();o.run();assertFalse(durable)
        store.fail=false;o.tick();w.run();o.run();c.barrier{durable=it};w.run();o.run()
        assertTrue(durable);assertEquals(CanvasSaveCoordinator.SaveState.SAVED,states.last())
    }
    @Test fun oldSaveCompletionCannotReportNewRevisionSaved() {
        val w=Queue();val o=Queue();val store=Store();val e=engine();val states=mutableListOf<CanvasSaveCoordinator.SaveState>()
        val c=CanvasSaveCoordinator("session","title",store,w,o,{"token"},state={states.add(it)})
        c.checkpoint(e.snapshot());w.run()
        e.dispatch(CanvasCommand.ReplaceInk(listOf(stroke("new"))));c.checkpoint(e.snapshot());o.run()
        assertEquals(listOf(CanvasSaveCoordinator.SaveState.SAVING,CanvasSaveCoordinator.SaveState.SAVING),states)
        w.run();o.run();assertEquals("new",store.saved!!.drawing.strokes.single().id)
    }
    @Test fun saveRejectsAnotherSession() {
        val q=Queue();val c=CanvasSaveCoordinator("one","",Store(),q,q,{""},state={})
        try{c.checkpoint(engine().snapshot());fail()}catch(_:IllegalStateException){}
    }
}
