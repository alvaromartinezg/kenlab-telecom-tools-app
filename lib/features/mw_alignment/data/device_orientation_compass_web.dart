import 'dart:async';
import 'dart:js_interop';

@JS('kenlabCompass.requestPermission')
external JSPromise<JSString> _requestCompassPermission();

@JS('kenlabCompass.start')
external void _startCompass(JSFunction callback);

@JS('kenlabCompass.stop')
external void _stopCompass();

class DeviceOrientationReading {
  const DeviceOrientationReading({
    this.headingDegrees,
    this.tiltDegrees,
    this.lateralDegrees,
    this.absoluteHeading = false,
    this.gravityX,
    this.gravityY,
    this.gravityZ,
  });

  final double? headingDegrees;
  final double? tiltDegrees;
  final double? lateralDegrees;
  final bool absoluteHeading;
  final double? gravityX;
  final double? gravityY;
  final double? gravityZ;
}

class DeviceOrientationCompass {
  final _readings = StreamController<DeviceOrientationReading>.broadcast();
  bool _started = false;

  Future<bool> requestPermission() async {
    final result = (await _requestCompassPermission().toDart).toDart;
    return result == 'granted';
  }

  Stream<DeviceOrientationReading> start() {
    if (_started) return _readings.stream;
    _started = true;
    final callback = ((
      JSNumber? heading,
      JSNumber? beta,
      JSNumber? gamma,
      JSBoolean absolute,
      JSNumber? gravityX,
      JSNumber? gravityY,
      JSNumber? gravityZ,
    ) {
      if (!_started || _readings.isClosed) return;
      final headingValue = heading?.toDartDouble;
      final betaValue = beta?.toDartDouble;
      final gammaValue = gamma?.toDartDouble;
      final gravityXValue = gravityX?.toDartDouble;
      final gravityYValue = gravityY?.toDartDouble;
      final gravityZValue = gravityZ?.toDartDouble;
      _readings.add(DeviceOrientationReading(
        headingDegrees:
            headingValue != null && headingValue.isFinite ? headingValue : null,
        // beta/gamma remain a fallback; the accelerometer gravity vector is
        // preferred for the level and tilt measurements.
        tiltDegrees: betaValue != null && betaValue.isFinite ? betaValue : null,
        lateralDegrees:
            gammaValue != null && gammaValue.isFinite ? gammaValue : null,
        absoluteHeading: absolute.toDart,
        gravityX: gravityXValue != null && gravityXValue.isFinite
            ? gravityXValue
            : null,
        gravityY: gravityYValue != null && gravityYValue.isFinite
            ? gravityYValue
            : null,
        gravityZ: gravityZValue != null && gravityZValue.isFinite
            ? gravityZValue
            : null,
      ));
    }).toJS;
    _startCompass(callback);
    return _readings.stream;
  }

  void stop() {
    if (!_started) return;
    _started = false;
    _stopCompass();
  }
}
