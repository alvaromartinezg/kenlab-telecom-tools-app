class SiteProfileInput {
  const SiteProfileInput({
    required this.latitude,
    required this.longitude,
    required this.antennaHeightMeters,
  });

  final double latitude;
  final double longitude;
  final double antennaHeightMeters;

  Map<String, Object> toJson() => {
        'lat': latitude,
        'long': longitude,
        'height_m': antennaHeightMeters,
      };
}

class LinkProfileRequest {
  const LinkProfileRequest({required this.siteA, required this.siteB});

  final SiteProfileInput siteA;
  final SiteProfileInput siteB;

  Map<String, Object> toJson() => {
        'site_a': siteA.toJson(),
        'site_b': siteB.toJson(),
      };
}

class TerrainProfilePoint {
  const TerrainProfilePoint({
    required this.distanceMeters,
    required this.terrainAltitudeMeters,
    this.lineOfSightAltitudeMeters,
    this.fresnelRadiusMeters,
  });

  final double distanceMeters;
  final double terrainAltitudeMeters;
  final double? lineOfSightAltitudeMeters;
  final double? fresnelRadiusMeters;

  factory TerrainProfilePoint.fromJson(Map<String, dynamic> json) =>
      TerrainProfilePoint(
        distanceMeters: _number(json, 'distance_m'),
        terrainAltitudeMeters: _number(json, 'terrain_altitude_m'),
        lineOfSightAltitudeMeters:
            _optionalNumber(json, 'line_of_sight_altitude_m'),
        fresnelRadiusMeters: _optionalNumber(json, 'fresnel_radius_m'),
      );
}

class LinkProfile {
  const LinkProfile({
    required this.distanceMeters,
    required this.azimuthADegrees,
    required this.azimuthBDegrees,
    required this.siteAGroundAltitudeMeters,
    required this.siteBGroundAltitudeMeters,
    required this.tiltADegrees,
    required this.tiltBDegrees,
    required this.profile,
  });

  final double distanceMeters;
  final double azimuthADegrees;
  final double azimuthBDegrees;
  final double siteAGroundAltitudeMeters;
  final double siteBGroundAltitudeMeters;
  final double tiltADegrees;
  final double tiltBDegrees;
  final List<TerrainProfilePoint> profile;

  factory LinkProfile.fromJson(Map<String, dynamic> json) => LinkProfile(
        distanceMeters: _number(json, 'distance_m'),
        azimuthADegrees: _number(json, 'azimuth_a_deg'),
        azimuthBDegrees: _number(json, 'azimuth_b_deg'),
        siteAGroundAltitudeMeters: _number(json, 'site_a_ground_altitude_m'),
        siteBGroundAltitudeMeters: _number(json, 'site_b_ground_altitude_m'),
        tiltADegrees: _number(json, 'tilt_a_deg'),
        tiltBDegrees: _number(json, 'tilt_b_deg'),
        profile: ((json['profile'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TerrainProfilePoint.fromJson)
            .toList(growable: false),
      );
}

double _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('La respuesta no incluye el valor numérico "$key".');
}

double? _optionalNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is num ? value.toDouble() : null;
}
