# Model Types — Implementation Plan

Reference mocks:
- `reference/navigator/model-types.html` — tree list with search, expand/collapse, badges
- `reference/navigator/model-type-detail.html` — read-only type inspector (Person example)

---

## Current State

### What exists
| Area | File(s) | Status |
|------|---------|--------|
| List screen | `navigator_screen.dart` | Working tree with expand/collapse, menu popup, `ExpandingFabMenu` |
| Row widget | `screens/navigator/widgets/model_type_row.dart` | Card + ListTile with settings gear; no badges, no icons |
| Routing | `router.dart` | Has `/models/:id`, `/model-type-form`; missing `/model-type/:id` detail route |
| Data model | `nx_db/.../ModelType.dart` | Full: parent, children, traits, attributes, relations, tagSystems |
| Provider | `nx_db/.../model_types_provider.dart` | `modelTypesProvider` (list), `modelTypeProvider(id)` (single with full struct) |

### What's broken / missing
- `navigator_screen.dart` line 126 pushes `/model-type-settings/${id}` — route doesn't exist in `router.dart`
- No `ModelTypeDetailScreen` (read-only inspector)
- No search / filter on the list
- Row widget doesn't match mock (no folder/box icons, no typeKind badges, no connector lines)
- `RelationshipType.fromJson` hardcodes `multiplicity: null` and `description: null` — check if API provides them
- No way to resolve relation target name → id for navigation on the detail screen

---

## Tasks

### 1. Add `/model-type/:id` route + `ModelTypeDetailScreen` scaffold

**Files:**
- EDIT `lib/router.dart` — add route, import new screen
- NEW `lib/screens/navigator/model_type_detail_screen.dart`

**Route:**
```
GoRoute(
  path: '/model-type/:modelTypeId',
  builder: (context, state) {
    final modelTypeId = int.parse(state.pathParameters['modelTypeId']!);
    return ModelTypeDetailScreen(modelTypeId: modelTypeId);
  },
),
```

**Screen structure** (`ConsumerWidget` watching `modelTypeProvider(modelTypeId)`):
- AppBar: back button, title = `modelType.name`, edit IconButton → `context.push('/model-type-form?modelTypeId=$id')`
- Body: `ListView` with sections (each a widget or inline):

#### 1a. Meta row
- `typeKind` chip (`base` / `abstract` / `trait`) with orange-50 bg + orange-600 text
- "Parent: {name}" as tappable text → `context.push('/model-type/${parent.id}')` (only if `parent != null`)

#### 1b. Description
- `modelType.description` in `bodyMedium` style, or omit section if null/empty

#### 1c. Traits section
- Section header: "TRAITS" (uppercase, `AppColors.gray400`, tracking-wider)
- For each trait in `modelType.traits`: card row with tag icon, trait name, chevron-right → `context.push('/model-type/${trait.id}')`
- Omit section if `traits` is null or empty

#### 1d. Attributes section
- Section header: "ATTRIBUTES"
- White card with dividers between rows
- Each row: attribute `key` (left), `valueType` chip (gray bg), optional "required" label (orange text, right)
- Omit section if `attributes` is null or empty

#### 1e. Inherited attributes section
- Section header: "INHERITED ATTRIBUTES from {parent.name}"
- Same layout as attributes but wrapped in `Opacity(opacity: 0.6)`
- Source: `ref.watch(modelTypeProvider(modelType.parentId!))` → use its `.attributes`
- Only show if `parentId != null`; handle loading/error gracefully (show nothing while loading)

#### 1f. Relations section
- Section header: "RELATIONS"
- Each relation as a card:
  - Row: target name (from `relation.link`), arrow icon, multiplicity chip (if non-null)
  - Description text (if non-null)
  - "via trait {traitName}" in italic purple (requires matching — skip for v1 unless API provides it)
  - Relation attributes: "Relation attrs:" label + chips for each `RelationAttributeDefinition` showing `key · valueType`
- Tap card → navigate to target type detail (see task 4 for name→id resolution)
- Omit section if `relations` is null or empty

#### 1g. Tag systems section
- Section header: "TAG SYSTEMS"
- Each `TagSystem` as a card:
  - Row: system name, chips for `selectionMode` ("exclusive"/"multiple") and structure ("flat"/"hierarchical" based on `isHierarchical`)
  - Below: wrap of `TagNode` leaf names as chips (`gray-100 bg, gray-600 text, rounded-lg`)
- Omit section if `tagSystems` is null or empty

---

### 2. Fix navigation in `NavigatorHomeScreen`

