# `nx_cooking` UI reference

This document is the visual + interaction spec for the **mobile-only**
cooking planner. It's the source of truth for the static HTML/CSS
prototype (`reference/`) and for the Flutter app that follows. The
companion DB plan is
[`servers/pgdb/docs/current-plans/cooking_additions.md`](../../../servers/pgdb/docs/current-plans/cooking_additions.md).

## What `nx_cooking` is

A mobile app that helps a person:

1. **Maintain a recipe inventory** — add a recipe once, reuse forever.
2. **Plan a week of cooking** — schedule recipes onto specific days.
3. **Generate a buy list** — automatically derived from the week's
   scheduled recipes; check items off as they're bought.
4. **Log what actually got cooked** — start/done/skip a planned task,
   record modifications and outcome.
5. **See weekly stats** — meals cooked, total time spent.

There is **no desktop layout**. Every screen targets a phone viewport.
A single bottom navigation bar with four tabs is the spine of the app.

## Reference prototype layout

```
nx_cooking/
  reference/
    arch.md              # this file
    index.html           # single-page prototype, all four tabs + sheets
    styles.css           # dark theme matching nx_projects
    (later) app.js       # state + render dispatch
```

Serve with `npx serve .` from `reference/`. The prototype is the visual
and interaction spec — the Flutter app reproduces it 1:1 before
adding any new behavior.

## Tabs

The four tabs at the bottom, left → right:

| Tab        | Icon (sketch) | Purpose                                                                  |
| ---------- | ------------- | ------------------------------------------------------------------------ |
| **Week**   | calendar      | This week's `CookingTask`s grouped by day; the planning view             |
| **Recipes**| book          | The user's recipe inventory; entry point to schedule a recipe            |
| **Buy**    | cart          | Computed buy list across this week's tasks; check off as bought          |
| **Stats**  | bar-chart     | Per-week stats — meals cooked, total cooking time                        |

The selected tab is the only persistent navigation state. Each tab
has independent in-tab navigation (push / pop) — leaving and
returning to a tab restores the in-tab state.

## State model (UI-level)

These are the only "globals" the prototype tracks. Everything else is
derived.

```js
let tab = 'week';                       // 'week' | 'recipes' | 'buy' | 'stats'
let weekStart = mondayOf(TODAY);        // shared by Week + Buy + Stats
let recipeNav = { recipeId: null,       // Recipes tab drill state
                  editing: false };
let cookingTaskNav = { taskId: null };  // Week tab drill state
let recipeSearch = '';                  // Recipes tab search query
let recipeSort = 'recent';              // 'recent' | 'alpha'
```

`weekStart` is **shared state** across Week / Buy / Stats — moving the
chevrons on Week also moves Buy and Stats. Recipes is week-independent.

## Tab 1 — Week

The planning view. Shows the seven days of `weekStart`'s week, today
auto-selected.

### Top chrome
- **Title bar**: "Week of Apr 27" (the Monday).
- **Chevrons** ‹ ›: step `weekStart` back / forward by 7 days.
- **Day strip**: Mon–Sun. Selected day is highlighted; today is
  underlined even when not selected. Tap a day to select it.

### Body
A vertical list of the **selected day's** `CookingTask` rows (not all
seven days at once — the screen would crowd). Above the list: a small
heading row "Tuesday · Apr 28 · 2 planned · 1 cooking".

Each task row:

```
┌────────────────────────────────────────────┐
│ ● Pasta Carbonara              ~30m   ›   │
│   3 ingredients · 2 bought                  │
└────────────────────────────────────────────┘
```

- **Status dot**: planned = neutral, cooking = accent (blue), done =
  check + dimmed, skipped = strike-through + grey.
- **Right chevron**: tap → cooking-task detail (push).
- **Subtitle**: "<n> ingredients · <k> bought".
- **Long-press**: bottom sheet with *Move to other day* / *Remove*.

### Empty state
"No cooking planned for Tuesday. Add a recipe from the Recipes tab."
No "+ add" button on Week tab — scheduling starts from a Recipe.

### No FAB on Week tab
The Recipes tab owns recipe creation. Week is read + drill-in only.

## Tab 2 — Recipes

The inventory. A scrollable list of the user's recipes.

