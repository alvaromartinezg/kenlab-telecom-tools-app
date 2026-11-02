import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenlab_telecom_tools/core/sensors/device_level_math.dart';

void main() {
  test('reports zero when a level device is horizontal or upright', () {
    expect(
      DeviceLevelMath.sideAngleDegrees(gravityX: 0, gravityZ: 9.81),
      closeTo(0, .001),
    );
    expect(
      DeviceLevelMath.tiltAngleDegrees(gravityY: 9.81, gravityZ: 0),
      closeTo(0, .001),
    );
  });

  test('reports the device tilt from gravity components', () {
    const degrees = 6.25;
    final radians = degrees * math.pi / 180;
    expect(
      DeviceLevelMath.sideAngleDegrees(
        gravityX: 9.81 * math.sin(radians),
        gravityZ: 9.81 * math.cos(radians),
      ),
      closeTo(degrees, .001),
    );
    expect(
      DeviceLevelMath.tiltAngleDegrees(
        gravityY: 9.81 * math.cos(radians),
        gravityZ: -9.81 * math.sin(radians),
      ),
      closeTo(degrees, .001),
    );
  });

  test('does not invent an angle when gravity data is absent', () {
    expect(
        DeviceLevelMath.sideAngleDegrees(gravityX: null, gravityZ: 0), isNull);
    expect(DeviceLevelMath.tiltAngleDegrees(gravityY: 0, gravityZ: 0), isNull);
  });
}
