# Study

Study turns cards plus a person's choices into an active learning session.

```text
study.dart / study_queue.dart
  -> study_setup_page.dart   selecting mode, recall components, filters and count
  -> session/               conducting a review and showing its recap
  -> language/              language sheets, examples, audio and fast recall
     -> drawing/            handwriting practice and script-specific recall
```

Study delegates review timing to `scheduling/` and voice delivery to `tutor/`.

A language card has six independent directed histories and FSRS schedules:
Meaning → Sound, Meaning → Script, Sound → Meaning, Sound → Script,
Script → Meaning and Script → Sound. Eligible directions sharing a card and source are combined into one question.
Yes/No updates every tested direction with its own FSRS calculation, in one
card save. Untested directions stay unchanged. Writing off removes script
targets; spoken-only also removes script prompts. Filters and due dates apply
before grouping, and the weakest included direction sets question priority. Book cards retain generic
Front → Back and optional Back → Front schedules.

The recall setup's **Recall for** choices are Meaning, Sound and Script.
Selecting a component includes every direction involving it as source or target.
Selections form a union, so overlapping directions are never counted twice.
Spoken-only cards exclude all script directions, without deleting their history
or schedules. Sound-source questions require an audio asset.

The device-local **Writing** setting excludes Meaning → Script and Sound → Script
when off. Script-source questions remain available. It filters questions only;
it does not change retained scores or histories. Script answers use the drawing
surface; meaning and sound answers use the standard response presentation.

`learning_stage.dart` derives Practice/Weak/Strong from activation and recall
history. Each direction uses successes among its latest five recalls divided by
five, with missing slots counted as zero. Each skill (Meaning, Sound, Script)
pools the latest five recalls across directions involving that skill, using the
same denominator. Overall scores average those three skills, or Meaning and
Sound for spoken-only cards. Card details, card filters and Progress use this
average. Recall filters and priority use each individual direction's score.
FSRS determines due dates independently. The Strong threshold is 80%.

Do not persist Weak/Strong or activate replacement cards after recall. Cards
store Future, Practice or Recall; Weak/Strong are calculated. Recall setup can
filter by retention or due schedules. AI sessions exclude script questions.

The server's schedule/history contract is version 4. Clients write directed cue
keys and reject legacy envelopes. SQLite schema 17 invalidates the old card
cache for a fresh pull and archives old queued card writes in
`rejected_card_outbox_v3`; those writes are not submitted or converted.
Cache and outbox partitions remain scoped to server, user, domain and app.
