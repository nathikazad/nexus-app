# Drawing screen refresh

The connected k65v1_64_bsp tablet firmware was inspected directly on 2026-09-23:

- `/system/framework/framework.jar`, classes4.dex: public `xrz.framework.manager.XrzEinkManager.forceGlobalRefresh(int)` delegates to `nativeForceGlobalRefresh(int)`.
- `EinkRefreshMode.EINK_GC16_MODE` is 4.
- The firmware's own `android.app.Activity$2.onReceive` constructs this manager and calls `forceGlobalRefresh(4)`.

The toolbar uses that same call after redrawing the current ink, without removing strokes, advancing the queue, revealing recall answers, or recording a rating. It is first in the toolbar (left of Previous in study) and present in writing recall. After card navigation, the previous ink is cleared, the new card is bound, then the global refresh is requested after the UI traversal. Manual and automatic refresh requests are logged under `NxCardsInk`.

The vendor API is discovered reflectively with a narrowly scoped hidden-API exemption. Other firmware that lacks this API retains ordinary Android redraw behavior; a manual request explains when hardware full refresh is unavailable. No firmware settings or persistent refresh policy are changed.

Example navigation is attached only to the original-script TextView in study. Touch hit testing checks the actual laid-out line bounds, excluding blank space after wrapped lines, text padding, translation, and transliteration. Recall examples remain non-navigable.
