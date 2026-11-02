import 'dart:math' as math;

class DeviceLevelMath {
  const DeviceLevelMath._();

  static double? sideAngleDegrees({double? gravityX, double? gravityZ}) {
    if (gravityX == null ||
        gravityZ == null ||
        gravityX.abs() + gravityZ.abs() < 1) {
      return null;
    }
    return math.atan2(gravityX, gravityZ.abs()) * 180 / math.pi;
  }

  static double? tiltAngleDegrees({double? gravityY, double? gravityZ}) {
    if (gravityY == null ||
        gravityZ == null ||
        gravityY.abs() + gravityZ.abs() < 1) {
      return null;
    }
    return math.atan2(-gravityZ, gravityY.abs()) * 180 / math.pi;
  }
}
