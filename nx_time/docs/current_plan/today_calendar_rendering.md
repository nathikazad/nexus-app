# Today & Calendar: how to render KGQL Action data

Goal: keep Today and Calendar **simple** (few rows, 6-color bar) even though
the graph underneath has many `Action` subtypes and instance-level relations
(Goto, Meet, Work, Consumption, Sleep, Workout, Meditation, Prayer, …).

This file is a reminder of **how to collapse the graph into rows** once the
KGQL data is wired in. No code here, just rules and examples.

## Data model assumptions (post-migration)

- Every `Action` base subtype (Sleep, Meet, Goto, Work, Workout, Meditation,
  Prayer, Consumption, …) has attributes:
  - `start_time` — **datetime, required**
  - `end_time`   — datetime, optional
- `Meal` was renamed to `Consumption`. `Alcohol` was removed.
- Composition between real-world "sessions" is modeled with **relations
  between instances**, not type hierarchy:
  - `Goto → Meet`         (`led_to_meeting`)
  - `Goto → Work`         (`led_to_work`)          — add when needed
  - `Goto → Consumption`  (`led_to_consumption`)   — add when needed
  - `Meet → Consumption`  (food/drinks during a meet) — add when needed
  - `Meet → Person`       (`with_person`)
  - `Meet → Place` / `Meet → Event` / `Goto → Place` / `Goto → Event`
- **No type hierarchy for "happened with / at / during"**. Parent/child
  (`parent_id`) is only for true "is-a" (e.g. future `Consumption` → `Meal`,
  `Drink`, `Snack`).

## Core idea: one row per "visit"

A day’s Today list shows **one row per `Goto`** (one trip). Anything whose
`[start_time, end_time]` is **contained** in the Goto’s window, or is
**linked from the Goto** via one of the `led_to_*` relations, **folds into
that row**. If there is no surrounding `Goto` (e.g. home work, sleep, morning
meditation), the primary Action itself becomes the row.

This keeps the list short and matches how people remember their day:
"I went to X and did Y" vs "I was home and did Z".

## Collapse algorithm (pseudocode)

Pure Dart, client-side, over KGQL results for the selected day:

```text
rows = []
used = {}  // ids of folded-away instances

for goto in sort(Goto instances by start_time):
    contained = [
        a for a in all Action instances
        if a.id != goto.id
           and (a is linked_from goto via led_to_*)
           or a.start_time in [goto.start, goto.end or goto.start]
              and (a.end_time or a.start_time) <= (goto.end or goto.start + ε)
    ]
    row = buildRow(umbrella=goto, folded=contained)
    rows.append(row)
    used += {goto.id} ∪ contained.ids

for a in all remaining Action instances (not in used), sort by start_time:
    rows.append(buildRow(umbrella=a, folded=[]))

return sort(rows by start_time)
```

Notes:

- Prefer the **relation link** when deciding containment; fall back on the
  time window only if the edge isn’t there.
- Don’t fold Actions that already have their own `Goto` nested later in the
  day (rare, but handle by using `used` as a set).
- `Sleep` is never folded under a `Goto`.

## Row title

Choose in this order, first match wins:

1. `Meet` present and has an `Event` → **"\<Event name\> — \<Place\>"**
   (e.g. *"DevCon 2026 — Moscone"*).
2. `Meet` present → **"\<verb\> with \<people\>"**, verb inferred from
   category (coffee / lunch / call) or the plainer *"Meeting with Rachel"*.
3. `Work` present → the Work title (task/project) + place if any.
4. `Workout` present → *"Dancing"*, *"Run"*, *"Yoga"* (from Workout `type`).
5. `Consumption`-only folded → *"Lunch"*, *"Snack"*, *"Coffee"*.
6. Fallback → *"Visited \<Place\>"* or the Goto’s own name if set.

## Row category (color)

Used for the list dot, the legend, and the Today bar segments. Priority:

1. `Sleep` → **Sleep**
2. `Work` → **Work**
3. `Workout` → **Exercise**
4. `Meet` → **Social**
5. `Consumption` → **Eat**
6. `Goto` with an `Event` → **Social** (or a future **Events** color)
7. Else → **Routine / Outdoors** (pick by Place tags if any)

