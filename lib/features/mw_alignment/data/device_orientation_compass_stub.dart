import 'dart:async';

class DeviceOrientationReading {
  const DeviceOrientationReading({
    this.headingDegrees,
    this.tiltDegrees,
    this.lateralDegrees,
    this.absoluteHeading = false,
  });

  final double? headingDegrees;
  final double? tiltDegrees;
  final double? lateralDegrees;
  final bool absoluteHeading;
}

class DeviceOrientationCompass {
  Future<bool> requestPermission() async => true;

  Stream<DeviceOrientationReading> start() => const Stream.empty();

  void stop() {}
}
