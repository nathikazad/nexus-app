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
import java.util.IdentityHashMap
import java.util.UUID
import kotlin.math.roundToInt

/** Entire editor is Android-native. The stock NoteView owns live pen/eraser
 * rendering. No Flutter surface, per-point bridge or drawing-thread callbacks.
 */
class NativeEditorActivity : Activity() {
    private lateinit var model:InkModel
    private lateinit var api:Class<*>
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
    private val seen=IdentityHashMap<Any,Boolean>()
    private val main=Handler(Looper.getMainLooper())
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
    private var foreground:Bitmap?=null
    private var buttonErasing=false

    override fun onCreate(state:Bundle?) {
        super.onCreate(state)
        density=resources.displayMetrics.density.toDouble()
        val page=LinearLayout(this).apply{orientation=LinearLayout.VERTICAL;setBackgroundColor(Color.WHITE)}
        val header=LinearLayout(this).apply{gravity=Gravity.CENTER_VERTICAL}
        val back=button("‹ Drawings"){finishWriting()}
        header.addView(back)
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
        undoButton=button("Undo"){perform{model.undo();showTool()}}
        redoButton=button("Redo"){perform{model.redo();showTool()}}
        tools.addView(undoButton);tools.addView(redoButton)
        page.addView(HorizontalScrollView(this).apply{isHorizontalScrollBarEnabled=false;addView(tools)})
        status=TextView(this).apply{textSize=12f;setPadding(dp(12),dp(2),dp(12),dp(6));text="Opening drawing…"}
        page.addView(status)
        body=FrameLayout(this)
        page.addView(body,LinearLayout.LayoutParams(-1,0,1f))
        setContentView(page)
        try {
            val input=NativeEditorFiles.scene(this)
            back.text=input["backLabel"] as? String?:"‹ Drawings"
            documentId=input["documentId"] as? String?:"prototype"
            title=input["title"] as? String?:"Drawing"
            name.text=title
            val pending=NativeEditorFiles.document(this)
            require(pending==null || pending["documentId"]==documentId){"Another drawing has unsaved changes"}
            model=InkCodec.model((pending?.get("drawing") as? Map<*,*>)?:input)
            api=Class.forName("com.xrz.NoteView")
            val widget=api.getConstructor(Context::class.java).newInstance(this) as View
            ink=widget
            flag(false)
            body.addView(widget,FrameLayout.LayoutParams(-1,-1))
            editing=NativeEditingView(this,model){checkpointSafely();updateControls()}.apply{visibility=View.GONE}
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
            val holder=api.getMethod("getHolder").invoke(widget) as SurfaceHolder
            holder.addCallback(object:SurfaceHolder.Callback {
                override fun surfaceCreated(holder:SurfaceHolder) {}
                override fun surfaceDestroyed(holder:SurfaceHolder) {}
                override fun surfaceChanged(holder:SurfaceHolder,format:Int,width:Int,height:Int) {
                    widget.post {
                        if(!ready && !closing && !isFinishing && holder.surface.isValid && widget.width>0 && widget.height>0) {
                            ready=true
                            runCatching{
                                val sw=body.width/density;val sh=body.height/density
                                val legacy=model.boards==null
                                model.boards=model.boards?:InkBoards(sw,sh)
                                if(legacy || kotlin.math.abs(model.view.scale-kotlin.math.min(sw/model.boards!!.width,sh/model.boards!!.height))>.001)
                                    model.view=model.boards!!.view(model.boards!!.current(model.view,sw,sh),sw,sh)
                                showTool();checkpoint()}.onFailure{ready=false;report(it)}
                        }
                    }
                }
            })
            Log.i("NxNativeEditor","Native canvas toolbar + stock black NoteView; document=$documentId")
        } catch(error:Throwable){report(error)}
    }
    private fun dp(value:Int)=(value*density).roundToInt()
    private fun button(label:String,action:()->Unit)=Button(this).apply{
        text=label;textSize=13f;isAllCaps=false;minWidth=dp(60);minimumWidth=dp(60)
        setPadding(dp(10),0,dp(10),0);setOnClickListener{if(!busy&&!closing)action()}
    }
    private fun nativeTool()=overview==null && tool in listOf(NativeTool.PEN,NativeTool.RUB,NativeTool.REGION)
    private fun flag(enabled:Boolean){ink?.let{api.getMethod("setInputEnabled",Boolean::class.javaPrimitiveType).invoke(it,enabled)}}
    private fun resumeInk(){flag(ready&&resumed&&!closing&&!busy&&!dialogOpen&&!overlayTouch&&nativeTool())}
    private fun finishPen(){ink?.let{api.getMethod("finishPen").invoke(it)}}

