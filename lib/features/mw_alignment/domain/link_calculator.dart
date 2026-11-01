import 'dart:math' as math;

class LinkGeometry {
  const LinkGeometry(
      {required this.distanceMeters, required this.bearingDegrees});

  final double distanceMeters;
  final double bearingDegrees;

  static ({double latitude, double longitude})? parseCoordinatePair(
    String input,
  ) {
    final normalized = input.replaceAll(RegExp('[−–—]'), '-');
    final match = RegExp(
      r'([-+]?\d{1,2}(?:\.\d+)?)\s*[,;]\s*([-+]?\d{1,3}(?:\.\d+)?)',
    ).firstMatch(normalized);
    if (match == null) return null;
    final latitude = double.tryParse(match.group(1)!);
    final longitude = double.tryParse(match.group(2)!);
    if (latitude == null ||
        longitude == null ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return (latitude: latitude, longitude: longitude);
  }

  static LinkGeometry between({
    required double fromLatitude,
    required double fromLongitude,
    required double toLatitude,
    required double toLongitude,
  }) {
    const earthRadiusMeters = 6371008.8;
    final lat1 = _radians(fromLatitude);
    final lat2 = _radians(toLatitude);
    final deltaLat = lat2 - lat1;
    final deltaLon = _radians(toLongitude - fromLongitude);
    final haversine = math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLon / 2), 2);
    final distance = earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
    final y = math.sin(deltaLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLon);
    final bearing = (_degrees(math.atan2(y, x)) + 360) % 360;
    return LinkGeometry(distanceMeters: distance, bearingDegrees: bearing);
  }

  static double tiltDegrees({
    required double distanceMeters,
    required double fromGroundMeters,
    required double fromAntennaHeightMeters,
    required double toGroundMeters,
    required double toAntennaHeightMeters,
  }) {
    final rise = toGroundMeters +
        toAntennaHeightMeters -
        fromGroundMeters -
        fromAntennaHeightMeters;
    return _degrees(math.atan2(rise, distanceMeters));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
  static double _degrees(double radians) => radians * 180 / math.pi;
}
