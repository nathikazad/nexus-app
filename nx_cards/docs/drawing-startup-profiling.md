# Drawing and recall startup timings

Android release builds emit `NxCardsStartup` markers to logcat. Capture with:

```
adb logcat -v epoch 'flutter:I' 'NxCardsStartup:I' '*:S'
```

Open the study setup, select drawing, and tap Start drawing. Exit, select writing recall, and tap Start recall. Repeat each once to distinguish first use from warm startup. Keep queue size and category the same.

Dart markers include a session identifier, monotonic cumulative `total_ms`, and duration since the previous marker `delta_ms`. Both Dart and Android markers include device `epoch_ms` to join the channel handoff. No card text, credentials, or account identifiers are logged.

Stages:

- `tap`: timer starts in the button handler.
- `dashboard_ready`: dashboard provider has resolved.
- `selection_ready` (recall): filters and queue selection completed.
- `queue_hydrated`: selected card bodies loaded from local storage. Drawing includes selection in this interval.
- `native_available`: platform availability check completed.
- `library_loaded`: library summaries loaded and indexed; includes library size.
- `example_parents_hydrated`: full bodies of direct example cards loaded once each. Required because offline summaries omit examples.
- `context_derived`: character and second-level example lists computed.
- `payload_ready`: complete queue serialized into method-channel arguments.
- `channel_send` / `channel_received`: method-channel dispatch and native receipt.
- `activity_create`: Android activity creation begins.
- `before_ink_init` / `ink_initialized`: handwriting view initialization.
- `layout_built` / `first_card_bound`: layout construction and initial card binding.
- `first_ui_post`: queued UI callback after initial setup. This is not proof that the e-ink panel has physically refreshed.

Native `native_ms` is elapsed time from activity creation. Do not time the awaited `NativeDrawingSession.open` as startup: it resolves only when the user ends the entire session.

The offline nested-example regression is covered by a test using a summary parent with no examples, a fully loaded parent with a sentence example, and an unloaded grandchild. It ensures exactly one parent read and no recursive body loading.

## Captured baseline: build 20260943, Android Wi-Fi 10.0.0.8

Drawing, 40 selected cards, 750 cards in the local library:

| Stage | Duration |
| --- | ---: |
| Dashboard | <1 ms |
| Selection plus sequential queue hydration | 12,597 ms |
| Native availability | 4 ms |
| Library summary load/index | 259 ms |
| Example-parent hydration | 694 ms |
| Derivation | 2 ms |
| Native ink initialization | 87 ms |
| Activity creation through first UI post | 950 ms |
| Tap through first UI post | 14,576 ms |

The user reported about 20 seconds visually. The markers do not include physical panel refresh. Queue preparation accounts for about 86% of the measured tap-to-UI interval; ink initialization is small. This baseline did not split drawing selection from body loading.

The next build overlaps up to eight local card reads, preserves ordering, and deduplicates identical cards across recall cues. Direct example parents use the same bounded reader. `selection_ready` now also splits drawing selection from loading. `card_read` reports database `query_ms` and content read/decode `body_ms`; concurrent durations overlap and must not be summed. Speedup must be verified with a new device run, not inferred from concurrency alone.

## Measured follow-up: build 20260944

The user repeated the 40-card drawing launch and reported it was faster. Same device and 750-card library; shuffled card membership and OS cache/background activity may differ between runs.

| Stage | New duration |
| --- | ---: |
| Selection | 2 ms |
| Queue hydration, eight overlapping reads | 427 ms |
| Native availability | 6 ms |
| Library summary load/index | 430 ms |
| Example-parent hydration | 578 ms |
| Derivation | 2 ms |
| Native ink initialization | 87 ms |
| Activity creation through first UI post | 920 ms |
| Tap through first UI post | 2,445 ms |

Observed end-to-end reduction: 83.2% (14,576 to 2,445 ms), approximately 6x faster in these two runs. Selected-card loading was the dominant baseline stage and dropped sharply. These are single-run observations, not a controlled benchmark or guaranteed speedup. Recall uses the same bounded hydration helper but has not yet been separately timed on-device. Physical e-ink refresh remains outside the markers.

## Incremental preparation: build 20260945

Drawing and Android writing recall now pass a fixed-size queue with only its first card prepared. The library index reuses the dashboard snapshot instead of rereading the full summary table. Each prepared card includes its direct and derived examples.

After the native UI is initialized, Android requests the next two indices. Advancing replenishes that two-card lookahead. Repeated requests share pending preparation; visited cards remain cached for Previous. Queue order and recall rating indices do not change. If navigation catches up to loading, ink is cleared only after the target card is ready; failed loads can be retried and the session can be exited while waiting. Closing the session invalidates pending results. No card preparation triggers a rating.

New timing markers: `first_card_ready` replaces full `queue_hydrated` on the native path; `card_prepared` records each index's preparation duration, including background work. `library_snapshot` measures indexing the existing dashboard. Compare first-card timing separately from lookahead completion.
