/// Parsed necklace battery sample from GATT read.
class BatteryData {
  final int percentage;
  final double voltage;
  final bool isCharging;

  BatteryData({
    required this.percentage,
    required this.voltage,
    required this.isCharging,
  });
}
