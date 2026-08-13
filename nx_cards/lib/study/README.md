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