### Top chrome
- **Search field** "Search recipes" (filters by name only — no
  ingredient search in v1).
- **Sort toggle**: *Recent* / *A–Z*. Default *Recent* (sort by
  `last_cooked_at` desc, recipes never cooked at the bottom).

### Body
A flat list of recipe rows:

```
┌────────────────────────────────────────────┐
│ Pasta Carbonara                          › │
│ 3 ingredients · last cooked 4d ago         │
└────────────────────────────────────────────┘
```

### FAB
A circular `+` in the bottom-right opens **Recipe edit** in *create*
mode. Visible **only on the Recipes tab list view**. Hidden on
recipe detail / edit.

### Empty state
"No recipes yet. Tap + to add your first."

### Recipe detail (push)

Tapping a recipe row pushes the detail screen.

```
[ ← back ]                       [ ⋯ overflow ]
┌────────────────────────────────────────────┐
│ ▢ photo placeholder (16:9 muted block)    │
│                                            │
│ Pasta Carbonara                            │
│ 3 ingredients · ~30m · last cooked 4d ago  │
│                                            │
│ Ingredients                                 │
│  • Spaghetti          500 g                │
│  • Eggs               4 whole              │
│  • Bacon              200 g                │
│                                            │
│ Instructions                                │
│  1. Boil pasta…                            │
│  2. …                                      │
└────────────────────────────────────────────┘
[ Cook now ]      [ Add to day ]
```

- **Photo placeholder** — a stub `<div>` sized 16:9; no upload in v1
  but the layout is reserved so adding photos later doesn't shift
  the page.
- **Cook now**: creates a `CookingTask` for **today** and sets it to
  `cooking` (calls the start lifecycle). Navigates to the
  cooking-task detail.
- **Add to day**: opens a calendar bottom-sheet (future-only;
  defaults to next empty day this week). On select, creates a
  `CookingTask` with `status: planned` for that date. Toast:
  "Added to Tue Apr 28". Stays on recipe detail.
- **Overflow** ⋯: *Edit* / *Delete*. Delete is soft (recipe hidden
  from inventory; existing tasks still resolve).

### Recipe edit (push, used for create + edit)

```
[ ← back ]                          [ Save ]
┌────────────────────────────────────────────┐
│ Name              [______________________] │
│ Notes             [______________________] │
│                                            │
│ Ingredients                                 │
│  ⋮ Spaghetti          [500] [g    ▾]    × │
│  ⋮ Eggs               [4]   [whole ▾]   × │
│  ⋮ Bacon              [200] [g    ▾]    × │
│  + Add ingredient                          │
└────────────────────────────────────────────┘
```

- **Add ingredient**: opens an **Item picker** sheet — search-as-you-
  type against existing `Item`s that carry the `CookingItem` trait.
  At the bottom of the picker: "Create new item: <query>" — taps
  through to a tiny new-item sheet (just a name field). The newly
  created Item is assumed to be tagged with the `CookingItem` trait
  by the tagging service; the recipe edit waits for that round-trip.
- **Quantity** and **Unit** — number input + free-string text input
  (rendered as a small dropdown of the user's recently-used units
  with "Custom…" at the bottom; the underlying field is free string).
- **Reorder** ⋮: long-press to drag.
- **Remove** ×: removes from this recipe.
- **Save**: validates name non-empty; ingredients optional but
  expected. Pop back to detail.

## Tab 3 — Buy

Computed shopping list for the current week. Reads only — well, taps
on checkboxes write back to the source `CookingTask.ingredient_checks`
JSON, but no Items are created or destroyed here.

### Top chrome
- **Title**: "Buy · week of Apr 27".
- **Chevrons** ‹ ›: shared with Week tab (same `weekStart`).
- **Summary line**: "14 items · 5 bought".

### Body — grouped by recipe, ascending alphabetical

```
Pasta Carbonara                 Tue · Apr 28
  ☑ Spaghetti           500 g
  ☑ Eggs                4 whole
  ☐ Bacon               200 g

Stir Fry                        Thu · Apr 30
  ☐ Onion               2 whole
  ☐ Bell pepper         1 whole
  …
```

- **Section header**: recipe name + the day(s) it's planned for. If a
  recipe is scheduled twice in the same week, it gets two sections
  (one per task) so the per-task check state stays separate.
