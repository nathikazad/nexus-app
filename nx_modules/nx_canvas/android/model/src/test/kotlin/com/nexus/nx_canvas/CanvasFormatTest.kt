package com.nexus.nx_canvas

import org.junit.Assert.*
import org.junit.Test
import org.json.JSONObject
import org.json.JSONArray
import java.io.File

class CanvasFormatTest {
    private fun unpack(value: Any?): Any? = when(value) {
        is JSONObject -> value.keys().asSequence().associateWith { unpack(value.get(it)) }
        is JSONArray -> (0 until value.length()).map { unpack(value.get(it)) }
        else -> value
    }
    @Test fun sharedDartKotlinFixtureRoundTripsExactly() {
        val file=File("../../../nx_canvas_model/test/fixtures/drawing-v1.json")
        val input=JSONObject(file.readText())
        val encoded=JSONObject(InkCodec.encode(InkCodec.model(unpack(input) as Map<*,*>)))
        assertTrue(input.similar(encoded))
    }
    @Test fun unsupportedFormatIsRejectedWithoutCreatingEmptyInk() {
        try { InkCodec.model(mapOf("format" to "nx-canvas","version" to 999));fail() } catch(_:IllegalArgumentException) {}
    }
}
