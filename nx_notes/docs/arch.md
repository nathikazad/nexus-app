# `nx_notes` architecture

This is the entry-point doc for the Flutter notes app. It follows the
same four-layer architecture as `nx_time`, `nx_projects`, and
`nx_expense`, with the responsive shell pattern from `nx_projects`.

Reference prototypes:

```text
reference/index.html             # desktop workspace
reference/reference-mobile.html  # mobile stack
```

## What `nx_notes` is

`nx_notes` is an internal Notion-like essay/document app on top of KGQL.
It stores live essays, immutable snapshots, tags, and graph links to
Actions, Digital Nouns, and Real Nouns.

The editor is built with AppFlowy Editor. KGQL stores:

- `document`: raw text, used for search, snippets, embeddings, and
  summaries.
- `json_document`: serialized editor state, used for edit/render
  fidelity.

## Layering

The app uses the same strict layers as the other Nexus Flutter apps:

```text
lib/
  core/      generic Flutter-only utilities
  domain/    pure Dart entities and repository interfaces
  data/      KGQL, nx_db, GraphQL, Riverpod bridge
  features/  screens, view-models, feature widgets
```

Rules:

| Layer | May import | Must not import |
|-------|------------|-----------------|
| `core/` | Flutter, intl, pure Dart | `domain/`, `data/`, `features/`, `nx_db` |
| `domain/` | pure Dart only | Flutter, Riverpod, GraphQL, `nx_db` |
| `data/` | `core/`, `domain/`, Riverpod, GraphQL, focused `nx_db` libraries | `features/` |
| `features/` | lower layers + `package:nx_db/auth.dart` if needed | `package:nx_db/kgql.dart`, `package:nx_db/riverpod.dart`, GraphQL |

Add layering tests early and keep them green.

## KGQL model assumptions

The backend model shape is:

```text
Abstract Essay
  document         string
  json_document    json

Essay
  canonical/live document

EssaySnap
  immutable snapshot
  version_number
  source
  change_summary
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

The canonical `Essay` id must remain stable. Saves update the live
Essay; meaningful checkpoints create `EssaySnap` rows.

## Folder layout

```text
nx_notes/
  lib/
    main.dart
    app.dart
    router.dart

    core/
      theme/
        app_theme.dart
      layout/
        layout.dart
        is_desktop_layout.dart
      formatting/
        date_label.dart
      widgets/
        empty_state.dart
        section_header.dart

    domain/
      essay/
        essay.dart
        essay_snap.dart
        essay_query.dart
        essay_result_context.dart
        essay_repository.dart
      tags/
        note_tag.dart
        tag_system.dart
      links/
        linked_model.dart

    data/
      providers.dart
      essay/
        essay_attr_keys.dart
        essay_mapper.dart
        essay_struct.dart
        essay_schema_provider.dart
        essay_snap_schema_provider.dart
        kgql_essay_repository.dart
      tags/
        kgql_tag_repository.dart
        tag_mapper.dart
      links/
        kgql_link_repository.dart
        linked_model_mapper.dart
      editor/
        essay_document_codec.dart
        super_editor_document_codec.dart

    features/
      auth/
        notes_login_screen.dart
      shell/
        notes_root_shell.dart
        selection_providers.dart
      desktop/
        desktop_shell.dart
        desktop_sidebar.dart
        desktop_result_overlay.dart
        desktop_tab_bar.dart
        desktop_inspector.dart
      mobile/
        mobile_shell.dart
        mobile_home_screen.dart
        mobile_tags_screen.dart
        mobile_search_screen.dart
        mobile_results_screen.dart
      navigator/
        essay_row.dart
        notes_sidebar_view_model.dart
        result_overlay_view_model.dart
      editor/
        essay_editor_screen.dart
        essay_editor_view_model.dart
        essay_editor_controller.dart
        widgets/
          editor_context_bar.dart
          editor_toolbar.dart
          editor_title_field.dart
      inspector/
        essay_inspector.dart
        details_panel.dart
        links_panel.dart
        history_panel.dart
      tags/
        tag_browser.dart
        tag_editor_sheet.dart
      links/
        link_picker_sheet.dart
      history/
        snapshot_history_sheet.dart
```

## Domain layer

Core types:

```text
Essay
  id
  title
  document
  jsonDocument
  wordCount
  status
  topics
  areaTags
  pinned
  updatedAt
  links
  latestVersionNumber

