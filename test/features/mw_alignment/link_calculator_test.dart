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
}
