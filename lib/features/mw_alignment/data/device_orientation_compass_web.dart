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
  });

  final double? headingDegrees;
  final double? tiltDegrees;
  final double? lateralDegrees;
  final bool absoluteHeading;
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
    ) {
      if (!_started || _readings.isClosed) return;
      final headingValue = heading?.toDartDouble;
      final betaValue = beta?.toDartDouble;
      final gammaValue = gamma?.toDartDouble;
      _readings.add(DeviceOrientationReading(
        headingDegrees:
            headingValue != null && headingValue.isFinite ? headingValue : null,
        // DeviceOrientation beta is 0° with the screen face-up and about 90°
        // with the phone upright; subtracting 90° gives deviation from vertical.
        tiltDegrees:
            betaValue != null && betaValue.isFinite ? betaValue - 90 : null,
        lateralDegrees:
            gammaValue != null && gammaValue.isFinite ? gammaValue : null,
        absoluteHeading: absolute.toDart,
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
