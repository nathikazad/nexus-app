// Stats dashboard: which tag systems and relation breakdowns to show.
//
// This is intentionally DB / deployment specific. When your KGQL schema uses
// different names, edit the sets below — the rest of the app still loads
// the full schema elsewhere.

/// Tag system names (`TagSystem.name`) that get a distribution pie on Stats.
const Set<String> statsDashboardTagSystemNames = {
  'Spending Category',
};

/// Relation target type names (e.g. `Company.name` group key) for Stats pies.
const Set<String> statsDashboardRelationTypeNames = {
  'Company',
};
