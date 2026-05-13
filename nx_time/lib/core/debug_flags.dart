/// Optional verbose tracing for action mapping / umbrella fold.
///
/// Enable when debugging:
/// `flutter run --dart-define=NX_TIME_TRACE_ACTION=true`
/// or add the same `--dart-define` to test runs.
const bool kNxTimeTraceActionSemantics = bool.fromEnvironment(
  'NX_TIME_TRACE_ACTION',
  defaultValue: false,
);
