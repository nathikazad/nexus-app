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
Script → Meaning and Script → Sound. Setup offers six directions in two columns. Selected directions determine
which source questions are eligible. Eligible directions are grouped by card and source into one
question. Either outgoing direction can admit that question through Due or
Retention; the review itself tests all enabled answers for that source.

`StudyPrompt.forRecall` defines that invariant and the shared FSRS scheduler
applies it again before grading. Yes/No updates both applicable outgoing
histories and schedules; schedules remain independent. Spoken-only cards never
test or update script. Writing off excludes script targets but retains script
sources. Missing/disabled directions are never enabled or credited.

The writing pad and script testing are automatic at 600 logical pixels or wider.
Phones expose a Writing switch. Silent is a separate cached session setting,
default off: it disables all playback and excludes sound-source questions,
without excluding sound targets. Meaning and Script cues can still test mental
pronunciation. AI retains its oral-only policy.

Setup shows selected cards (recalls) on the left and the fixed available total
as “X cards (Y recalls)” on the right. The count slider selects recalls;
multiple answers sharing a source cue count as one recall. Selection covers each card's weakest eligible question first, then
remaining questions; the selected queue is shuffled. All/Clear share the cue
heading row and selected direction buttons use the format controls' filled style.

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
filter by retention or due schedules. New selects Recall cards with no review
history, review count, or last-review timestamp in any direction, including
disabled directions. The available count at the bottom of recall setup shows distinct cards
and grouped recalls. The slider selects the number of recalls; practice
continues to select cards. Recall formats are Standard and Fast. AI sessions exclude script questions.

The server's schedule/history contract is version 4. Clients write directed cue
keys and reject legacy envelopes. SQLite schema 17 invalidates the old card
cache for a fresh pull and archives old queued card writes in
`rejected_card_outbox_v3`; those writes are not submitted or converted.
Cache and outbox partitions remain scoped to server, user, domain and app.

## Current entry dates

`added_to_current_at` is an optional YYYY-MM-DD calendar date. Entering Recall
(Current) from another state records the device-local date; re-entering updates
it. Reviews and repeated Recall writes preserve it. Existing cards remain null.
SQLite v18 adds only a nullable column and preserves v17 cards/outbox data.

Recall setup's By date tab lists the five most recent dated Current groups in
scope, with distinct card counts and a two-ended date-range slider. The slider
steps through dates from oldest to newest and includes all groups between its handles. Null dates are
excluded. Dates select the pool independently of retention/due filters; selected directions and the direction-count choice still apply. Selection still covers
each card's weakest direction first, fills remaining slots, then shuffles.
