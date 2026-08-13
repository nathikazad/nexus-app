class GpsPoint {
  const GpsPoint({
    required this.timeHms,
    required this.timeIso,
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    this.altitudeM,
    this.speedMps,
    this.headingDeg,
    this.isMocked,
  });

  final String timeHms;
  final String timeIso;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final double? altitudeM;
  final double? speedMps;
  final double? headingDeg;
  final bool? isMocked;
}
