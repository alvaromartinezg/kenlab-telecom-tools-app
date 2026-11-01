import 'package:flutter_test/flutter_test.dart';
import 'package:kenlab_telecom_tools/features/mw_alignment/domain/link_calculator.dart';

void main() {
  test('calculates a roughly eastward link bearing and distance', () {
    final link = LinkGeometry.between(
      fromLatitude: 0,
      fromLongitude: 0,
      toLatitude: 0,
      toLongitude: 1,
    );

    expect(link.bearingDegrees, closeTo(90, 0.01));
    expect(link.distanceMeters, closeTo(111195, 100));
  });

  test('calculates positive upward tilt from confirmed antenna heights', () {
    final tilt = LinkGeometry.tiltDegrees(
      distanceMeters: 1000,
      fromGroundMeters: 100,
      fromAntennaHeightMeters: 10,
      toGroundMeters: 120,
      toAntennaHeightMeters: 10,
    );

    expect(tilt, closeTo(1.145, 0.01));
  });

  test('parses signed coordinates copied from a Google Maps URL', () {
    final coordinate = LinkGeometry.parseCoordinatePair(
      'https://maps.google.com/?q=-34.603722, -58.381592',
    );

    expect(coordinate?.latitude, -34.603722);
    expect(coordinate?.longitude, -58.381592);
  });

  test('parses Unicode minus and rejects out-of-range coordinates', () {
    expect(LinkGeometry.parseCoordinatePair('−34.6, −58.3')?.latitude, -34.6);
    expect(LinkGeometry.parseCoordinatePair('91, 0'), isNull);
  });
}
