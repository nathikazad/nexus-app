package com.nexus.nx_canvas

/** Keep transition milestones, failures and slow spans; omit steady-ink chatter. */
object CanvasDiagnosticPolicy {
    fun event(name: String) = name == "diagnostics.start" || name == "dart" ||
        name.startsWith("transition.") || name == "overlay.repair" ||
        name == "stage.error" || name == "input.fault" ||
        name.endsWith("timeout") || name.endsWith("failed") ||
        name == "main.stall" || name == "main.recovered"
    fun span(name: String, milliseconds: Double) = milliseconds >= 50 ||
        name.startsWith("open.") || name.startsWith("bridge.") ||
        name.startsWith("close.") || name == "action.close" ||
        name == "render.total" || name == "firmware.setForeground"
}