EssaySnap
  id
  essayId
  versionNumber
  document
  jsonDocument
  source
  changeSummary
  createdAt

EssayQuery
  searchText
  tagFilters
  pinnedOnly
  sort

EssayResultContext
  title
  query
  resultIds
```

Repository interface:

```text
EssayRepository
  listRecent(limit)
  listPinned(limit)
  search(query)
  listByTag(system, node, includeDescendants)
  getById(id)
  create(topic)
  updateDraft(essay)
  createSnapshot(essayId, source, changeSummary)
  listSnapshots(essayId)
  restoreSnapshot(essayId, snapId)
  updateTags(...)
  updateLinks(...)
```

Domain types stay pure Dart. They do not know about KGQL, AppFlowy Editor,
Riverpod, or Flutter widgets.

## Data layer

KGQL knowledge lives in `data/`.

`KgqlEssayRepository` should:

- use `personalDomainIdProvider` through `data/providers.dart`;
- request `Essay` with `document`, `json_document`, tags, links, and
  snapshot summary fields;
- create/update live `Essay` rows through `set_kgql_models`;
- create `EssaySnap` rows and link them with `has_snapshot`;
- query tags through KGQL tag filters;
- expose Ref-free constructor dependencies, following `nx_time` and
  `nx_projects`.

`EssayDocumentCodec` isolates editor serialization:

```text
EssayDocumentCodec
  initialJson()
  plainTextFromJson(json)
  editorDocumentFromJson(json)
  jsonFromEditorDocument(document)
```

AppFlowy Editor and any JSON helper package should only be referenced
behind this codec and the editor feature. This keeps the persistence
shape stable if the editor serialization library changes.

## Responsive shell

Use the `nx_projects` dual-shell pattern.

`router.dart` exposes a root route that chooses desktop or mobile by
viewport width:

```text
NotesRootShell
  if desktop -> DesktopShell
  else       -> MobileShell
```

Desktop and mobile share repositories, domain types, and view-model
logic where possible. They differ in chrome and navigation model.

## Desktop UX

Desktop is a workspace:

```text
sidebar + editor tabs + editor + inspector + result overlay
```

Sidebar:

- two tabs: `Essays` and `Tags`;
- `Essays`: search, Recent 5, Pinned 5, saved views;
- `Tags`: tag systems and hierarchical tag tree;
- sidebar stays visible when results are open.

Result overlay:

- fills the whole workspace to the right of the sidebar;
- covers tabs, editor, and inspector;
- lists matching essays for search/tag/recent/pinned;
- selecting a row opens or reuses an essay tab.

Tabs:

- desktop only;
- each tab owns its own optional `EssayResultContext`;
- closing tabs must keep at least one editor tab open.

Context bar:

- shown below the toolbar when the active tab has a result context;
- `Back to Topic: Technical` reopens the same result overlay;
- previous/next walks that tab's result set.

Inspector:

- details, tags, links, and history for the active essay;
- no inspector on mobile.

## Mobile UX

Mobile is stack-based and opens one note at a time:

```text
Home/Search/Tags -> Results -> Editor -> Bottom sheets
```

Bottom navigation:

- `Essays`
- `Tags`
- `Search`

Editor:

- no tabs;
- top app bar with back and overflow menu;
- optional `Back to <results>` context bar;
- details, links, and history appear as bottom sheets.

Back behavior:

- from editor opened through a result set, back returns to that result
  list;
- from editor opened directly, back returns to the previous home tab.

## Auth and router

Follow the existing apps:

- `main.dart`: `ProviderScope(child: NexusNotesApp())`
- `app.dart`: `MaterialApp.router`
- `router.dart`: `GoRouter` listening to `authProvider`
- unauthenticated users go to `/login`

Initial route should be `/notes`.

## Testing

Minimum tests:

```text
test/layering/no_flutter_in_domain_test.dart
test/layering/no_nx_db_in_features_test.dart

test/domain/essay/essay_test.dart
test/domain/essay/essay_query_test.dart

test/data/essay/essay_mapper_test.dart
test/data/essay/kgql_essay_repository_test.dart
test/data/editor/essay_document_codec_test.dart

test/features/editor/essay_editor_view_model_test.dart
test/widget/desktop_workspace_test.dart
test/widget/mobile_navigation_stack_test.dart
```

The first implementation can use fake repositories for feature/widget
tests. KGQL repository tests should use mocked GraphQL clients or a
small integration fixture once the backend model types exist.