    private fun switchTool(next:NativeTool) {
        if(::boardControls.isInitialized)boardControls.cancelPress()
        if((next==tool && overview==null) || !ready || busy || closing)return
        val wasNative=nativeTool()
        perform {
            dismissOverview();tool=next;buttonErasing=false;model.selected.clear()
            if(wasNative && nativeTool()) {
                // Keep the vendor framebuffer and record list intact. A pen
                // change does not require a full-screen foreground refresh.
                setNativePen(tool)
            } else if(!wasNative && !nativeTool()) {
                editing.tool=tool;editing.invalidate()
            } else showTool()
        }
    }

    /** Runs only on toolbar/navigation actions, never for live pen samples. */
    private fun perform(action:()->Unit) {
        if(!::model.isInitialized || !ready || busy)return
        val needsCapture=nativeTool()
        val beforeStrokes=model.strokes;val beforeView=model.view;val beforePlaces=model.places
        busy=true
        try{if(needsCapture){flag(false);finishPen()}}catch(error:Throwable){busy=false;report(error);return}
        val run=Runnable {
            try {
                if(needsCapture)captureNew()
                editing.cancelGesture();action()
                if(model.strokes!==beforeStrokes || model.view!=beforeView || model.places!==beforePlaces)checkpoint()
                updateControls()
            }
            catch(error:Throwable){report(error)}
            finally{busy=false;runCatching{resumeInk()}.onFailure{report(it)}}
        }
        // Retain the drain window only when leaving live firmware ink.
        if(needsCapture)main.postDelayed(run,100) else run.run()
    }
    private fun captureNew() {
        val widget=ink?:return
        val rotation=api.getMethod("getAbsoluteRotation").invoke(widget) as Int
        val records=api.getMethod("getRecordList").invoke(widget) as List<*>
        for(record in records.filterNotNull()) {
            if(seen.containsKey(record))continue
            val cls=record.javaClass
            val type=cls.getField("type").getInt(record)
            if(type !in listOf(101,201,202)){seen[record]=true;continue}
            val raw=cls.getField("points").get(record) as? List<*>?:continue
            val max=(cls.getField("maxPressure").get(record) as Number).toDouble()
            val min=(cls.getField("minPressure").get(record) as Number).toDouble()
            val pc=raw.firstOrNull { it!=null }?.javaClass?:continue
            val getX=pc.getMethod("getX");val getY=pc.getMethod("getY");val getPressure=pc.getMethod("getPressure")
            val points=raw.filterNotNull().map{p->
                val x=(getX.invoke(p) as Number).toDouble()
                val y=(getY.invoke(p) as Number).toDouble()
                val pressure=(getPressure.invoke(p) as Number).toDouble()
                val local=InkCoordinates.panelToView(InkPoint(x,y),rotation,widget.width.toDouble(),widget.height.toDouble())
                val world=model.view.world(InkPoint(local.x/density,local.y/density))
                InkPoint(world.x,world.y,if(max>min)((pressure-min)/(max-min)).coerceIn(.1,1.0)else 1.0)
            }
            val width=cls.getField("strokeWidth").getInt(record)/density/model.view.scale
            if(points.isNotEmpty())when(type) {
                101->model.add(NativeStroke(UUID.randomUUID().toString(),points,cls.getField("color").getInt(record).toLong() and 0xffffffffL,width))
                201->model.erase(points,width/2)
                202->model.eraseRegion(points)
            }
            seen[record]=true
        }
    }
    private fun showTool() {
        if(!ready)return
        dismissOverview()
        flag(false)
        if(nativeTool()) {
            editing.visibility=View.GONE;ink!!.visibility=View.VISIBLE
            setNativePen(if(buttonErasing)NativeTool.REGION else tool)
            // Stock SimplePen paint stays pure black: changing it slowed this tablet.
            val rotation=api.getMethod("getAbsoluteRotation").invoke(ink) as Int
            val image=NativeInkPainter.panelBitmap(model,density,body.width,body.height,rotation)
            // The firmware scale mode copies panel pixels; despite accepting a
            // rotation argument, Painter.drawBitmap does not rotate its image.
            api.getMethod("setDrawGroundMode",Int::class.javaPrimitiveType).invoke(ink,0)
            api.getMethod("resetRecordList").invoke(ink);seen.clear()
            api.getMethod("setForeground",Bitmap::class.java).invoke(ink,image)
            foreground=image
            resumeInk()
        } else {
            ink!!.visibility=View.INVISIBLE;editing.visibility=View.VISIBLE
            editing.tool=tool;editing.invalidate()
        }
        updateControls()
    }
    private fun setNativePen(selected:NativeTool) {
        val penClass=Class.forName(when(selected){NativeTool.RUB->"com.xrz.Rubber";NativeTool.REGION->"com.xrz.RegionRubber";else->"com.xrz.SimplePen"})
        val pen=penClass.getConstructor().newInstance()
        val width=if(selected==NativeTool.PEN)penWidth*model.view.scale*density else 24*density
        penClass.getMethod("setStrokeWidth",Int::class.javaPrimitiveType).invoke(pen,width.roundToInt().coerceAtLeast(1))
        api.getMethod("setPen",Class.forName("com.xrz.BasePen")).invoke(ink,pen)
    }
    /** Only tool transitions touch the vendor API; live ink stays stock. */
    private fun eraseButton(held:Boolean) {
        if(!ready || busy || closing || dialogOpen || !nativeTool() || overlayTouch || held==buttonErasing)return
        runCatching {
            finishPen()
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
    override fun dispatchTouchEvent(event:MotionEvent):Boolean {
        if(event.actionMasked==MotionEvent.ACTION_DOWN && ::boardControls.isInitialized) {
            val rect=Rect()
            overlayTouch=listOf(boardControls,boardLabel).any{it.getGlobalVisibleRect(rect) && rect.contains(event.rawX.toInt(),event.rawY.toInt())}
            if(overlayTouch && ready)runCatching{flag(false);finishPen()}.onFailure{report(it)}
        }
        if(!overlayTouch)stylusButtons(event)
        val handled=super.dispatchTouchEvent(event)
        if(event.actionMasked==MotionEvent.ACTION_UP || event.actionMasked==MotionEvent.ACTION_CANCEL) {
            val wasOverlay=overlayTouch;overlayTouch=false
            if(wasOverlay && ready)runCatching{resumeInk()}.onFailure{report(it)}
        }
        return handled
    }
    override fun dispatchGenericMotionEvent(event:MotionEvent):Boolean {
        stylusButtons(event)
        return super.dispatchGenericMotionEvent(event)
    }
    private fun updateControls() {
        if(!::model.isInitialized)return
        buttons.forEach{(t,b)->b.isSelected=t==tool;b.setTypeface(null,if(t==tool)Typeface.BOLD else Typeface.NORMAL);b.alpha=if(t==tool)1f else .65f}
        // Include uncollected native strokes: an Undo tap captures them first.
        undoButton.isEnabled=model.canUndo || nativeTool()
        redoButton.isEnabled=model.canRedo
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
    }
    private fun chooseWidth()=perform{
        dialogOpen=true
        val widths=doubleArrayOf(1.5,3.0,6.0,10.0)
        AlertDialog.Builder(this).setTitle("Pen thickness").setSingleChoiceItems(widths.map{"$it pt"}.toTypedArray(),widths.indexOfFirst{it==penWidth}){dialog,index->
            penWidth=widths[index];runCatching{if(nativeTool())setNativePen(if(buttonErasing)NativeTool.REGION else tool);updateControls()}.onFailure{report(it)};dialog.dismiss()
        }.setNegativeButton("Cancel",null).create().apply{setOnDismissListener{dialogOpen=false;resumeInk()};show()}
    }
    private fun dismissOverview() { overview?.let{body.removeView(it)};overview=null }
    private fun navigateBoard(dx:Int,dy:Int,jump:Boolean) {
        if(!ready || busy || closing)return
        perform {
            dismissOverview();model.selected.clear()
            model.view=model.boards!!.navigate(model.view,dx,dy,jump,body.width/density,body.height/density)
            showTool()
        }
    }
    private fun openBoard(board:InkBoard) {
        dismissOverview();model.selected.clear()
        model.view=model.boards!!.view(board,body.width/density,body.height/density)
        showTool();checkpointSafely()
    }
    private fun showOverview() {
        if(::boardControls.isInitialized)boardControls.cancelPress()
        perform {
            dismissOverview()
            overview=NativeBoardGrid(this,model){board->perform{openBoard(board)}}
            ink?.visibility=View.INVISIBLE;editing.visibility=View.GONE
            body.addView(overview,FrameLayout.LayoutParams(-1,-1))
            boardControls.bringToFront();boardLabel.bringToFront()
            updateControls()
        }
    }
    private fun checkpoint() {
        NativeEditorFiles.write(this,"document-output",mapOf("documentId" to documentId,"title" to title,"drawing" to InkCodec.encode(model),"saveToken" to UUID.randomUUID().toString()))
    }
    private fun checkpointSafely(){runCatching{checkpoint()}.onFailure{report(it)}}
    private fun finishWriting() {
        if(::boardControls.isInitialized)boardControls.cancelPress()
        if(!::model.isInitialized || !ready){finish();return}
        perform{checkpoint();closing=true;setResult(RESULT_OK);finish()}
    }
    @Deprecated("Legacy Android back callback") override fun onBackPressed(){finishWriting()}
    override fun onPause() {
        if(::boardControls.isInitialized)boardControls.cancelPress()
        overlayTouch=false
        resumed=false
        if(::model.isInitialized)runCatching{flag(false);if(ready){finishPen();captureNew()};if(::editing.isInitialized)editing.cancelGesture();checkpoint()}.onFailure{report(it)}
        super.onPause()
    }
    override fun onResume(){super.onResume();resumed=true;if(ready)runCatching{resumeInk()}.onFailure{report(it)}}
    private fun report(error:Throwable){val cause=error.cause?:error;Log.e("NxNativeEditor","Canvas operation failed",cause);status.text="Could not complete operation: ${cause.message}"}
}
