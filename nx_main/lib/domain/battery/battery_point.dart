/// One battery sample from GET /battery/day.
class BatteryPoint {
  const BatteryPoint({
    required this.timeHms,
    required this.percent,
    required this.voltageMv,
    required this.charging,
  });

  final String timeHms;
  final int percent;
  final int voltageMv;
  final bool charging;
}