## Row subtitle

A comma-joined summary of **other** folded items that didn’t make the title:

- People (from `Meet.with_person`) — e.g. *"with Alice, Bob"*.
- Consumption names — *"coffee, cookies"*.
- Event name if not already in the title.
- Place name if not already in the title.

## Worked examples

### 1. Moscone — met Alice and Bob

Graph:

- `Goto(start=9:00, end=16:00) → Place(Moscone) → Event(DevCon 2026)`
- `Meet(Alice, with_person=Alice, at_place=Moscone, at_event=DevCon)`
- `Meet(Bob,   with_person=Bob,   at_place=Moscone, at_event=DevCon)`

Row:

```
•  DevCon 2026 — Moscone Center       9:00 AM – 4:00 PM · 7h
   with Alice, Bob
```

Category: **Social**. Bar: one segment 9am–4pm.

### 2. Joe’s Club — danced, met Corinne

Graph:

- `Goto(start=21:30, end=23:45) → Place(Joe’s Club)`
- `Workout(type="dance", start=21:40, end=23:30)`
- `Meet(Corinne, with_person=Corinne, at_place=Joe’s Club)`

Row:

```
•  Dancing — Joe’s Club               9:30 PM – 11:45 PM · 2h 15m
   with Corinne
```

Category: **Exercise** (rule 3 fires before rule 4). If you want Social to
win when a person is there, change the priority in code — the rule is local.

### 3. Starbucks — coffee with Rachel, coffee and cookies

Graph:

- `Goto(start=15:00, end=15:45) → Place(Starbucks)`
- `Meet(Rachel, with_person=Rachel, at_place=Starbucks)`
- `Consumption(coffee)` and `Consumption(cookies)` — contained in the Goto

Row:

```
•  Coffee with Rachel — Starbucks     3:00 PM – 3:45 PM · 45m
   coffee, cookies
```

Category: **Social**.

## Today bar segmentation

- One **segment per row** (post-collapse), sized by
  `(end - start) / day_window`.
- Color = the row’s category color.
- Gaps between rows are rendered as the **slate-100 background** (same as
  today’s stub in `fake_today_repository.dart`).
- Optional: **merge adjacent same-category segments** on the bar (list rows
  stay separate).

## Calendar week view

- Use the exact same `displayCategory()` + collapse logic per day.
- Column stack = category segments for the day, sized like Today.
- Tap a day → Today-style list for that date; tap a row → detail sheet.

## Detail sheet

The row is terse; detail is rich. When a user taps a row, render the full
graph for that umbrella:

- Place (address, city, map pin).
- People (from `Meet.with_person`).
- Event (from `Goto.to_event` / `Meet.at_event`).
- Consumptions (with any prices / calories).
- Linked tasks (when Work / future `Task` integration is added).
- Notes, photos, wearables.

This is what `ActivityDetailArgs` in
`lib/features/activity/activity_detail_models.dart` is already shaped for.

## Where to wire it in Flutter (when data lands)

- Add a small pure-Dart module (`lib/features/activity/action_fold.dart` or
  similar) exposing:
  - `List<DayRow> foldDayActions(List<Model> actions)`
  - `String titleForRow(DayRow r)`
  - `ActivityCategory categoryForRow(DayRow r)`
- Feed its output into:
  - `TodaySnapshot` construction (replacing `FakeTodayRepository`).
  - `CalendarPage` day columns (replace the hard-coded `_stackColumn`
    segment lists).
- Keep `ActivityRow` / `TimeMapBar` / `CategoryLegend` unchanged; only the
  data source changes.

## Guardrails

- **Don’t** push this logic into the DB. KGQL returns the graph; the app
  decides how to render a day. That keeps the graph reusable for other
  views (graph viz, search, memory traversal) without being biased toward
  the Today UI.
- **Don’t** add a new model type to simplify rendering (e.g. "DisplayBlock").
  Compose from existing Actions + relations.
- **Do** treat the collapse rules as UI config — they’ll evolve as more
  Action subtypes appear.
