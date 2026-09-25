package com.nexus.nx_canvas

import android.content.Context
import android.graphics.Canvas
import android.graphics.Rect
import android.view.View

/** Same cooked-coordinate XRZ service used by NX Cards on Bigme firmware. */
internal class BigmeCanvasFirmware(context: Context) {
        private val type = Class.forName("com.xrz.HandwrittenClient")
        val listenerType = Class.forName("com.xrz.HandwrittenClient\$InputListener")
        private val instance = type.getConstructor(Context::class.java).newInstance(context)
        private val getCanvas = type.getMethod("getCanvas")
        private val invalidate = type.getMethod("inValidate", Rect::class.java, Int::class.javaPrimitiveType)
        private val input = type.getMethod("setInputEnabled", Boolean::class.javaPrimitiveType)
        private val overlay = type.getMethod("setOverlayEnabled", Boolean::class.javaPrimitiveType)
        fun bind(view: View, listener: Any) {
            type.getMethod("bindView", View::class.java).invoke(instance, view)
            type.getMethod("registerInputListener", listenerType).invoke(instance, listener)
            // Default cooked coordinates, explicitly selected when supported.
            runCatching { type.getMethod("setUseRawInputEvent", Boolean::class.javaPrimitiveType).invoke(instance, false) }
        }
        fun connect(w: Int, h: Int) = type.getMethod("connect", Int::class.javaPrimitiveType,
            Int::class.javaPrimitiveType).invoke(instance, w, h) == true
        fun updateLayout() {
            type.getMethod("updateLayout").invoke(instance)
            type.getMethod("updateRotation").invoke(instance)
            overlay.invoke(instance, true)
            runCatching { type.getMethod("setBlendEnabled", Boolean::class.javaPrimitiveType).invoke(instance, true) }
        }
        fun canvas() = getCanvas.invoke(instance) as? Canvas
        fun layout() = listOf("getViewLayout", "getPhyViewLayout", "getPhyRotation").joinToString { name ->
            "$name=${runCatching { type.getMethod(name).invoke(instance) }.getOrNull()}"
        }
        fun refresh(rect: Rect, mode: Int) { invalidate.invoke(instance, rect, mode) }
        fun enable(value: Boolean) { input.invoke(instance, value) }
        fun close() {
            runCatching { input.invoke(instance, false) }
            runCatching { overlay.invoke(instance, false) }
            runCatching { type.getMethod("disconnect").invoke(instance) }
            runCatching { type.getMethod("unBindView").invoke(instance) }
        }
    }