- **Row**: checkbox + Item name + "<qty> <unit>".
- **Tap row** (anywhere): toggles the checkbox; immediately writes
  the boolean to the owning `CookingTask.ingredient_checks` map
  (key = Item Model id).
- **Order within a section**: ingredient definition order on the
  Recipe (no internal sort).
- **No quantity merging across sections**. Onion in two recipes shows
  in two sections, with two checkboxes.

### Empty state
"Nothing scheduled for this week." (no buy list to compute).

### Visual treatment of checked rows
- Checkbox filled, label gets `text-decoration: line-through` and
  reduced opacity. Bought rows do **not** sink to the bottom — they
  stay in their recipe section so the user can re-find them.

### No filters in v1
No "show unchecked only", no day filter, no aisle grouping. Defer.

## Tab 4 — Stats

Minimal. Same week-navigation as Week + Buy.

### Top chrome
- **Title**: "Stats · week of Apr 27".
- **Chevrons** ‹ ›: same shared `weekStart`.

### Body

```
┌────────────────────┐  ┌────────────────────┐
│      3             │  │     2h 15m         │
│  meals cooked      │  │  total cooking     │
└────────────────────┘  └────────────────────┘

Cooked this week
  ▢ Pasta Carbonara   Tue · 45m
  ▢ Stir Fry          Wed · 30m
  ▢ Pasta Carbonara   Sat · 60m   (cooked again)
```

- **Meals cooked**: `count(Cooking)` whose `start_time` falls
  in the selected week.
- **Total time**: Σ `(end_time − start_time)` across those actions.
- **Cooked this week list**: one row per `Cooking`. Tap → the
  cooking-task detail of the linked task (if any).
- **Skipped tasks** are **not** counted; they don't appear in the
  list either.

### Empty state
"Nothing cooked yet this week." Both numbers show `—`.

## Cooking-task detail (pushed from Week tab)

Tapping a `CookingTask` row on Week pushes a screen that's the
recipe-detail layout **plus** controls for the task's lifecycle and
the per-task ingredient checkboxes.

```
[ ← back ]                          [ ⋯ overflow ]
┌────────────────────────────────────────────┐
│ ▢ photo placeholder                        │
│                                            │
│ Pasta Carbonara                            │
│ Tue · Apr 28 ·  status: planned            │
│                                            │
│ Ingredients   (tap to toggle bought)       │
│  ☐ Spaghetti          500 g                │
│  ☐ Eggs               4 whole              │
│  ☐ Bacon              200 g                │
│                                            │
│ Instructions   (read-only, from recipe)    │
│  1. …                                       │
└────────────────────────────────────────────┘

(footer changes by status — see below)
```

### Status-driven footer

| Current status | Footer buttons                           | Result                                                                                  |
| -------------- | ---------------------------------------- | --------------------------------------------------------------------------------------- |
| `planned`      | [ Start cooking ]   [ Mark done ]   [ Skip ] | *Start* → status `cooking`, creates open `Cooking`. *Mark done* → prompts for both start and end times, then status `done`. *Skip* → status `skipped`. |
| `cooking`      | [ Mark done ]   [ Cancel cooking ]       | *Mark done* → prompts for end time only, fills modifications + outcome, status `done`. *Cancel* → discards open `Cooking`, status `planned`. |
| `done`         | [ Edit log ]                             | Opens the modifications + outcome editor. Status sticks at `done`.                      |
| `skipped`      | [ Restore ]                              | Status `planned`.                                                                       |

### Mark-done sheet

Bottom sheet with:

```
End time          [ now ▾ ]    (default = now; tap to pick)
(if no start_time yet) Start time  [ −30m ▾ ]
Modifications     [____________]  (optional)
How did it go?    [____________]  (optional)
                                   [ Save ]
```

The two text fields write to `Cooking.modifications` and
`Cooking.outcome`. Skipping them is fine.

### Ingredient checkboxes
Tapping a checkbox toggles the boolean immediately, same write path
as Buy tab. The two views stay in sync.

### Overflow ⋯
*Move to other day* (future-only date picker) / *Remove* (deletes
the task; if a `Cooking` exists, the action is **not** deleted —
it stands on its own and still counts in Stats).

