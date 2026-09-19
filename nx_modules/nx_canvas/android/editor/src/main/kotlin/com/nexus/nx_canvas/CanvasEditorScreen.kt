package com.nexus.nx_canvas

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.graphics.*
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.widget.*
import java.util.UUID
import kotlin.math.roundToInt

/** Entire editor is Android-native. The stock NoteView owns live pen/eraser
 * rendering. No Flutter surface, per-point bridge or drawing-thread callbacks.
 */
class CanvasEditorScreen(private val activity: Activity, private val components: CanvasComponents = CanvasServices.components) : android.content.ContextWrapper(activity) {
    private var ink:View?=null
    private lateinit var editing:NativeEditingView
    private lateinit var body:FrameLayout
    private lateinit var status:TextView
    private lateinit var boardLabel:TextView
    private var overview:NativeBoardGrid?=null
    private lateinit var boardControls:NativeBoardControls
    private var overlayTouch=false
    private val buttons=mutableMapOf<NativeTool,Button>()
    private lateinit var undoButton:Button
    private lateinit var redoButton:Button
    private val diagnostics=components.diagnostics
    private val main=Handler(Looper.getMainLooper())
    private val scheduler=AndroidCanvasScheduler(main)
    private lateinit var session: CanvasSessionResources
    private lateinit var input: AndroidCanvasInput
    private lateinit var engine: CanvasEngine
    private val model get()=engine.presentation()
    private val repository by lazy { CanvasServices.repository(applicationContext) }
    private val metrics=InkMetrics()
    private val penPending get()=session.imports.penPending
    private val pendingImports get()=session.imports.pendingImports
    private val importFailed get()=session.imports.importFailed
    private val rendering get()=session.renders.rendering
    private var documentId="prototype"
    private var title="Drawing"
    private var penWidth=3.0
    private var tool=NativeTool.PEN
    private var density=1.0
    private var ready=false
    private var busy=false
    private var resumed=false
    private var closing=false
    private var dialogOpen=false
    private var buttonErasing=false
    private lateinit var saveStatus:TextView
    private var destroyed=false
    private var latestSaveState = CanvasSaveCoordinator.SaveState.SAVED
    private val idleStatus = CanvasIdleUpdate(scheduler) {
        if (!destroyed && ::session.isInitialized) {
            // Completed ink affects history controls, not tool labels or board layout.
            undoButton.isEnabled = engine.canUndo || nativeTool()
            redoButton.isEnabled = engine.canRedo
            val text = when (latestSaveState) {
                CanvasSaveCoordinator.SaveState.SAVING -> "Saving…"
                CanvasSaveCoordinator.SaveState.SAVED -> "Saved locally"
                CanvasSaveCoordinator.SaveState.RETRYING -> "Save failed · retrying…"
            }
            if (saveStatus.text.toString() != text) saveStatus.text = text
        }
    }
    private val navigation=InkNavigationQueue()
    private var navigationScheduled=false
    private var diagnosticNavigationAt=0L

