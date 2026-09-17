# NX Expense navigation

Navigation and Order details use the same routes on mobile and desktop. Desktop
adds source panes around the active route. It no longer keeps an independent
expense selection, transaction selection, tab index, or third-panel stack.

## Navigation contract

- Use `navPush(context, location)` for app page navigation. It records the source
  URI in `from`, including the source filter and date parameters.
- Each pane has a `NavigationLocation`. A click in a source pane uses that pane's
  location, not the rightmost page's location.
- Use `navBack` for pages. It pops active route history when available and falls
  back to the saved source or owning section for a direct link. Source-pane Back
  navigates to that pane's parent. Dialogs and image viewers retain Navigator pop.
- Section navigation selects an explicit root route. Mobile bottom navigation
  contains Expenses, Stats, Budget, and Bank. Orders, Tags, and Images open from
  the top-right menu and retain Back navigation; desktop keeps its section rail.
  The new-expense action is a plus icon with an accessible tooltip.
- At widths below 1100, show the current page. At desktop widths, show the section
  list, an eligible immediate source page, and the current page. Forms and link
  pickers are never recreated as source panes. Resizing keeps the current route.
- Transaction destinations carry both event ID and event timestamp. Their detail
  query uses that composite identity, independently of list date filters. Linking
  and unlinking refresh the detail provider and affected lists on both layouts.
- Relation and tag labels are decoded once. Date-only drilldown URLs supply a
  one-day filter even without explicit range query parameters.
- Authentication preserves a requested internal destination through login. A
  change between authenticated domain/server/user sessions resets to Expenses.

## Order details

Expense Order relations open `/orders/:id`. Other relations open related expense
lists. Order detail provides saved source-order links, product links and images,
quantities, unit prices, line totals, tax/status/delivery information when saved,
and related expense navigation for the Order and individual products.

Explicit line totals win; otherwise calculate unit price × quantity (default 1).
Missing prices remain unknown. Relation-specific product assets fall back to
Product attributes. Only HTTP(S) URLs with a host are launched; failed launches
show an error without leaving the page. Order loading, missing, and failure states
retain Back navigation; failures offer retry.

## Verification

Tests cover mobile and desktop expense → Order → Back; actual list panes at the
1100 breakpoint; window resize; direct and invalid links; transaction → expense →
Back; launching saved URLs; model mapping and quantity totals; exact transaction
identity lookup; and scoped tag/date route parameters. Existing tests also cover
forms, product rendering, link payloads, data caches, and domain gating.

Live database tests require the separately configured integration environment.
This change does not migrate to NX Sync/AppDataHost, change server schemas, or
perform a device installation. Offline consistency and queued-write behavior
remain the next phase.

## Visual design and motion

Desktop uses a dark navigation rail and rounded white panels on a slate canvas.
Teal selection indicators and the Order total header provide visual hierarchy.
Product cards move prices/actions below their text in narrow panes. Inter's four
used weights are bundled with their OFL license for consistent rendering.

`ExpenseMotion.page` owns route transitions: a 280 ms eased fade/short slide on
entry and a 200 ms reverse. Compact iOS uses Cupertino routes to preserve native
swipe-back. Source panes enter without keeping duplicate outgoing forms alive.
Expense and Order cards provide a small desktop hover lift. Reduced-motion or
accessible-navigation settings disable custom movement and page transitions.
Amounts are never counted up or animated through misleading intermediate values.

`expense_motion_test.dart` checks forward/back navigation, reduced-motion pages,
and the native iOS route. The navigation journey suite uses the production page
transitions. Set `NX_PREVIEW_DIR` when running that suite to save rendered phone
and desktop previews using fixture data.

## Expense images

`/images` lists timeline events with `eventType: image`, `source: expense_app`,
newest first, independently of the expense date range. Cursor pagination loads
older uploads. All / Unlinked / Linked describe Expense or Order attachments,
not whether reconciliation has completed. Existing expense-app bill uploads are
included. Events from other image sources are not included.

Add image uploads through the existing authenticated `/snapshots` endpoint and
creates no model or model link. Camera is offered on iOS/Android; library selection
is available on supported platforms. Uploads are bound to the selected session,
and success refreshes the gallery. Uploading from Linked switches to Unlinked so
the new image is visible. Bill attachment changes refresh image-link status too.

`/images/:id?time=...` resolves the full timeline identity, shows a zoomable image,
and opens a full-screen viewer. Expense/Order attachments navigate to their detail
pages. Dates label upload time, not the purchase date. No OCR or reconciliation
mutation is performed by this screen. The feature requires connectivity.