**File:** EDIT `lib/screens/navigator_screen.dart`

Changes:
- Line 122-127: change tap behavior — all types navigate to `/model-type/${modelType.id}` (the new detail screen). The detail screen will have a "View instances" action for base types.
- Remove the `/model-type-settings/` dead path.
- Replace `ExpandingFabMenu` with a single `FloatingActionButton` (orange, plus icon) → `context.push('/model-type-form')` to match the mock. Keep the `invalidate(modelTypesProvider)` on pop result.

---

### 3. Restyle `ModelTypeRow` to match mock

**File:** EDIT `lib/screens/navigator/widgets/model_type_row.dart`

Changes — replace Card/ListTile with flat row matching the HTML:

For **parent/abstract** rows:
- Leading chevron (down when expanded, right when collapsed) — toggles on tap of chevron area
- Folder icon (`Icons.folder_outlined`) in orange-500
- Name in `font-medium gray-900`
- Trailing badge chip: "abstract" (gray text, gray-100 bg, rounded-md)
- Top border divider between groups (except first)
- Row tap → expand/collapse (same as chevron)

For **child/base** rows:
- Indented (`pl-10` equivalent = 40px left padding)
- Short horizontal line connector (`Container` width 24, height 1, gray-200)
- Box icon (`Icons.check_box_outline_blank` or `Icons.crop_square`) in orange-400
- Name in `gray-800`
- Trailing badge: "base" chip
- Row tap → navigate to detail

Remove the settings gear button entirely — editing happens from the detail screen.

Update constructor: remove `onSettingsTap` (required → optional or removed), add `isChild` bool to toggle between parent/child styling.

---

### 4. Add search bar to `NavigatorHomeScreen`

**File:** EDIT `lib/screens/navigator_screen.dart`

- Add a `TextEditingController _searchController` and `String _searchQuery` state
- Insert search bar between AppBar and list (match mock: gray-100 bg, rounded-xl, search icon, "Search types..." placeholder)
- Filter logic: for each root model type, include it if its name or any descendant's name contains the query (case-insensitive). If a parent matches, show all children. If only a child matches, show the parent (collapsed to just the matching child).
- When search is active, auto-expand matching parent groups.

---

### 5. Resolve relation target name → id for navigation

**File:** NEW or extend provider

The detail screen needs to navigate from a relation's `link` (which is a target model type **name**) to `/model-type/:id`. Options:

** Build a `Map<String, int>` from `modelTypesProvider` data (walk the tree once). Create a simple derived provider:
```dart
final modelTypeNameToIdProvider = Provider<Map<String, int>>((ref) {
  final typesAsync = ref.watch(modelTypesProvider);
  return typesAsync.whenOrNull(data: (types) {
    final map = <String, int>{};
    void walk(List<ModelType> list) {
      for (final t in list) {
        map[t.name] = t.id;
        if (t.children != null) walk(t.children!);
      }
    }
    walk(types);
    return map;
  }) ?? {};
});
```

Place in `model_types_provider.dart` (nx_db) 


---

### 6. Extend `RelationshipType` parsing (data hardening)

**File:** EDIT `nx_db/lib/src/models/ModelType.dart` lines 127-133

Check actual API response for `multiplicity` and `description` fields. If present under different keys (e.g. `cardinality`), parse them. Current code hardcodes both to `null`.

Suggested fix (assuming API does return them):
```dart
multiplicity: rel['multiplicity'] as String? ?? rel['cardinality'] as String?,
description: rel['description'] as String?,
```

If the API truly doesn't return them, leave as-is and note that the detail screen won't show multiplicity/description until the backend is updated.

---

## File Summary

| Action | Path |
|--------|------|
| NEW | `lib/screens/navigator/model_type_detail_screen.dart` |
| EDIT | `lib/router.dart` |
| EDIT | `lib/screens/navigator_screen.dart` |
| EDIT | `lib/screens/navigator/widgets/model_type_row.dart` |
| MAYBE EDIT | `nx_db/lib/src/models/ModelType.dart` (relation parsing) |
| MAYBE NEW | Provider for name→id mapping (in nx_db or nx_main) |

## Suggested Order

1 → 2 → 3 → 6 → 5 → 1 (detail sections) → 4

Start with routing and a skeleton detail screen (task 1 scaffold + task 2 navigation fix) so the app is immediately navigable. Then restyle the list rows (task 3). Then harden data (task 6) and add name resolution (task 5) before fleshing out the detail sections. Search (task 4) is independent and can be done anytime.
