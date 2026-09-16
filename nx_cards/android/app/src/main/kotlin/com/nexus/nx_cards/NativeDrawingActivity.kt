package com.nexus.nx_cards

import android.app.Activity
import android.os.Bundle
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.*
import android.media.MediaPlayer
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.roundToInt

/** A separate opaque Android window: no Flutter surface participates in ink. */
class NativeDrawingActivity : Activity() {
    private lateinit var cards: List<Map<*, *>>
    private lateinit var progress: TextView
    private lateinit var prompt: TextView
    private lateinit var subtitle: TextView
    private lateinit var hint: TextView
    private lateinit var controls: LinearLayout
    private lateinit var end: Button
    private var native: NativeInkPanel? = null
    private var standard: StandardInkPanel? = null
    private var index = 0
    private var recall = false
    private var revealed = false
    private var visibleAnswer = true
    private var busy = false
    private var revealedAt = 0L
    private var player: MediaPlayer? = null
    private var audioFile: File? = null
    private var audioGeneration = 0
    private val density get() = resources.displayMetrics.density
    private fun dp(value: Int) = (value * density).roundToInt()
    private fun label(size: Float) = TextView(this).apply { textSize = size; setTextColor(Color.BLACK); gravity = Gravity.CENTER }
    private fun button(label: String, action: () -> Unit) = Button(this).apply {
        text = label; contentDescription = label; isAllCaps = false; textSize = 15f; setTextColor(Color.BLACK)
        minHeight = dp(48); setOnClickListener { if (!busy) action() }
    }
    private val card get() = cards[index]
    private fun value(key: String) = card[key] as? String ?: ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val input = NativeDrawingBridge.input
        if (input == null) { finish(); return }
        try {
            cards = (input["cards"] as List<*>).map { it as Map<*, *> }
            require(cards.isNotEmpty())
            recall = input["recall"] == true
            val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setBackgroundColor(Color.WHITE); setPadding(dp(16), dp(8), dp(16), dp(8)) }
            val header = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL }
            end = button(if (recall) "End" else "Back") { finish() }
            header.addView(end)
            header.addView(label(18f).apply { text = input["title"] as? String ?: "Drawing" }, LinearLayout.LayoutParams(0, -2, 1f))
            root.addView(header, LinearLayout.LayoutParams(-1, -2))
            progress = label(13f); root.addView(progress)
            val reference = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER; setPadding(dp(12), dp(12), dp(12), dp(12)) }
            prompt = label(32f); subtitle = label(16f)
            reference.addView(prompt, LinearLayout.LayoutParams(-1, -2))
            reference.addView(subtitle, LinearLayout.LayoutParams(-1, -2))
            val scroll = ScrollView(this).apply { isFillViewport = true; addView(reference) }
            val height = (resources.displayMetrics.heightPixels * .24).roundToInt().coerceIn(dp(110), dp(240))
            root.addView(scroll, LinearLayout.LayoutParams(-1, height))
            hint = label(12f); root.addView(hint, LinearLayout.LayoutParams(-1, dp(28)))
            val frame = FrameLayout(this).apply {
                background = GradientDrawable().apply { setColor(Color.WHITE); setStroke(dp(1), Color.LTGRAY); cornerRadius = dp(12).toFloat() }
            }
            root.addView(frame, LinearLayout.LayoutParams(-1, 0, 1f))
            if (runCatching { Class.forName("com.xrz.NoteView") }.isSuccess) {
                native = NativeInkPanel(this) { report(it.message ?: "Drawing error") }
                frame.addView(native!!.getView(), FrameLayout.LayoutParams(-1, -1))
            } else {
                standard = StandardInkPanel(this)
                frame.addView(standard, FrameLayout.LayoutParams(-1, -1))
            }
            controls = LinearLayout(this).apply { gravity = Gravity.CENTER; setPadding(0, dp(8), 0, 0) }
            root.addView(controls, LinearLayout.LayoutParams(-1, -2))
            setContentView(root)
            updateCard()
            Log.i("NxCardsNative", "Fully native ${if (recall) "recall" else "practice"} activity opened")
        } catch (e: Throwable) {
            setResult(RESULT_CANCELED, Intent().putExtra("error", e.toString())); finish()
        }
    }
    private fun updateCard() {
        progress.text = "${index + 1} of ${cards.size}"
        prompt.text = if (recall && revealed) value("answer") else value("prompt")
        prompt.visibility = if (!recall && !visibleAnswer) View.INVISIBLE else View.VISIBLE
        prompt.textSize = if (!recall && value("prompt").codePointCount(0, value("prompt").length) == 1) 64f else 32f
        subtitle.text = if (recall && !revealed) "" else value("subtitle")
        hint.text = if (recall) { if (revealed) "Compare your drawing with the answer" else "Write your answer" } else "Practice only"
        controls.removeAllViews()
        if (card["audio"] == true && (!recall || revealed)) controls.addView(button("Play") { play() })
        if (!recall) {
            controls.addView(button(if (visibleAnswer) "Hide" else "Show") { visibleAnswer = !visibleAnswer; updateCard() })
            controls.addView(button(if (index == cards.lastIndex) "Finish" else "Next") { advance() })
        } else if (!revealed) {
            controls.addView(button("Show answer") { revealed = true; revealedAt = System.currentTimeMillis(); updateCard() })
        } else {
            controls.addView(button("No") { rate(false) })
            controls.addView(button("Yes") { rate(true) })
        }
    }
    private fun setBusy(value: Boolean) {
        busy = value; end.isEnabled = !value
        for (i in 0 until controls.childCount) controls.getChildAt(i).isEnabled = !value
        native?.setResumed(!value)
    }
    private fun advance() {
        stopAudio()
        if (index == cards.lastIndex) { finish(); return }
        setBusy(true)
        val next = {
            if (!isFinishing && !isDestroyed) {
                index++; revealed = false; updateCard(); setBusy(false)
            }
        }
        native?.clear(next) ?: run { standard?.clear(); next() }
    }
    private fun rate(correct: Boolean) {
        if (!revealed) return
        setBusy(true); hint.text = "Saving…"
        val channel = NativeDrawingBridge.channel
        if (channel == null) { setBusy(false); report("Session ended. Close this screen and try again."); return }
        channel.invokeMethod("rate", mapOf("index" to index, "correct" to correct, "revealedAt" to revealedAt), object : MethodChannel.Result {
            override fun success(result: Any?) { if (!isFinishing && !isDestroyed) { setBusy(false); advance() } }
            override fun error(code: String, message: String?, details: Any?) { if (!isDestroyed) { setBusy(false); report(message ?: "Could not save review. Try again.") } }
            override fun notImplemented() = error("missing", "Could not save review", null)
        })
    }
    private fun play() {
        stopAudio()
        val generation = audioGeneration
        hint.text = "Loading audio…"
        NativeDrawingBridge.channel?.invokeMethod("audio", mapOf("index" to index), object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (generation != audioGeneration || isFinishing || isDestroyed) return
                try {
                    val bytes = result as ByteArray
                    val file = File.createTempFile("cards-audio-", ".audio", cacheDir); audioFile = file; file.writeBytes(bytes)
                    player = MediaPlayer().apply {
                        setDataSource(file.absolutePath)
                        setOnPreparedListener { if (generation == audioGeneration) { it.start(); hint.text = "Playing pronunciation" } }
                        setOnCompletionListener { stopAudio(); hint.text = if (recall) "Compare your drawing with the answer" else "Practice only" }
                        setOnErrorListener { _, _, _ -> stopAudio(); report("Could not play audio"); true }
                        prepareAsync()
                    }
                } catch (e: Throwable) { stopAudio(); report("Could not play audio") }
            }
            override fun error(code: String, message: String?, details: Any?) { if (generation == audioGeneration && !isDestroyed) report("Could not load audio. Try again.") }
            override fun notImplemented() = error("missing", null, null)
        })
    }
    private fun stopAudio() { audioGeneration++; player?.release(); player = null; audioFile?.delete(); audioFile = null }
    private fun report(message: String) { if (::hint.isInitialized) hint.text = message; Log.e("NxCardsNative", message) }
    override fun onResume() { super.onResume(); native?.setResumed(!busy) }
    override fun onPause() { native?.setResumed(false); stopAudio(); super.onPause() }
    override fun onWindowFocusChanged(hasFocus: Boolean) { super.onWindowFocusChanged(hasFocus); native?.setResumed(hasFocus && !busy) }
    @Deprecated("Legacy back")
    override fun onBackPressed() { if (!busy) super.onBackPressed() }
    override fun onDestroy() { native?.dispose(); stopAudio(); super.onDestroy() }
}
