package com.nexus.nx_cards

import org.junit.Assert.*
import org.junit.Test

class InkBackendTest {
    @Test fun noteViewHasPriorityEvenWhenBothApisExist() {
        assertEquals(listOf(InkBackend.NOTE_VIEW, InkBackend.BIGME, InkBackend.STANDARD), inkBackends { true })
    }
    @Test fun bigmeDoesNotRequireNoteViewOrBrandMatch() {
        assertEquals(listOf(InkBackend.BIGME, InkBackend.STANDARD), inkBackends { it != "com.xrz.NoteView" })
    }
    @Test fun incompleteFirmwareUsesStandardFallback() {
        assertEquals(listOf(InkBackend.STANDARD), inkBackends { it == "com.xrz.HandwrittenClient" })
        assertEquals(listOf(InkBackend.STANDARD), inkBackends { false })
    }
    @Test fun clearingRejectsLateMoveAndUndoKeepsPreviousStroke() {
        val history = InkStrokeHistory()
        history.begin(.1f, .2f, false); history.move(.2f, .3f); history.end()
        history.begin(.4f, .5f, true); history.move(.5f, .6f)
        history.undo(); history.move(.8f, .9f)
        assertEquals(1, history.strokes.size)
        assertEquals(2, history.strokes.single().points.size)
        history.clear(); history.move(.9f, .9f)
        assertTrue(history.strokes.isEmpty()); assertFalse(history.active)
    }
    @Test fun normalizedSnapshotSurvivesResizeAndIsIndependent() {
        val history = InkStrokeHistory()
        history.begin(.25f, .5f, false); history.move(.75f, .8f); history.end()
        val snapshot = history.snapshot(); history.clear()
        assertEquals(.25f, snapshot.single().points.first().x)
        assertEquals(.5f, snapshot.single().points.first().y)
        assertFalse(snapshot.single().erasing)
        assertEquals(2, snapshot.single().points.size)
    }
}
