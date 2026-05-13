# `nx_notes` implementation plan

This plan builds `nx_notes` in thin vertical slices. The goal is to get
the writing loop working before adding heavier graph features.

## Phase 0: Decisions and references

Inputs:

- Desktop reference: `reference/index.html`
- Mobile reference: `reference/reference-mobile.html`
- Architecture: `docs/arch.md`
- KGQL essay design: `servers/pgdb/docs/current-plan/essay.md`

Decisions already made:

- Desktop uses tabs; mobile does not.
- Desktop search/tag results are a full workspace overlay.
- Desktop sidebar has two tabs: `Essays` and `Tags`.
- Each desktop essay tab owns its own result context.
- Mobile uses stack navigation and one open essay.
- Creating an essay requires choosing a topic first.
- Live Essay id stays stable; snapshots are separate `EssaySnap` rows.

## Phase 1: Backend KGQL model setup

Add or update KGQL model types:

```text
Abstract Essay
Essay
EssaySnap
```

Attributes:

```text
document        string
json_document   json
version_number  number   # EssaySnap
source          string   # EssaySnap
change_summary  json     # EssaySnap
```

Relations:

```text
Essay -> EssaySnap      has_snapshot
Essay -> Essay          references_essay
Essay -> Action         references_action
Essay -> Digital Nouns  references_digital_noun
Essay -> Real Nouns     references_real_noun
EssaySnap -> EssaySnap  parent_snapshot
```

Acceptance checks:

- `get_kgql_model_type(["Essay"])` returns shared document attributes.
- `get_kgql_model_type(["EssaySnap"])` returns shared document
  attributes and snapshot-specific fields.
- Can create Essay with `document` and `json_document`.
- Can create EssaySnap and link it to Essay.
- Can query Essay by tag filters.

## Phase 2: Flutter package scaffold

Create the app package if not already scaffolded:

```bash
cd /Users/nathikazad/Projects/Nexus/mobile
flutter create --template=app --org com.nexus --platforms ios,android,web nx_notes
```

Keep or add:

```text
pubspec.yaml
analysis_options.yaml
lib/main.dart
lib/app.dart
lib/router.dart
```

Dependencies:

```yaml
flutter_riverpod
graphql_flutter
go_router
intl
google_fonts
nx_db
appflowy_editor
```

Add AppFlowy Editor JSON/serialization dependency only behind the editor
codec. Do not spread editor serialization code through repositories or
widgets.

Acceptance checks:

- App launches to login when unauthenticated.
- App launches to `/notes` when authenticated.
- `flutter analyze` passes.

## Phase 3: Layer skeleton and tests

Create folders from `docs/arch.md`:

```text
core/
domain/
data/
features/
```

Add layering tests:

```text
test/layering/no_flutter_in_domain_test.dart
test/layering/no_nx_db_in_features_test.dart
```

Acceptance checks:

- Tests fail if `domain/` imports Flutter/Riverpod/nx_db.
- Tests fail if `features/` imports KGQL/GraphQL/nx_db internals.

## Phase 4: Domain model

Implement:

```text
domain/essay/essay.dart
domain/essay/essay_snap.dart
domain/essay/essay_query.dart
domain/essay/essay_result_context.dart
domain/essay/essay_repository.dart
domain/tags/tag_system.dart
domain/tags/note_tag.dart
domain/links/linked_model.dart
```

Acceptance checks:

- Pure Dart unit tests cover constructors, equality/value helpers, and
  query composition.
- No Flutter or Riverpod imports in `domain/`.

## Phase 5: Data layer and fake-first providers

Implement KGQL mapper structure:

```text
data/essay/essay_attr_keys.dart
data/essay/essay_mapper.dart
data/essay/essay_struct.dart
data/essay/essay_schema_provider.dart
data/essay/essay_snap_schema_provider.dart
data/essay/kgql_essay_repository.dart
data/providers.dart
```

Repository operations:

- recent essays
- pinned essays
- search by title
- list by tag
- get by id
- create essay with required topic
- update live draft
- create snapshot
- list snapshots

Keep fake repositories available for widget tests, but the default provider
uses the KGQL repository after login.

Acceptance checks:

- Mapper tests convert KGQL `Model` to `Essay`.
- Mapper tests convert `Essay` updates to set_kgql payloads.
- Provider test confirms `essayRepositoryProvider` returns the KGQL repo after
  login.

## Phase 6: Editor codec and AppFlowy Editor wrapper

Implement:

```text
data/editor/essay_document_codec.dart
data/editor/appflowy_document_codec.dart
features/editor/essay_editor_controller.dart
features/editor/essay_editor_view_model.dart
features/editor/widgets/editor_toolbar.dart
features/editor/widgets/editor_title_field.dart
```

Rules:

- `json_document` is the AppFlowy Editor source of truth.
- `document` is derived raw text.
- Autosave updates live Essay with debounce.
- Manual checkpoint creates EssaySnap.
- Do not create snapshots on every keystroke.

Acceptance checks:

- New blank document can be created.
- Existing JSON document can be loaded.
- Raw text extraction is stable.
- Title/body edits mark editor dirty and trigger debounced save.

## Phase 7: Desktop shell

Implement desktop UI from `reference/index.html`:

```text
features/desktop/desktop_shell.dart
features/desktop/desktop_sidebar.dart
features/desktop/desktop_result_overlay.dart
features/desktop/desktop_tab_bar.dart
features/desktop/desktop_inspector.dart
features/shell/selection_providers.dart
```

Behavior:

- Sidebar tabs: `Essays`, `Tags`.
- `Essays`: search, Recent 5, Pinned 5, Saved Views.
- `Tags`: tag tree.
- Search/tag/recent/pinned open full workspace overlay.
- Overlay result row opens or reuses an essay tab.
- Each tab stores its own `EssayResultContext`.
- Context bar can reopen that tab's prior result set.
- Tab close works and keeps at least one tab open.
- Sidebar `+` opens topic dropdown; choosing a topic creates an essay.

Acceptance checks:

- Widget test opens tag overlay and selects an essay.
- Widget test verifies context bar is per tab.
- Widget test closes active tab and activates neighboring tab.
- Widget test verifies create requires topic choice.

## Phase 8: Mobile shell

Implement mobile UI from `reference/reference-mobile.html`:

```text
features/mobile/mobile_shell.dart
features/mobile/mobile_home_screen.dart
features/mobile/mobile_tags_screen.dart
features/mobile/mobile_search_screen.dart
features/mobile/mobile_results_screen.dart
features/mobile/mobile_editor_screen.dart
```

Behavior:

- Bottom nav: `Essays`, `Tags`, `Search`.
- No editor tabs.
- Opening an essay from results carries a result context.
- Back from editor returns to the result list when context exists.
- Overflow menu opens bottom sheet.
- Details, Links, History are bottom sheets.

Acceptance checks:

- Widget test: tag -> results -> essay -> back returns to results.
- Widget test: direct recent essay -> back returns to home.
- Widget test: menu opens details/links/history sheets.

## Phase 9: Tags and links

Implement:

```text
features/tags/tag_browser.dart
features/tags/tag_editor_sheet.dart
features/links/link_picker_sheet.dart
data/tags/kgql_tag_repository.dart
data/links/kgql_link_repository.dart
```

Behavior:

- Edit status/topic/area tags.
- Browse hierarchical tag systems.
- Add links to Actions, Digital Nouns, and Real Nouns.
- Show backlinks/linked models in desktop inspector and mobile links
  sheet.

Acceptance checks:

- Updating tags persists through KGQL.
- Linking an essay to a model persists through KGQL.
- Linked model appears after reload.

## Phase 10: History and restore

Implement:

```text
features/history/snapshot_history_sheet.dart
features/inspector/history_panel.dart
```

Behavior:

- List snapshots sorted by `version_number desc`.
- Create manual checkpoint.
- Preview snapshot.
- Restore snapshot.
- Restore creates a checkpoint of current live Essay before applying
  the selected snapshot.

Acceptance checks:

- Manual checkpoint creates an EssaySnap with next version number.
- Latest snapshot is `max(version_number)`.
- Restore copies `document` and `json_document` back to live Essay.

## Phase 11: Polish and verification

Add:

- loading states
- empty states
- offline/error messages
- keyboard shortcuts on desktop
- responsive desktop/mobile breakpoint
- screenshot/widget tests for key screens

Verification:

```bash
flutter analyze
flutter test
flutter run -d chrome
```

Manual smoke flow:

1. Login.
2. Create essay by choosing a topic.
3. Edit title/body.
4. Save checkpoint.
5. Browse by tag.
6. Open result.
7. Use back-to-results context.
8. Add a link.
9. View history.
10. Restore prior snapshot.

## Initial milestone

The first shippable internal milestone is:

```text
auth
desktop shell
mobile shell
recent/pinned/tag/search navigation
open essay
edit title/body
autosave live Essay
manual snapshot
history list
```

Defer advanced link picking, rich diffing, branch history, and AI
rewrite workflows until the core writing loop is stable.
