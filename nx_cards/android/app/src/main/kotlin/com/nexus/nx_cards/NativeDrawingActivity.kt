package com.nexus.nx_cards

import android.app.Activity
import android.os.Bundle
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.*
import android.media.MediaPlayer
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.lang.ref.WeakReference
import kotlin.math.roundToInt

/** A separate opaque Android window: no Flutter surface participates in ink. */
class NativeDrawingActivity : Activity() {
    private lateinit var cards: MutableList<Map<*, *>>
    private val cardWaiters = mutableMapOf<Int, MutableList<(String?) -> Unit>>()
    private var loadingCard = false
    private lateinit var progress: TextView
    private lateinit var prompt: TextView
    private lateinit var subtitle: TextView
    private lateinit var hint: TextView
    private lateinit var controls: LinearLayout
    private lateinit var end: Button
    private var examplesList: LinearLayout? = null
    private var examplesScroll: ScrollView? = null
    private var examplesCardIndex = -1
    private var contextHeadings: View? = null
    private var contextColumns: View? = null
    private var characterColumn: LinearLayout? = null
    private var characterHeading: TextView? = null
    private var charactersList: LinearLayout? = null
    private var charactersScroll: ScrollView? = null
    private var ink: DrawingInkPanel? = null
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
        val startup = android.os.SystemClock.elapsedRealtime()
        fun mark(stage: String) = Log.i("NxCardsStartup", "stage=$stage native_ms=${android.os.SystemClock.elapsedRealtime() - startup} epoch_ms=${System.currentTimeMillis()}")
        mark("activity_create")
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        val input = NativeDrawingBridge.input
        if (input == null) { finish(); return }
        try {
            cards = (input["cards"] as List<*>).map { it as Map<*, *> }.toMutableList()
            NativeDrawingBridge.activity = WeakReference(this)
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
            val frame = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                background = GradientDrawable().apply { setColor(Color.WHITE); setStroke(dp(1), Color.LTGRAY); cornerRadius = dp(12).toFloat() }
            }
            root.addView(frame, LinearLayout.LayoutParams(-1, 0, 1f))
            controls = LinearLayout(this).apply { gravity = Gravity.END }
            frame.addView(controls, LinearLayout.LayoutParams(-1, dp(48)))
            mark("before_ink_init")
            ink = InkPanelHost(this, ::report)
            mark("ink_initialized")
            frame.addView(ink!!.getView(), LinearLayout.LayoutParams(-1, 0, 1f))
            // Tablet context is shared by practice and revealed recall.
            if (resources.configuration.smallestScreenWidthDp >= 600) {
                val headings = LinearLayout(this)
                contextHeadings = headings
                headings.addView(label(13f).apply {
                    text = "USED IN · EXAMPLES"
                    gravity = Gravity.START or Gravity.CENTER_VERTICAL
                }, LinearLayout.LayoutParams(0, dp(36), 7f))
                characterHeading = label(13f).apply {
                    text = "CHARACTERS"
                    gravity = Gravity.START or Gravity.CENTER_VERTICAL
                }
                headings.addView(characterHeading, LinearLayout.LayoutParams(0, dp(36), 2f).apply { leftMargin = dp(16) })
                root.addView(headings)
                val columns = LinearLayout(this)
                contextColumns = columns
                examplesList = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
                examplesScroll = ScrollView(this).apply {
                    isFillViewport = true
                    addView(examplesList)
                }
                columns.addView(examplesScroll, LinearLayout.LayoutParams(0, -1, 7f))
                charactersList = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
                charactersScroll = ScrollView(this).apply {
                    isFillViewport = true
                    addView(charactersList)
                }
                characterColumn = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    addView(charactersScroll, LinearLayout.LayoutParams(-1, -1))
                }
                columns.addView(characterColumn, LinearLayout.LayoutParams(0, -1, 2f).apply { leftMargin = dp(16) })
                root.addView(columns, LinearLayout.LayoutParams(-1, 0, 1.2f))
            }
            setContentView(root)
            mark("layout_built")
            updateCard()
            mark("first_card_bound")
            root.post { mark("first_ui_post"); prefetch() }
            Log.i("NxCardsNative", "Fully native ${if (recall) "recall" else "practice"} activity opened")
        } catch (e: Throwable) {
            setResult(RESULT_CANCELED, Intent().putExtra("error", e.toString())); finish()
        }
    }
    private fun updateCard() {
        progress.text = "${index + 1} of ${cards.size}"
        prompt.text = if (recall && revealed) value("answer") else value("prompt")
        prompt.visibility = if (!recall && !visibleAnswer) View.INVISIBLE else View.VISIBLE
        prompt.textSize = if (!recall && card["multiCharacter"] == false) 64f else 32f
        subtitle.text = if (recall && !revealed) "" else value("subtitle")
        hint.text = if (recall) { if (revealed) "Compare your drawing with the answer" else "Write your answer" } else "Practice only"
        val showContext = !recall || revealed
        // Reserve the context area before reveal. GONE resizes NoteView when
        // the answer appears; the firmware can discard pen records during that
        // resize before our layout listener captures them. INVISIBLE keeps the
        // ink surface and existing strokes in place without exposing answers.
        contextHeadings?.visibility = if (showContext) View.VISIBLE else View.INVISIBLE
        contextColumns?.visibility = if (showContext) View.VISIBLE else View.INVISIBLE
        if (showContext) updateExamples()
        controls.removeAllViews()
        control("Refresh screen", "refresh") { refreshScreen() }
        if (!recall) control("Previous", "previous", enabled = index > 0) { moveTo(index - 1) }
        control("Undo", "undo") { ink?.undo() }
        control("Erase", "erase") { ink?.clear {} }
        if (card["audio"] == true && (!recall || revealed)) control("Play", "play") { play() }
        if (!recall) {
            control(if (visibleAnswer) "Hide" else "Show", if (visibleAnswer) "hide" else "show") { visibleAnswer = !visibleAnswer; updateCard() }
            control(if (index == cards.lastIndex) "Finish" else "Next", if (index == cards.lastIndex) "yes" else "next") { advance() }
        } else if (!revealed) {
            control("Show answer", "show") { revealed = true; revealedAt = System.currentTimeMillis(); updateCard() }
        } else {
            control("No", "no") { rate(false) }
            control("Yes", "yes") { rate(true) }
        }
    }
    private fun refreshDisplay(manual: Boolean = false, complete: () -> Unit) {
        if (isFinishing || isDestroyed) return
        val root = window.decorView
        root.invalidate()
        // Post after Android has rendered the updated card before refreshing
        // the panel; do not change card state, reveal state, or review history.
        root.postOnAnimation {
            root.post {
                if (!isFinishing && !isDestroyed) {
                    val refreshed = runCatching {
                        if (android.os.Build.VERSION.SDK_INT >= 28) {
                            org.lsposed.hiddenapibypass.HiddenApiBypass.addHiddenApiExemptions("Lxrz/framework/manager/XrzEinkManager;")
                        }
                        val type = Class.forName("xrz.framework.manager.XrzEinkManager")
                        val manager = type.getConstructor().newInstance()
                        // GC16, identical to this firmware's Activity refresh receiver.
                        type.getMethod("forceGlobalRefresh", Int::class.javaPrimitiveType).invoke(manager, 4)
                    }
                    complete()
                    if (refreshed.isSuccess) Log.i("NxCardsInk", "Full screen GC16 refresh requested; manual=$manual index=$index")
                    else {
                        Log.w("NxCardsInk", "Firmware full refresh unavailable", refreshed.exceptionOrNull())
                        if (manual) report("Redrawn; full-screen refresh unavailable on this device")
                    }
                }
            }
        }
    }
    private fun refreshScreen() {
        setBusy(true)
        val redraw = { refreshDisplay(manual = true) { setBusy(false) } }
        ink?.refresh(redraw) ?: redraw()
    }
    private fun updateExamples() {
        val list = examplesList ?: return
        if (examplesCardIndex == index) return
        examplesCardIndex = index
        list.removeAllViews()
        examplesScroll?.scrollTo(0, 0)
        updateCharacters()
        val examples = card["examples"] as? List<*> ?: emptyList<Any>()
        if (examples.isEmpty()) {
            list.addView(label(16f).apply {
                text = "No linked examples for this card yet."
                gravity = Gravity.START
                setPadding(dp(12), dp(12), dp(12), dp(12))
            })
        }
        val derived = card["derivedExamples"] as? List<*> ?: emptyList<Any>()
        (examples + derived).forEachIndexed { exampleIndex, item ->
            val isDerived = exampleIndex >= examples.size
            if (isDerived && exampleIndex == examples.size) list.addView(label(14f).apply {
                text = "DERIVED EXAMPLES"
                gravity = Gravity.START
                setPadding(dp(12), dp(20), dp(12), dp(8))
            })
            val example = item as? Map<*, *> ?: return@forEachIndexed
            val row = LinearLayout(this).apply {
                gravity = Gravity.TOP
                setPadding(dp(12), dp(12), dp(4), dp(12))
            }
            val textColumn = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
            if (isDerived) textColumn.addView(label(14f).apply {
                text = "Via ${example["via"]}"
                gravity = Gravity.START
                setPadding(0, 0, 0, dp(5))
            })
            listOf("text" to 24f, "transliteration" to 16f, "translation" to 16f).forEach { (key, size) ->
                val value = example[key] as? String ?: ""
                if (value.isNotBlank()) textColumn.addView(label(size).apply {
                    text = value
                    gravity = Gravity.START
                    setPadding(0, 0, 0, dp(5))
                    if (key == "text" && !recall && example["cardId"] is Number) {
                        contentDescription = "Open example card: $value"
                        isFocusable = true
                        setOnClickListener { if (!busy && !recall) openExample((example["cardId"] as Number).toInt()) }
                        var pressedOnText = false
                        fun hitsText(event: MotionEvent): Boolean {
                            val lines = layout ?: return false
                            val x = event.x - totalPaddingLeft + scrollX
                            val y = event.y - totalPaddingTop + scrollY
                            if (y < 0 || y >= lines.height) return false
                            val line = lines.getLineForVertical(y.toInt())
                            return x >= lines.getLineLeft(line) && x <= lines.getLineRight(line)
                        }
                        setOnTouchListener { _, event ->
                            when (event.actionMasked) {
                                MotionEvent.ACTION_DOWN -> pressedOnText = hitsText(event)
                                MotionEvent.ACTION_MOVE -> if (!hitsText(event)) pressedOnText = false
                                MotionEvent.ACTION_UP -> {
                                    if (pressedOnText && hitsText(event)) performClick()
                                    pressedOnText = false
                                }
                                MotionEvent.ACTION_CANCEL -> pressedOnText = false
                            }
                            true
                        }
                    }
                }, LinearLayout.LayoutParams(-2, -2))
            }
            // Keep a non-clickable gap between card navigation and audio.
            row.addView(textColumn, LinearLayout.LayoutParams(0, -2, 1f).apply { rightMargin = dp(16) })
            if (example["audio"] == true) row.addView(ImageButton(this).apply {
                contentDescription = "Play example: ${example["text"]}"
                tooltipText = "Play example"
                setImageDrawable(DrawingIcon("play"))
                setPadding(dp(12), dp(12), dp(12), dp(12))
                setBackgroundColor(Color.TRANSPARENT)
                setOnClickListener { if (!busy) {
                    if (isDerived) play(derivedIndex = exampleIndex - examples.size) else play(exampleIndex)
                } }
            }, LinearLayout.LayoutParams(dp(48), dp(48)))
            list.addView(row, LinearLayout.LayoutParams(-1, -2))
            list.addView(View(this).apply { setBackgroundColor(Color.LTGRAY) }, LinearLayout.LayoutParams(-1, dp(1)))
        }
    }
    private fun updateCharacters() {
        val list = charactersList ?: return
        val show = card["multiCharacter"] == true
        characterColumn?.visibility = if (show) View.VISIBLE else View.GONE
        characterHeading?.visibility = if (show) View.VISIBLE else View.GONE
        list.removeAllViews()
        charactersScroll?.scrollTo(0, 0)
        if (!show) return
        val characters = card["characters"] as? List<*> ?: emptyList<Any>()
        if (characters.isEmpty()) list.addView(label(15f).apply {
            text = "No linked characters yet."
            gravity = Gravity.START
            setPadding(0, dp(12), 0, dp(12))
        })
        characters.forEachIndexed { characterIndex, item ->
            val part = item as? Map<*, *> ?: return@forEachIndexed
            val entry = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(0, dp(12), 0, dp(12))
            }
            val top = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL }
            top.addView(label(28f).apply {
                text = part["text"] as? String ?: ""
                gravity = Gravity.START
            }, LinearLayout.LayoutParams(0, -2, 1f))
            if (part["audio"] == true) top.addView(ImageButton(this).apply {
                contentDescription = "Play character: ${part["text"]}"
                tooltipText = "Play character"
                setImageDrawable(DrawingIcon("play"))
                setPadding(dp(12), dp(12), dp(12), dp(12))
                setBackgroundColor(Color.TRANSPARENT)
                setOnClickListener { if (!busy) play(characterIndex = characterIndex) }
            }, LinearLayout.LayoutParams(dp(48), dp(48)))
            entry.addView(top)
            listOf("transliteration", "translation").forEach { key ->
                val value = part[key] as? String ?: ""
                if (value.isNotBlank()) entry.addView(label(16f).apply {
                    text = value
                    gravity = Gravity.START
                    setPadding(0, dp(5), 0, 0)
                })
            }
            list.addView(entry, LinearLayout.LayoutParams(-1, -2))
            list.addView(View(this).apply { setBackgroundColor(Color.LTGRAY) }, LinearLayout.LayoutParams(-1, dp(1)))
        }
    }
    private fun control(label: String, icon: String, enabled: Boolean = true, action: () -> Unit) {
        controls.addView(ImageButton(this).apply {
            tag = enabled
            isEnabled = enabled && !busy
            alpha = if (enabled) 1f else .35f
            contentDescription = label
            tooltipText = label
            setImageDrawable(DrawingIcon(icon))
            setPadding(dp(12), dp(12), dp(12), dp(12))
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener { if (!busy) action() }
        }, LinearLayout.LayoutParams(dp(48), dp(48)))
    }
    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        ink?.eraseButton(StylusInput.erasing(event))
        val result = super.dispatchTouchEvent(event)
        if (event.actionMasked == MotionEvent.ACTION_CANCEL) ink?.eraseButton(false)
        return result
    }
    override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
        ink?.eraseButton(StylusInput.erasing(event))
        return super.dispatchGenericMotionEvent(event)
    }
    private fun setBusy(value: Boolean) {
        busy = value; end.isEnabled = !value
        for (i in 0 until controls.childCount) {
            val control = controls.getChildAt(i)
            control.isEnabled = !value && control.tag != false
        }
        ink?.setResumed(!value)
    }
    private fun openExample(cardId: Int) {
        stopAudio()
        setBusy(true)
        NativeDrawingBridge.channel?.invokeMethod("exampleCard", mapOf("index" to index, "cardId" to cardId), object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (isFinishing || isDestroyed) return
                // Flutter has popped the details route and brought this same
                // drawing activity forward; keep the card and ink untouched.
                setBusy(false)
            }
            override fun error(code: String, message: String?, details: Any?) { setBusy(false); report(message ?: "Could not open example card") }
            override fun notImplemented() { setBusy(false); report("Example navigation unavailable") }
        })
    }
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() { if (!busy || loadingCard) super.onBackPressed() }

    private fun advance() {
        if (index == cards.lastIndex) { stopAudio(); finish(); return }
        moveTo(index + 1)
    }
    private fun requestCard(target: Int, done: (String?) -> Unit) {
        if (cards[target]["pending"] != true) { done(null); return }
        val existing = cardWaiters[target]
        if (existing != null) { existing.add(done); return }
        cardWaiters[target] = mutableListOf(done)
        fun complete(error: String?) {
            val callbacks = cardWaiters.remove(target) ?: return
            if (!isFinishing && !isDestroyed) callbacks.forEach { it(error) }
        }
        val channel = NativeDrawingBridge.channel
        if (channel == null) { complete("Session ended"); return }
        channel.invokeMethod("prepare", mapOf("index" to target), object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (result !is Map<*, *>) { complete("Could not load card. Try again."); return }
                cards[target] = result
                complete(null)
            }
            override fun error(code: String, message: String?, details: Any?) = complete("Could not load card. Try Next again.")
            override fun notImplemented() = complete("Card loading unavailable")
        })
    }
    private fun prefetch() {
        for (target in (index + 1)..minOf(index + 2, cards.lastIndex)) {
            requestCard(target) { /* Demand navigation retries failed background reads. */ }
        }
    }
    private fun moveTo(targetIndex: Int) {
        if (targetIndex !in cards.indices || busy) return
        stopAudio()
        setBusy(true)
        loadingCard = true
        end.isEnabled = true
        end.setOnClickListener { if (loadingCard || !busy) finish() }
        hint.text = "Loading card…"
        requestCard(targetIndex) { error ->
            loadingCard = false
            if (error != null) { setBusy(false); report(error); return@requestCard }
            val next = {
                if (!isFinishing && !isDestroyed) {
                    index = targetIndex; revealed = false; updateCard()
                    refreshDisplay { setBusy(false); prefetch() }
                }
            }
            ink?.clear(next) ?: next()
        }
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
    private fun play(exampleIndex: Int? = null, characterIndex: Int? = null, derivedIndex: Int? = null) {
        stopAudio()
        val generation = audioGeneration
        hint.text = "Loading audio…"
        NativeDrawingBridge.channel?.invokeMethod("audio", mapOf("index" to index, "exampleIndex" to exampleIndex, "characterIndex" to characterIndex, "derivedIndex" to derivedIndex), object : MethodChannel.Result {
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
    override fun onResume() { super.onResume(); ink?.setResumed(!busy) }
    override fun onPause() { ink?.setResumed(false); stopAudio(); super.onPause() }
    override fun onWindowFocusChanged(hasFocus: Boolean) { super.onWindowFocusChanged(hasFocus); ink?.setResumed(hasFocus && !busy) }
    override fun onDestroy() { if (NativeDrawingBridge.activity?.get() === this) NativeDrawingBridge.activity = null; ink?.dispose(); stopAudio(); super.onDestroy() }
}
