/// `Feature.ideation_status` in KGQL — matches
/// [servers/pgdb/admin_functions/setup_model_types.py] enum
/// `idea` | `considering` | `approved` | `rejected`.
enum IdeationStatus {
  idea,
  considering,
  approved,
  rejected;

  /// String stored in the database.
  String get dbValue => name;

  /// Reference-style row labels in the app UI.
  String get displayLabel {
    return switch (this) {
      IdeationStatus.idea => 'Ideated',
      IdeationStatus.considering => 'Refined',
      IdeationStatus.approved => "Spec'd",
      IdeationStatus.rejected => 'Rejected',
    };
  }

  static IdeationStatus? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return switch (raw) {
      'idea' => IdeationStatus.idea,
      'considering' => IdeationStatus.considering,
      'approved' => IdeationStatus.approved,
      'rejected' => IdeationStatus.rejected,
      _ => null,
    };
  }
}
