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
sessions. Only English → language and language → English are selectable; both
include pronunciation. Study is ungraded. Recall writes one attempt and updates
FSRS for that direction.

`learning_stage.dart` derives Practice/Learning/Learnt from activation and the
account's recent-answer window (default 10, threshold 80%). Future means inactive.
Do not manually persist Learning/Learnt or activate replacement cards after recall.
Cards store Future, Practice, or Recall. Learning/Learnt are calculated from recall history; session completion does not run a separate progression service.

Language recall includes all cards matching the selected stages and score range,
just like Practice. When Learnt is selected, recall setup shows its due count.
Due Learnt cards are queued first (weaker scores first), then the remaining matching
cards fill the requested session size. Future-due Learnt cards remain selectable.
Settings are stored in
`users.preferences.nx_cards.history_window` and refreshed with library sync;
saving requires connectivity. Server migration and verification are documented
in `servers/nexus/apps/nx_cards/maintenance/learning-workflow.md`.

Reverse-direction recall offers Written or Listening presentation. Listening
shows transliteration and plays target-language audio; both ask for the source
language meaning and use the same `StudyCue.toLanguage` schedule/history.
The presentation preference is local setup state, never a database direction.
Standard and writing modes autoplay the prompt; Fast uses per-row playback.
