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
    private lateinit var zoomLabel:TextView
    private val buttons=mutableMapOf<NativeTool,Button>()
    private lateinit var undoButton:Button
    private lateinit var redoButton:Button
    private lateinit var previousButton:Button
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
        toolButton(NativeTool.HAND,"Hand")
        toolButton(NativeTool.MAGNIFY,"⌕ Magnify")
        tools.addView(button("Pen width"){chooseWidth()})
        undoButton=button("Undo"){perform{model.undo();showTool()}}
        redoButton=button("Redo"){perform{model.redo();showTool()}}
        tools.addView(undoButton);tools.addView(redoButton)
        page.addView(HorizontalScrollView(this).apply{isHorizontalScrollBarEnabled=false;addView(tools)})
        status=TextView(this).apply{textSize=12f;setPadding(dp(12),dp(2),dp(12),dp(6));text="Opening drawing…"}
        page.addView(status)
        body=FrameLayout(this)
        page.addView(body,LinearLayout.LayoutParams(-1,0,1f))
        val navigation=LinearLayout(this).apply{gravity=Gravity.CENTER_VERTICAL}
        previousButton=button("Previous view"){perform{model.back();showTool()}}
        navigation.addView(previousButton)
        navigation.addView(button("Overview"){perform{model.overview(body.width/density,body.height/density);showTool()}})
        navigation.addView(button("Places"){choosePlace()})
        navigation.addView(Space(this),LinearLayout.LayoutParams(0,1,1f))
        navigation.addView(button("−"){perform{model.zoom(.8,center());showTool()}})
        zoomLabel=TextView(this).apply{gravity=Gravity.CENTER;minWidth=dp(48)}
        navigation.addView(zoomLabel)
        navigation.addView(button("+"){perform{model.zoom(1.25,center());showTool()}})
        page.addView(navigation)
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
                            runCatching{showTool();checkpoint()}.onFailure{ready=false;report(it)}
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
    private fun center()=InkPoint(body.width/density/2,body.height/density/2)
    private fun nativeTool()=tool in listOf(NativeTool.PEN,NativeTool.RUB,NativeTool.REGION)
    private fun flag(enabled:Boolean){ink?.let{api.getMethod("setInputEnabled",Boolean::class.javaPrimitiveType).invoke(it,enabled)}}
    private fun resumeInk(){flag(ready&&resumed&&!closing&&!busy&&!dialogOpen&&nativeTool())}
    private fun finishPen(){ink?.let{api.getMethod("finishPen").invoke(it)}}

    private fun switchTool(next:NativeTool) {
        if(next==tool || !ready || busy || closing)return
        val wasNative=nativeTool()
        perform {
            tool=next;buttonErasing=false;model.selected.clear()
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
        if(!ready || busy || closing || dialogOpen || !nativeTool() || held==buttonErasing)return
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
        stylusButtons(event)
        return super.dispatchTouchEvent(event)
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
        previousButton.isEnabled=model.canGoBack
        zoomLabel.text="${(model.view.scale*100).roundToInt()}%"
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
    private fun choosePlace()=perform{
        dialogOpen=true
        val labels=(model.places.map{it.name}+"+ Save this view").toTypedArray()
        AlertDialog.Builder(this).setTitle("Places").setItems(labels){_,index->
            if(index<model.places.size){model.rememberView();model.view=model.places[index].view;showTool();checkpointSafely()}
            else main.post{savePlace()}
        }.setNegativeButton("Close",null).create().apply{setOnDismissListener{dialogOpen=false;resumeInk()};show()}
    }
    private fun savePlace() {
        flag(false);dialogOpen=true
        val input=EditText(this).apply{hint="Opening, next idea…";setSingleLine()}
        AlertDialog.Builder(this).setTitle("Name this view").setView(input).setPositiveButton("Save"){_,_->
            val name=input.text.toString().trim();if(name.isNotEmpty()){model.places=model.places+InkPlace(name,model.view);checkpointSafely()}
        }.setNegativeButton("Cancel",null).create().apply{setOnDismissListener{dialogOpen=false;resumeInk()};show()}
    }
    private fun checkpoint() {
        NativeEditorFiles.write(this,"document-output",mapOf("documentId" to documentId,"title" to title,"drawing" to InkCodec.encode(model),"saveToken" to UUID.randomUUID().toString()))
    }
    private fun checkpointSafely(){runCatching{checkpoint()}.onFailure{report(it)}}
    private fun finishWriting() {
        if(!::model.isInitialized || !ready){finish();return}
        perform{checkpoint();closing=true;setResult(RESULT_OK);finish()}
    }
    @Deprecated("Legacy Android back callback") override fun onBackPressed(){finishWriting()}
    override fun onPause() {
        resumed=false
        if(::model.isInitialized)runCatching{flag(false);if(ready){finishPen();captureNew()};if(::editing.isInitialized)editing.cancelGesture();checkpoint()}.onFailure{report(it)}
        super.onPause()
    }
    override fun onResume(){super.onResume();resumed=true;if(ready)runCatching{resumeInk()}.onFailure{report(it)}}
    private fun report(error:Throwable){val cause=error.cause?:error;Log.e("NxNativeEditor","Canvas operation failed",cause);status.text="Could not complete operation: ${cause.message}"}
}