## Bottom sheets (shared)

All sheets share one backdrop. Opening any sheet closes any open
sheet first (single-modal invariant).

| Sheet                | Triggered from                          | Purpose                                                  |
| -------------------- | --------------------------------------- | -------------------------------------------------------- |
| Day picker (future)  | Recipe detail *Add to day*; Move action | Pick a date ≥ today                                      |
| Day-time picker      | Mark done (start + end times)           | Two pickers, one per field                               |
| Item picker          | Recipe edit *+ Add ingredient*          | Search Items with `CookingItem` trait + create-new       |
| Unit picker          | Recipe edit unit field                  | Recently-used units + Custom… input                      |
| New-item sheet       | Item picker *Create new item*           | Single name field + save                                 |
| Mark-done sheet      | Cooking-task detail *Mark done*         | End time, optional start time, modifications, outcome    |
| Confirm-delete sheet | Recipe detail / task overflow *Delete*  | "Hide recipe? It will stop appearing in your inventory." |
| Long-press task menu | Week tab task row long-press            | Move to other day / Remove                               |

## Theme + visual language

Inherits the dark theme from
[`nx_projects/reference/`](../../nx_projects/reference/) — same CSS
variables, same spacing scale, same row treatments. Specifically:

- `--bg`, `--panel`, `--accent`, `--ok`, `--warn` re-used verbatim.
- Status dot colors: `planned = --muted`, `cooking = --accent`,
  `done = --ok`, `skipped = --warn` (or strikethrough + muted).
- Photo placeholder: `--panel` block with a faint icon centered.
- Chevron / day-strip styling matches `nx_projects` Sprint tab's
  day strip so the two apps feel like the same family.

## What's intentionally not here (v1)

- **No desktop shell.** This app is mobile-first **and** mobile-only.
  No `isDesktopLayout` switch, no `embedded` flag on screens, no
  multi-pane composition. A future revision can add it; the screen
  widgets above are designed so they could each be wrapped in a
  panel chrome later, but no such hook exists now.
- **No quantity merging on the buy list.** Two recipes that need
  onion = two checkboxes. Aggregation is a future feature.
- **No ingredient search in Recipes tab.** Name only.
- **No recipe categories / tags / favorites.**
- **No recipe photos** (placeholder block only).
- **No rating field on cooking actions.** Just modifications + outcome.
- **No carry-forward of last session's modifications.**
- **No history tab.** Stats covers the "what did I cook" question on
  a per-week basis; no all-time feed.
- **No multi-recipe cooking tasks.** Two dishes in one evening = two
  tasks.
- **No filters / aisle grouping on Buy tab.** Group-by-recipe only.
- **No undo for skipped tasks** beyond the *Restore* button on the
  task detail.
- **No backfill in the Add-to-day calendar.** Future-only. Backfilling
  past cooking happens implicitly via the *Mark done* flow that
  prompts for both start and end times.

## Build order for the prototype

When implementing the static HTML/CSS, do it in this order so each
step is testable on its own:

1. **Shell** — bottom nav + top bar + view container. Stub all four
   tabs with placeholders; verify tab switching works.
2. **Recipes tab** — list, search, sort toggle, FAB. Seed with 5–6
   recipes in a JS array.
3. **Recipe detail** — read-only view with Cook now / Add to day
   buttons (buttons are no-ops for now).
4. **Recipe edit** — name, notes, ingredients with item picker (item
   picker reads from a seeded items array).
5. **Week tab** — day strip, week chevrons, task list per selected
   day. Seed CookingTasks referencing the recipes from step 2.
6. **Cooking-task detail** — recipe-style read view + status footer +
   ingredient checkboxes. Wire the status state machine in JS.
7. **Buy tab** — group by recipe, render rows from the week's tasks,
   wire checkbox writes into the same JS state as step 6.
8. **Stats tab** — count `Cooking` models, sum durations, render two
   numbers + the cooked-this-week list.
9. **Bottom sheets** — day picker, mark-done sheet, unit picker,
   confirm-delete. Drive from one sheet manager.
10. **Empty states** — wire each tab's empty-state copy.

After step 10 the prototype is feature-complete for v1 and the
Flutter port can begin.
