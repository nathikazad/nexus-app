package com.nexus.nx_cards

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout

/** Owns one renderer and keeps selection/fallback out of the study UI. */
internal class InkPanelHost(context: Context, private val report: (String) -> Unit) : DrawingInkPanel {
    private val host = FrameLayout(context)
    private var panel: DrawingInkPanel? = null
    private var resumed = true
    private var closed = false
    private val candidates = inkBackends { name -> runCatching { Class.forName(name) }.isSuccess }.iterator()

    init { selectNext() }
    private fun selectNext(restored: List<InkStroke> = emptyList()) {
        if (closed) return
        panel?.dispose(); panel = null; host.removeAllViews()
        while (candidates.hasNext()) {
            val backend = candidates.next()
            try {
                val candidate: DrawingInkPanel = when (backend) {
                    InkBackend.NOTE_VIEW -> NativeInkPanel(host.context) { error -> report(error.message ?: "Drawing error") }
                    InkBackend.BIGME -> {
                        lateinit var bigme: BigmeInkPanel
                        bigme = BigmeInkPanel(host.context) { error ->
                            if (!closed && panel === bigme) {
                                val strokes = bigme.snapshot()
                                selectNext(strokes)
                                report("Using standard drawing; Bigme acceleration unavailable")
                                Log.w("NxCardsInk", "Bigme initialization/runtime fallback", error)
                            }
                        }
                        bigme
                    }
                    InkBackend.STANDARD -> StandardInkPanel(host.context, restored)
                }
                panel = candidate
                host.addView(candidate.getView(), FrameLayout.LayoutParams(-1, -1))
                candidate.setResumed(resumed)
                Log.i("NxCardsInk", "Renderer selected: $backend; ${android.os.Build.MANUFACTURER}/${android.os.Build.MODEL}")
                return
            } catch (error: Throwable) {
                Log.w("NxCardsInk", "Renderer $backend could not initialize", error)
                panel?.dispose(); panel = null; host.removeAllViews()
            }
        }
        report("Drawing could not start. Close this screen and try again.")
    }
    override fun getView(): View = host
    override fun clear(complete: () -> Unit) { panel?.clear(complete) ?: complete() }
    override fun undo() { panel?.undo() }
    override fun eraseButton(held: Boolean) { panel?.eraseButton(held) }
    override fun setResumed(value: Boolean) { resumed = value; panel?.setResumed(value) }
    override fun dispose() { closed = true; panel?.dispose(); panel = null }
}
