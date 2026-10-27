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
Script → Meaning and Script → Sound. Recall setup counts individual directions, each presented as its own question.
Selection first takes each card’s weakest eligible direction, ordered weakest
first. Remaining slots take the other eligible directions in weakness order.
Only the selected queue is shuffled, so presentation order is fully randomized.
Yes/No updates every tested direction with its own FSRS calculation, in one
card save. Untested directions stay unchanged. Writing off removes script
targets; spoken-only also removes script prompts. Filters and due dates apply
before selection. Book cards retain generic
Front → Back and optional Back → Front schedules.

The recall setup's **Recall for** choices are Meaning, Sound and Script.
Selecting a component includes every direction involving it as source or target.
Selections form a union, so overlapping directions are never counted twice.
Spoken-only cards exclude all script directions, without deleting their history
or schedules. Sound-source questions require an audio asset.

The device-local **Writing** setting excludes Meaning → Script and Sound → Script
when off. Script-source questions remain available. When on, every non-spoken-only
question in standard recall has a writing area, including script prompts. That
extra scratchpad does not add any tested directions or change scoring.

The device-local **Sound** setting excludes sound as either source or target when
off, leaving Meaning ↔ Script (or only Script → Meaning with Writing off).
Spoken-only cards have no eligible questions in a silent session. Audio playback,
including answer and related-card audio, is disabled for the session. Both
settings also apply to grouped recall and are remembered in recall setup.

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
disabled directions. The available-card count at the bottom of recall setup shows distinct cards
and individual directions. The slider selects the number of directions; practice
continues to select cards and similar-sound recall selects groups. AI sessions exclude script questions.

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
excluded. Dates select the pool independently of retention/due filters; skill,
sound, writing and direction-count choices still apply. Selection still covers
each card's weakest direction first, fills remaining slots, then shuffles.