    fun onCreate(state:Bundle?) {
        if(diagnostics === CanvasDiagnostics) { CanvasDiagnostics.start(applicationContext); CanvasDiagnostics.attach(activity) }
        diagnostics.event("canvas.open")
        density=resources.displayMetrics.density.toDouble()
        val page=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setBackgroundColor(Color.WHITE)}
        val header=LinearLayout(this).apply{gravity=Gravity.CENTER_VERTICAL}
        val back=button("‹ Drawings"){finishWriting()}
        header.addView(back)
        header.addView(button("Retry input") {
            session.imports.retry()
            perform("retry_input") { checkpoint();updateControls() }
        })
        val name=TextView(this).apply{textSize=18f;setPadding(dp(12),0,dp(8),0);maxLines=1}
        header.addView(name,LinearLayout.LayoutParams(0,-2,1f))
        page.addView(header)
        val tools=LinearLayout(this)
        fun toolButton(t:NativeTool,label:String) { val b=button(label){switchTool(t)};buttons[t]=b;tools.addView(b) }
        toolButton(NativeTool.PEN,"Pen")
        toolButton(NativeTool.RUB,"Rub erase")
        toolButton(NativeTool.REGION,"Region erase")
        toolButton(NativeTool.SELECT,"Lasso / move")
        tools.addView(button("Pen width"){chooseWidth()})
        undoButton=button("Undo"){perform("undo"){engine.dispatch(CanvasCommand.Undo);showTool()}}
        redoButton=button("Redo"){perform("redo"){engine.dispatch(CanvasCommand.Redo);showTool()}}
        tools.addView(undoButton);tools.addView(redoButton)
        page.addView(HorizontalScrollView(this).apply{isHorizontalScrollBarEnabled=false;addView(tools)})
        status=TextView(this).apply{textSize=12f;setPadding(dp(12),dp(2),dp(12),dp(6));text="Opening drawing…"}
        page.addView(status)
        saveStatus=TextView(this).apply{textSize=11f;setPadding(dp(12),0,dp(12),dp(4));text="Saved locally"}
        page.addView(saveStatus)
        body=FrameLayout(this)
        page.addView(body,LinearLayout.LayoutParams(-1,0,1f))
        activity.setContentView(page)
        try {
            val input=diagnostics.measure("open.read_input"){repository.scene()}
            back.text=input["backLabel"] as? String?:"‹ Drawings"
            documentId=input["documentId"] as? String?:"prototype"
            title=input["title"] as? String?:"Drawing"
            name.text=title
            val pending=diagnostics.measure("open.read_recovery"){repository.document()}
            require(pending==null || pending["documentId"]==documentId){"Another drawing has unsaved changes"}
            engine=CanvasEngine(documentId, InkSnapshot.of(diagnostics.measure("open.decode_model"){InkCodec.model((pending?.get("drawing") as? Map<*,*>)?:input)}))
            this.input=components.input(this, components.diagnostics)
            val widget=this.input.view
            ink=widget
            session=CanvasSessionResources(engine, title, repository, scheduler, components=components,
                changed={checkpoint();idleStatus.request()}, settled={drainAction()},
                failed={
                    busy=false;flag(false)
                    if(::session.isInitialized)session.actions.cancel()
                    report(it)
                },
                eligible={nativeTool()}, present={frame->this.input.present(frame.bitmap)},
                renderSettled={resumeInk()}, saveState={state->
                    latestSaveState = state
                    idleStatus.request()
                })
            this.input.onFault={message->busy=false;status.text=message;diagnostics.event("input.fault",mapOf("reason" to message))}
            this.input.onEvent={event->scheduler.execute {
                if(!destroyed) {
                    when(event) {
                        is InputEvent.Down -> idleStatus.contact(true)
                        is InputEvent.Up -> idleStatus.contact(false)
                        InputEvent.Cancelled -> idleStatus.contact(false)
                        else -> {}
                    }
                    session.imports.accept(event, InputTransform(model.view,this.input.rotation,widget.width,widget.height,density))
                }
            }}
            flag(false)
            body.addView(widget,FrameLayout.LayoutParams(-1,-1))
            editing=NativeEditingView(this,engine){checkpointSafely();updateControls()}.apply{visibility=View.GONE}
            body.addView(editing,FrameLayout.LayoutParams(-1,-1))
            boardControls=NativeBoardControls(this,{dx,dy,jump->navigateBoard(dx,dy,jump)},{showOverview()})
            body.addView(boardControls,FrameLayout.LayoutParams(dp(152),dp(152),Gravity.BOTTOM or Gravity.RIGHT).apply{
                rightMargin=dp(16);bottomMargin=dp(16)
            })
            boardLabel=TextView(this).apply{
                textSize=12f;setTextColor(Color.DKGRAY);setPadding(dp(10),dp(6),dp(10),dp(6))
                background=android.graphics.drawable.GradientDrawable().apply{
                    setColor(Color.WHITE);cornerRadius=dp(14).toFloat();setStroke(dp(1),0xffdddddd.toInt())
                }
            }
            body.addView(boardLabel,FrameLayout.LayoutParams(-2,-2,Gravity.BOTTOM or Gravity.LEFT).apply{
                leftMargin=dp(16);bottomMargin=dp(16)
            })
            // Layout gives us a size before the firmware sets its rotation.
            // Its surfaceChanged callback initializes rotation and panel buffers;
            // render only after that callback sequence has completed.
            val holder=this.input.holder
            holder.addCallback(object:SurfaceHolder.Callback {
                override fun surfaceCreated(holder:SurfaceHolder) {}
                override fun surfaceDestroyed(holder:SurfaceHolder) {}
                override fun surfaceChanged(holder:SurfaceHolder,format:Int,width:Int,height:Int) {
                    widget.post {
                        if(!ready && !closing && !activity.isFinishing && holder.surface.isValid && widget.width>0 && widget.height>0) {
                            ready=true
                            runCatching{
                                val sw=body.width/density;val sh=body.height/density
                                val legacy=model.boards==null
                                engine.dispatch(CanvasCommand.SetBoards(model.boards?:InkBoards(sw,sh)))
                                if(legacy || kotlin.math.abs(model.view.scale-kotlin.math.min(sw/model.boards!!.width,sh/model.boards!!.height))>.001)
                                    engine.dispatch(CanvasCommand.SetView(model.boards!!.view(model.boards!!.current(model.view,sw,sh),sw,sh)))
                                showTool();checkpoint()}.onFailure{ready=false;report(it)}
                        }
                    }
                }
            })
            diagnostics.event("canvas.ready")
        } catch(error:Throwable){report(error)}
    }
    private fun dp(value:Int)=(value*density).roundToInt()
    private fun button(label:String,action:()->Unit)=Button(this).apply{
        text=label;textSize=13f;isAllCaps=false;minWidth=dp(60);minimumWidth=dp(60)
        setPadding(dp(10),0,dp(10),0);setOnClickListener{if(!busy&&!closing)action()}
    }
    private fun nativeTool()=overview==null && tool in listOf(NativeTool.PEN,NativeTool.RUB,NativeTool.REGION)
    private fun flag(enabled:Boolean){if(::input.isInitialized)input.enable(enabled)}
    private fun resumeInk(){flag(ready&&resumed&&!closing&&!busy&&!dialogOpen&&!overlayTouch&&!rendering&&nativeTool())}

    private fun switchTool(next:NativeTool) {
        if(::boardControls.isInitialized)boardControls.cancelPress()
        if((next==tool && overview==null) || !ready || busy || closing)return
        val wasNative=nativeTool()
        perform("switch_tool") {
            dismissOverview();tool=next;buttonErasing=false;engine.dispatch(CanvasCommand.ClearSelection)
            if(wasNative && nativeTool()) {
                // Keep the vendor framebuffer and record list intact. A pen
                // change does not require a full-screen foreground refresh.
                setNativePen(tool)
            } else if(!wasNative && !nativeTool()) {
                editing.tool=tool;editing.invalidate()
            } else showTool()
        }
    }

    /** Wait only for real outstanding ink, not a fixed delay on every button tap. */
    private fun perform(label:String="operation",action:()->Unit) {
        if(!::session.isInitialized)return
        diagnostics.event("action.request",mapOf("action" to label,"busy" to busy,"closing" to closing,"ready" to ready,"import_failed" to importFailed,"pending_imports" to pendingImports,"pen_pending" to penPending))
        val requested=System.nanoTime()
        if(!::engine.isInitialized || !ready || busy || closing || importFailed){
            diagnostics.event("action.rejected",mapOf("action" to label))
            if(importFailed)status.text="An input operation needs recovery. Tap Retry input before leaving."
            return
        }
        busy=true
        flag(false)
        input.drain { drained ->
        if(destroyed)return@drain
        if(!drained){busy=false;status.text="Input has not finished. Lift the pen and tap Retry input.";return@drain}
        session.actions.submit(action={
            diagnostics.event("action.ready",mapOf("action" to label,"wait_ms" to (System.nanoTime()-requested)/1e6))
            val operationSpan=diagnostics.begin("action."+label)
            val before=InkSnapshot.of(model)
            try {
                editing.cancelGesture();action()
                if(InkSnapshot.of(model)!=before)checkpoint()
                updateControls()
            } catch(error:Throwable){report(error)}
            finally {busy=false;resumeInk();scheduleNavigation();operationSpan.end()}
        }, unresolved={
            busy=false;navigation.clear()
            status.text="Input has not finished. Lift the pen and tap Retry input.";resumeInk()
        })
        }
    }
    private fun drainAction() { if(::session.isInitialized)session.actions.drain() }
    private fun renderForeground() {
        if(importFailed)return
        flag(false)
        session.renders.request(CanvasRenderRequest(engine.snapshot(),density,body.width,body.height,input.rotation))
    }
    private fun showTool() {
        val diagnosticSpan=diagnostics.begin("tool.show")
        try {
        if(!ready)return
        dismissOverview()
        flag(false)
        if(nativeTool()) {
            editing.visibility=View.GONE;ink!!.visibility=View.VISIBLE
            setNativePen(if(buttonErasing)NativeTool.REGION else tool)
            // Stock SimplePen paint stays pure black: changing it slowed this tablet.
            renderForeground()
        } else {
            ink!!.visibility=View.INVISIBLE;editing.visibility=View.VISIBLE
            editing.tool=tool;editing.invalidate()
        }
        updateControls()

        } finally {diagnosticSpan.end()}
    }
    private fun setNativePen(selected:NativeTool) {
        input.setPen(selected,if(selected==NativeTool.PEN)penWidth*model.view.scale*density else 24*density)
    }
    /** Only tool transitions touch the vendor API; live ink stays stock. */
    private fun eraseButton(held:Boolean) {
        if(!ready || busy || closing || dialogOpen || !nativeTool() || overlayTouch || held==buttonErasing)return
        runCatching {
            buttonErasing=held
            setNativePen(if(held)NativeTool.REGION else tool)
            Log.i("NxNativeEditor","Stylus region erase: $held")
        }.onFailure{report(it)}
    }
    private fun stylusButtons(event:MotionEvent) {
        if(event.pointerCount==0)return
        val type=event.getToolType(0)
        if(type==MotionEvent.TOOL_TYPE_STYLUS || type==MotionEvent.TOOL_TYPE_ERASER) {
            eraseButton(type==MotionEvent.TOOL_TYPE_ERASER || event.buttonState and
                (MotionEvent.BUTTON_STYLUS_PRIMARY or MotionEvent.BUTTON_STYLUS_SECONDARY)!=0)
        }
    }
    fun dispatchTouchEvent(event:MotionEvent, dispatch: () -> Boolean):Boolean {
        if(event.actionMasked==MotionEvent.ACTION_DOWN && ::boardControls.isInitialized) {
            val rect=Rect()
            overlayTouch=listOf(boardControls,boardLabel).any{it.getGlobalVisibleRect(rect) && rect.contains(event.rawX.toInt(),event.rawY.toInt())}
            if(overlayTouch && ready)flag(false)
        }
        if(!overlayTouch) {
            stylusButtons(event)

        }
        if(event.actionMasked==MotionEvent.ACTION_DOWN || event.actionMasked==MotionEvent.ACTION_UP)diagnostics.event("touch.dispatch",mapOf("action" to event.actionMasked,"event_age_ms" to android.os.SystemClock.uptimeMillis()-event.eventTime,"overlay" to overlayTouch))
        val handled=dispatch()
        if(event.actionMasked==MotionEvent.ACTION_UP || event.actionMasked==MotionEvent.ACTION_CANCEL) {
            val wasOverlay=overlayTouch;overlayTouch=false
            if(wasOverlay && ready)runCatching{resumeInk()}.onFailure{report(it)}
        }
        return handled
    }
    fun dispatchGenericMotionEvent(event:MotionEvent, dispatch: () -> Boolean):Boolean {
        stylusButtons(event)
        return dispatch()
    }
    private fun updateControls() {
        val diagnosticSpan=diagnostics.begin("controls.update")
        try {
        if(!::engine.isInitialized)return
        diagnostics.event("canvas.state", mapOf("tool" to tool.name,"overview" to (overview!=null),"busy" to busy,"rendering" to rendering,"pending_imports" to pendingImports,"pending_saves" to session.saves.pendingSaves,"pen_pending" to penPending,"strokes" to model.strokes.size,"scale" to model.view.scale))
        buttons.forEach{(t,b)->b.isSelected=t==tool;b.setTypeface(null,if(t==tool)Typeface.BOLD else Typeface.NORMAL);b.alpha=if(t==tool)1f else .65f}
        // Include uncollected native strokes: an Undo tap captures them first.
        undoButton.isEnabled=engine.canUndo || nativeTool()
        redoButton.isEnabled=engine.canRedo
        if(model.boards!=null && body.width>0) {
            val board=model.boards!!.current(model.view,body.width/density,body.height/density)
            boardLabel.text=if(overview!=null)"Tap a board to open it" else "Board ${board.column}, ${board.row}"
        }
        status.text=when(tool){
            NativeTool.PEN->"Black pen · ${penWidth} pt · Hold the pen button and circle to erase"
            NativeTool.RUB->"Rub eraser · Rub over the parts you want to remove"
            NativeTool.REGION->"Region eraser · Draw a loop and lift to erase inside"
            NativeTool.SELECT->"Lasso / move · Circle ink, then drag inside the selection"
            NativeTool.HAND->"Hand · Drag to move; pinch to zoom the infinite canvas"
            NativeTool.MAGNIFY->"Magnify · Tap a spot to zoom in 2× around it; Previous view goes back"
        }

        } finally {diagnosticSpan.end()}
    }
    private fun chooseWidth()=perform("pen_width"){
        dialogOpen=true
        val widths=doubleArrayOf(1.5,3.0,6.0,10.0)
        AlertDialog.Builder(this).setTitle("Pen thickness").setSingleChoiceItems(widths.map{"$it pt"}.toTypedArray(),widths.indexOfFirst{it==penWidth}){dialog,index->
            penWidth=widths[index];runCatching{if(nativeTool())setNativePen(if(buttonErasing)NativeTool.REGION else tool);updateControls()}.onFailure{report(it)};dialog.dismiss()
        }.setNegativeButton("Cancel",null).create().apply{setOnDismissListener{dialogOpen=false;resumeInk()};show()}
    }
    private fun dismissOverview() { overview?.let{body.removeView(it)};overview=null }
    private fun navigateBoard(dx:Int,dy:Int,jump:Boolean) {
        diagnostics.event("navigation.request",mapOf("dx" to dx,"dy" to dy,"jump" to jump,"busy" to busy,"rendering" to rendering))
        diagnosticNavigationAt=System.nanoTime()
        if(!ready || closing)return
        navigation.add(dx,dy,jump);scheduleNavigation()
    }
    private fun scheduleNavigation() {
        if(navigation.isEmpty || navigationScheduled || busy || closing)return
        navigationScheduled=true
        // One display frame combines rapid presses, without losing their distance.
        body.postOnAnimation {
            navigationScheduled=false
            if(busy || closing)return@postOnAnimation
            perform("navigate") {
                dismissOverview();engine.dispatch(CanvasCommand.ClearSelection)
                engine.dispatch(CanvasCommand.SetView(navigation.apply(model.boards!!,model.view,body.width/density,body.height/density)))
                showTool()
            }
        }
    }
    private fun openBoard(board:InkBoard) {
        val diagnosticSpan=diagnostics.begin("overview.open_board")
        try {
        dismissOverview();engine.dispatch(CanvasCommand.ClearSelection)
        engine.dispatch(CanvasCommand.OpenBoard(board,body.width/density,body.height/density))
        showTool();checkpointSafely()

        } finally {diagnosticSpan.end()}
    }
    private fun showOverview() {
        val diagnosticSpan=diagnostics.begin("overview.open")
        try {
        if(::boardControls.isInitialized)boardControls.cancelPress()
        diagnostics.event("overview.request")
        perform("overview") {
            dismissOverview()
            overview=NativeBoardGrid(this,model,session.previews,diagnostics,components.overviewRenderer){board->perform("open_board"){openBoard(board)}}
            ink?.visibility=View.INVISIBLE;editing.visibility=View.GONE
            body.addView(overview,FrameLayout.LayoutParams(-1,-1))
            boardControls.bringToFront();boardLabel.bringToFront()
            updateControls()
        }

        } finally {diagnosticSpan.end()}
    }
    private fun checkpoint() { session.saves.checkpoint(engine.snapshot()) }
    private fun checkpointSafely(){runCatching{checkpoint()}.onFailure{report(it)}}
    private fun finishWriting() {
        if(::boardControls.isInitialized)boardControls.cancelPress()
        if(!::engine.isInitialized || !ready){activity.finish();return}
        perform("close") {
            checkpoint();closing=true;flag(false)
            session.saves.barrier { saved ->
                if(saved) {session.releaseLease();activity.setResult(Activity.RESULT_OK);activity.finish()}
                else {closing=false;saveStatus.text="Could not save. Please retry before leaving.";resumeInk()}
            }
        }
    }
    fun onBackPressed(){finishWriting()}
    fun onPause() {
        val diagnosticSpan=diagnostics.begin("activity.pause")
        try {
        if(::boardControls.isInitialized)boardControls.cancelPress()
        overlayTouch=false
        resumed=false
        if(::engine.isInitialized)runCatching {
            flag(false)
            if(::editing.isInitialized)editing.cancelGesture()
            if(ready)input.drain { drained -> if(drained && !destroyed)checkpointSafely() }
            checkpoint()
        }.onFailure{report(it)}

        } finally {diagnosticSpan.end()}
    }
    fun onResume(){resumed=true;if(ready)runCatching{resumeInk()}.onFailure{report(it)}}
    fun onDestroy() {
        destroyed=true
        idleStatus.close()
        if(::input.isInitialized)input.close()
        if(::body.isInitialized && ink != null)body.removeView(ink)
        if(::session.isInitialized)session.close()
    }
    private fun report(error:Throwable){val cause=error.cause?:error;Log.e("NxNativeEditor","Canvas operation failed",cause);status.text="Could not complete operation: ${cause.message}"}
}
