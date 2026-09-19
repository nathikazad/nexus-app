package com.nexus.nx_canvas

data class CanvasPenTool(val tool: NativeTool, val width: Double)

/** Control plane only. Raw pen events never enter this interface. */
interface CanvasFirmwarePort {
    /** Stop new contacts while allowing the current stroke to reach its real up. */
    fun admitNewStrokes(enabled: Boolean)
    fun isDrained(): Boolean
    fun changeTool(tool: CanvasPenTool)
}

/** Serializes destructive firmware mutations at completed stroke boundaries. */
class CanvasInputLifecycle(
    private val port: CanvasFirmwarePort,
    private val scheduler: CanvasScheduler,
    private val diagnostic: DiagnosticSink = NoCanvasDiagnostics,
    private val fault: (String) -> Unit,
) {
    private sealed class Command {
        data class Tool(val value: CanvasPenTool) : Command()
        class Drain(val done: (Boolean) -> Unit) : Command() {
            private var replied = false
            fun reply(ok: Boolean) { if (!replied) { replied = true; done(ok) } }
        }
    }
    private val queue = java.util.ArrayDeque<Command>()
    private var waiting: Command? = null
    private var enabled = false
    private var pumping = false
    private var closed = false
    private var timeout: Cancellation? = null
    private var current: CanvasPenTool? = null

    fun enable(value: Boolean) {
        enabled = value && !closed
        pump()
    }
    fun tool(value: CanvasPenTool) {
        if (closed) return
        // With no intervening stroke admitted, only the latest tool intent matters.
        if (queue.peekLast() is Command.Tool) queue.removeLast()
        queue.add(Command.Tool(value))
        pump()
    }
    fun drain(done: (Boolean) -> Unit) {
        if (closed) { done(false); return }
        enabled = false
        queue.add(Command.Drain(done))
        pump()
    }
    fun progressed() = pump()

    private fun pump() {
        if (pumping || closed) return
        pumping = true
        try {
            while (true) {
                val barrier = waiting
                if (barrier != null) {
                    if (!port.isDrained()) return
                    timeout?.cancel(); timeout = null
                    if (barrier is Command.Tool) {
                        try { port.changeTool(barrier.value) }
                        catch (error: Throwable) {
                            enabled = false
                            diagnostic.event("input.tool_failed", mapOf("error_type" to error.javaClass.name))
                            fault("The tool could not be changed. Tap Retry input.")
                            return
                        }
                        current = barrier.value
                    }
                    waiting = null
                    diagnostic.event("input.transition_drained")
                    if (barrier is Command.Drain) barrier.reply(true)
                }
                val command = queue.pollFirst() ?: return
                if (command is Command.Tool && command.value == current) continue
                port.admitNewStrokes(false)
                waiting = command
                diagnostic.event("input.transition_wait", mapOf("kind" to if (command is Command.Tool) "tool" else "drain"))
                timeout = scheduler.after(2000) {
                    if (waiting === command) {
                        enabled = false
                        fault("Input has not finished. Lift the pen and tap Retry input.")
                        diagnostic.event("input.transition_timeout")
                        if (command is Command.Drain) command.reply(false)
                    }
                }
            }
        } finally {
            pumping = false
            port.admitNewStrokes(enabled && waiting == null && queue.isEmpty() && !closed)
        }
    }
    fun close() {
        closed = true; enabled = false
        port.admitNewStrokes(false)
        timeout?.cancel(); timeout = null
        (waiting as? Command.Drain)?.reply(false)
        queue.filterIsInstance<Command.Drain>().forEach { it.reply(false) }
        queue.clear(); waiting = null
    }
}
