# Study

Study turns cards plus a person's choices into an active learning session.

```text
study.dart / study_queue.dart
  -> study_setup_page.dart   selecting mode, prompts, filters, order, and count
  -> session/    conducting a review and showing its recap
  -> language/          language sheets, examples, audio, and fast recall
     -> drawing/        handwriting practice and script-specific recall
```

Study delegates review timing to `scheduling/` and voice delivery to `tutor/`.

Language direction is chosen on `LanguagePage` and shared by its lists and
sessions. English text → target language, target-language audio → target language,
and target script → English are selectable. Each has independent history,
strength, and FSRS state. Study is ungraded. Recall writes one attempt for the
selected direction regardless of presentation.

`learning_stage.dart` derives Practice/Weak/Strong from activation and the
latest ten attempts per direction, using a denominator of at least five and an
80% Strong threshold. The old account window setting no longer controls scoring.
Future means inactive.
Do not manually persist Weak/Strong or activate replacement cards after recall.
Cards store Future, Practice, or Recall. Weak/Strong are calculated from recall history; session completion does not run a separate progression service.

Language recall includes all cards matching the selected stages and score range,
just like Practice. When Strong is selected, recall setup shows its due count.
Due Strong cards are queued first (weaker scores first), then the remaining matching
cards fill the requested session size. Future-due Strong cards remain selectable.
Scoring is derived from existing history; no history migration or FSRS reset is needed.

English and audio recall offer Standard, Fast and Write. Target script → English
offers Standard and Fast. Standard/Fast imply a spoken response; there is no
separate response selector or Read/Listen toggle. Writing is optional.

Audio uses `StudyCue.fromAudio` (`from_audio`), shows only “Listen” before reveal,
and excludes cards without audio. Standard and Write autoplay; Fast uses per-row
playback. Revealed cards put target script above English. Existing `to_language`
history stays unchanged; historical listening cannot be distinguished from read
reviews. Missing audio schedules start fresh; explicit disabled schedules remain
disabled. No SQLite schema bump is needed; cue maps are JSON.

Deploy the server validator update in
`servers/nexus/apps/nx_cards/maintenance/three_recall_types.sql` before updated
clients write. Upgrade other clients editing the same cards, since legacy clients
can discard unrecognized audio entries when replacing whole cue maps.
