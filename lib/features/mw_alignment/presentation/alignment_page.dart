import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/location/elevation_service.dart';
import '../data/device_orientation_compass.dart';
import '../../mw_profile/data/mw_profile_api.dart';
import '../../mw_profile/models/link_profile.dart';
import '../../mw_profile/presentation/link_profile_chart.dart';
import '../domain/link_calculator.dart';

enum _GuidedStep { lateral, tilt, azimuth, fine }

class AlignmentPage extends StatefulWidget {
  const AlignmentPage({super.key});

  @override
  State<AlignmentPage> createState() => _AlignmentPageState();
}

class _AlignmentPageState extends State<AlignmentPage> {
  static const _lateralTolerance = 1.5;
  static const _tiltTolerance = 1.0;
  static const _azimuthTolerance = 2.0;

  CameraController? _camera;
  Position? _siteA;
  AccelerometerEvent? _acceleration;
  MagnetometerEvent? _magneticField;
  double? _heading;
  double? _webTilt;
  double? _webLateral;
  bool _requestingCompass = false;
  bool _compassPermissionGranted = false;
  String? _compassError;
  bool _loadingCamera = true;
  bool _useInclinometer = true;
  bool _connectionMode = false;
  String? _error;
  double? _siteBGroundAltitude;
  bool _loadingElevation = false;
  String? _elevationError;
  Timer? _elevationDebounce;
  Timer? _profileDebounce;
  LinkProfile? _profile;
  bool _profileLoading = false;
  String? _profileError;
  int _profileRequestNumber = 0;
  _GuidedStep? _guidedStep;
  final _guidedCaptureKey = GlobalKey();
  final _orientationCompass = DeviceOrientationCompass();
  StreamSubscription<AccelerometerEvent>? _accSubscription;
  StreamSubscription<MagnetometerEvent>? _magSubscription;
  StreamSubscription<DeviceOrientationReading>? _orientationSubscription;

  final _siteBLat = TextEditingController();
  final _siteBLon = TextEditingController();
  final _siteAAntennaHeight = TextEditingController(text: '0');
  final _siteBAntennaHeight = TextEditingController(text: '0');
  final _connectionCode = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _refreshLocation();
    _listenToSensors();
  }

  @override
  void dispose() {
    _camera?.dispose();
    _accSubscription?.cancel();
    _magSubscription?.cancel();
    _orientationSubscription?.cancel();
    _orientationCompass.stop();
    _siteBLat.dispose();
    _siteBLon.dispose();
    _elevationDebounce?.cancel();
    _profileDebounce?.cancel();
    _siteAAntennaHeight.dispose();
    _siteBAntennaHeight.dispose();
    _connectionCode.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty)
        throw Exception('No se encontró una cámara disponible.');
      final rear = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.back);
      final controller = CameraController(
        rear.isNotEmpty ? rear.first : cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _loadingCamera = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = 'Cámara: $error';
          _loadingCamera = false;
        });
    }
  }

  Future<void> _refreshLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Activa los servicios de ubicación.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
            'Permite ubicación para calcular el rumbo desde Site A.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted)
        setState(() {
          _siteA = position;
          _profile = null;
          _profileLoading = false;
          _profileError = null;
          _error = null;
        });
      _scheduleProfileRequest();
    } catch (error) {
      if (mounted)
        setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _listenToSensors() {
    // Generic Sensor's Magnetometer API is unavailable in mobile browsers.
    // The web implementation starts DeviceOrientation after a user grants it.
    if (kIsWeb) return;
    _accSubscription = accelerometerEventStream().listen((event) {
      _acceleration = event;
      _updateHeading();
      if (mounted) setState(() {});
    }, onError: (_) {});
    _magSubscription = magnetometerEventStream().listen((event) {
      _magneticField = event;
      _updateHeading();
    }, onError: (_) {});
  }

  void _updateHeading() {
    final acceleration = _acceleration;
    final magnetic = _magneticField;
    if (acceleration == null || magnetic == null) return;
    final magneticStrength = math.sqrt(magnetic.x * magnetic.x +
        magnetic.y * magnetic.y +
        magnetic.z * magnetic.z);
    if (magneticStrength < 1) return;
    final roll = math.atan2(acceleration.y, acceleration.z);
    final pitch = math.atan2(
      -acceleration.x,
      math.sqrt(
          acceleration.y * acceleration.y + acceleration.z * acceleration.z),
    );
    final horizontalX =
        magnetic.x * math.cos(pitch) + magnetic.z * math.sin(pitch);
    final horizontalY = magnetic.x * math.sin(roll) * math.sin(pitch) +
        magnetic.y * math.cos(roll) -
        magnetic.z * math.sin(roll) * math.cos(pitch);
    final degrees =
        (math.atan2(horizontalY, horizontalX) * 180 / math.pi + 360) % 360;
    if (mounted) setState(() => _heading = degrees);
  }

  Future<void> _enableCompass() async {
    if (_requestingCompass) return;
    setState(() {
      _requestingCompass = true;
      _compassError = null;
    });
    try {
      final granted = await _orientationCompass.requestPermission();
      if (!mounted) return;
      if (!granted) {
        setState(() {
          _requestingCompass = false;
          _compassPermissionGranted = false;
          _compassError =
              'No se autorizó la orientación. Permítela en Safari y vuelve a intentarlo.';
        });
        return;
      }
      await _orientationSubscription?.cancel();
      _orientationSubscription = _orientationCompass.start().listen(
        (reading) {
          if (!mounted) return;
          setState(() {
            if (reading.headingDegrees != null) {
              _heading = reading.headingDegrees;
            }
            _webTilt = reading.tiltDegrees;
            _webLateral = reading.lateralDegrees;
          });
        },
        onError: (Object error) {
          if (mounted)
            setState(() => _compassError = 'Sensor de orientación: $error');
        },
      );
      setState(() {
        _requestingCompass = false;
        _compassPermissionGranted = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _requestingCompass = false;
        _compassPermissionGranted = false;
        _compassError = 'No se pudo habilitar la brújula: $error';
      });
    }
  }

  LinkGeometry? get _geometry {
    final start = _siteA;
    final lat = double.tryParse(_siteBLat.text.trim().replaceAll('−', '-'));
    final lon = double.tryParse(_siteBLon.text.trim().replaceAll('−', '-'));
    if (start == null ||
        lat == null ||
        lon == null ||
        lat.abs() > 90 ||
        lon.abs() > 180) return null;
    return LinkGeometry.between(
      fromLatitude: start.latitude,
      fromLongitude: start.longitude,
      toLatitude: lat,
      toLongitude: lon,
    );
  }

  double? get _targetAzimuth =>
      _profile?.azimuthADegrees ?? _geometry?.bearingDegrees;
  double? get _targetDistance =>
      _profile?.distanceMeters ?? _geometry?.distanceMeters;

  double? get _tilt {
    final apiTilt = _profile?.tiltADegrees;
    if (apiTilt != null) return apiTilt;
    final start = _siteA;
    final endAltitude = _siteBGroundAltitude;
    final startHeight = double.tryParse(_siteAAntennaHeight.text.trim());
    final endHeight = double.tryParse(_siteBAntennaHeight.text.trim());
    final geometry = _geometry;
    if (start == null ||
        endAltitude == null ||
        startHeight == null ||
        endHeight == null ||
        startHeight < 0 ||
        endHeight < 0 ||
        geometry == null) {
      return null;
    }
    return LinkGeometry.tiltDegrees(
      distanceMeters: geometry.distanceMeters,
      fromGroundMeters: start.altitude,
      fromAntennaHeightMeters: startHeight,
      toGroundMeters: endAltitude,
      toAntennaHeightMeters: endHeight,
    );
  }

  double? get _lateralAngle {
    if (_webLateral != null) return _webLateral;
    final acceleration = _acceleration;
    if (acceleration == null) return null;
    // Use the gravity axis appropriate to the instructed phone orientation:
    // flat during lateral setup, upright during tilt and fine alignment.
    final upright = acceleration.y.abs() >= acceleration.z.abs();
    final across = upright ? acceleration.x : acceleration.y;
    final vertical = upright ? acceleration.y : acceleration.z;
    return math.atan2(across, vertical.abs()) * 180 / math.pi;
  }

  void _siteBCoordinatesChanged() {
    setState(() {
      _siteBGroundAltitude = null;
      _elevationError = null;
      _profile = null;
      _profileLoading = false;
      _profileError = null;
    });
    _elevationDebounce?.cancel();
    final lat = double.tryParse(_siteBLat.text.trim().replaceAll('−', '-'));
    final lon = double.tryParse(_siteBLon.text.trim().replaceAll('−', '-'));
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      _scheduleProfileRequest();
      return;
    }
    if (!const MwProfileApi().isConfigured) {
      _elevationDebounce = Timer(const Duration(milliseconds: 500), () {
        _fetchSiteBElevation(lat, lon);
      });
    }
    _scheduleProfileRequest();
  }

  void _scheduleProfileRequest() {
    _profileDebounce?.cancel();
    final requestNumber = ++_profileRequestNumber;
    final siteA = _siteA;
    final lat = double.tryParse(_siteBLat.text.trim().replaceAll('−', '-'));
    final lon = double.tryParse(_siteBLon.text.trim().replaceAll('−', '-'));
    final heightA = double.tryParse(_siteAAntennaHeight.text.trim());
    final heightB = double.tryParse(_siteBAntennaHeight.text.trim());
    if (!const MwProfileApi().isConfigured ||
        siteA == null ||
        lat == null ||
        lon == null ||
        heightA == null ||
        heightB == null ||
        heightA < 0 ||
        heightB < 0) {
      if (mounted && _profileLoading) {
        setState(() => _profileLoading = false);
      }
      return;
    }
    _profileDebounce = Timer(const Duration(milliseconds: 800), () {
      _requestProfile(siteA, lat, lon, heightA, heightB, requestNumber);
    });
  }

  void _profileInputsChanged() {
    setState(() {
      _profile = null;
      _profileError = null;
    });
    _scheduleProfileRequest();
  }

  Future<void> _requestProfile(
      Position siteA,
      double latitudeB,
      double longitudeB,
      double heightA,
      double heightB,
      int requestNumber) async {
    setState(() {
      _profileLoading = true;
      _profileError = null;
    });
    try {
      final profile =
          await const MwProfileApi().calculateProfile(LinkProfileRequest(
        siteA: SiteProfileInput(
            latitude: siteA.latitude,
            longitude: siteA.longitude,
            antennaHeightMeters: heightA),
        siteB: SiteProfileInput(
            latitude: latitudeB,
            longitude: longitudeB,
            antennaHeightMeters: heightB),
      ));
      if (!mounted || requestNumber != _profileRequestNumber) return;
      setState(() {
        _profile = profile;
        _siteBGroundAltitude = profile.siteBGroundAltitudeMeters;
        _profileLoading = false;
      });
    } catch (error) {
      if (!mounted || requestNumber != _profileRequestNumber) return;
      setState(() {
        _profileLoading = false;
        _profileError = error.toString();
      });
    }
  }

  Future<void> _fetchSiteBElevation(double latitude, double longitude) async {
    setState(() => _loadingElevation = true);
    try {
      final elevation = await const ElevationService().forCoordinate(
        latitude: latitude,
        longitude: longitude,
      );
      if (!mounted ||
          double.tryParse(_siteBLat.text.trim().replaceAll('−', '-')) !=
              latitude ||
          double.tryParse(_siteBLon.text.trim().replaceAll('−', '-')) !=
              longitude) return;
      setState(() {
        _siteBGroundAltitude = elevation;
        _loadingElevation = false;
        _elevationError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingElevation = false;
        _elevationError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pasteSiteBCoordinates() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final pair = LinkGeometry.parseCoordinatePair(clipboard?.text ?? '');
    if (pair == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Copia en Google Maps las coordenadas en formato latitud, longitud.')),
        );
      return;
    }
    _siteBLat.text = pair.latitude.toString();
    _siteBLon.text = pair.longitude.toString();
    _siteBCoordinatesChanged();
  }

  double _angularError(double measured, double target) =>
      ((measured - target + 540) % 360) - 180;

  double? get _azimuthError {
    final heading = _heading;
    final target = _targetAzimuth;
    if (heading == null || target == null) return null;
    return _angularError(heading, target);
  }

  bool get _lateralReady =>
      _lateralAngle != null && _lateralAngle!.abs() <= _lateralTolerance;
  bool get _tiltReady =>
      _pitch != null &&
      _tilt != null &&
      (_pitch! - _tilt!).abs() <= _tiltTolerance;
  bool get _azimuthReady =>
      _azimuthError != null && _azimuthError!.abs() <= _azimuthTolerance;
  bool get _fineAligned => _lateralReady && _tiltReady && _azimuthReady;

  void _startGuidedAlignment() {
    if (kIsWeb && !_compassPermissionGranted) unawaited(_enableCompass());
    setState(() => _guidedStep = _GuidedStep.lateral);
  }

  void _advanceGuidedAlignment() {
    final step = _guidedStep;
    if (step == _GuidedStep.lateral && _lateralReady) {
      setState(() => _guidedStep = _GuidedStep.tilt);
    } else if (step == _GuidedStep.tilt && _tiltReady) {
      setState(() => _guidedStep = _GuidedStep.azimuth);
    } else if (step == _GuidedStep.azimuth && _azimuthReady) {
      setState(() => _guidedStep = _GuidedStep.fine);
    }
  }

  Future<void> _captureGuidedStep() async {
    final step = _guidedStep;
    if (step == null) return;
    if (step != _GuidedStep.fine && !_stepReady(step)) {
      _showMessage('Ajusta los valores dentro de tolerancia antes de avanzar.');
      return;
    }
    final renderObject = _guidedCaptureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      _showMessage('No se pudo capturar esta pantalla. Inténtalo de nuevo.');
      return;
    }
    ui.Image? image;
    try {
      image = await renderObject.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw Exception('No se pudo codificar la captura PNG.');
      final now = DateTime.now();
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await FileSaver.instance.saveFile(
        name:
            'KenLab_${step.name}_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}',
        bytes: bytes,
        fileExtension: 'png',
        mimeType: MimeType.png,
      );
      if (!mounted) return;
      if (step != _GuidedStep.fine) _advanceGuidedAlignment();
      _showMessage(step == _GuidedStep.fine
          ? 'Captura de pantalla guardada.'
          : 'Captura guardada; avanzaste al siguiente paso.');
    } catch (error) {
      if (mounted) _showMessage('No se pudo guardar la captura: $error');
    } finally {
      image?.dispose();
    }
  }

  bool _stepReady(_GuidedStep step) => switch (step) {
        _GuidedStep.lateral => _lateralReady,
        _GuidedStep.tilt => _tiltReady,
        _GuidedStep.azimuth => _azimuthReady,
        _GuidedStep.fine => _fineAligned,
      };

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _azimuthReadout({bool dark = false}) {
    final primary = dark ? Colors.white : const Color(0xFF263746);
    final secondary = dark ? Colors.white70 : const Color(0xFF66736B);
    final errorColor = _azimuthReady
        ? const Color(0xFF198754)
        : (dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.black.withValues(alpha: .24)
            : const Color(0xFFF4F5F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        _azimuthValue('BRÚJULA', _heading, primary, secondary),
        _azimuthValue('OBJETIVO', _targetAzimuth, primary, secondary),
        _azimuthValue('DIFERENCIA', _azimuthError, errorColor, secondary,
            signed: true),
      ]),
    );
  }

  Widget _azimuthValue(
    String label,
    double? value,
    Color primary,
    Color secondary, {
    bool signed = false,
  }) =>
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: secondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .4)),
          const SizedBox(height: 2),
          Text(
            value == null
                ? '—°'
                : '${signed && value > 0 ? '+' : ''}${value.toStringAsFixed(1)}°',
            style: TextStyle(
                color: primary, fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ]),
      );

  Widget _guidedAlignmentCard() {
    final step = _guidedStep;
    if (step == null) {
      return FilledButton.icon(
        onPressed: _targetAzimuth == null ? null : _startGuidedAlignment,
        icon: const Icon(Icons.assistant_direction),
        label: const Text('Iniciar alineamiento guiado'),
      );
    }

    final (title, instruction, measured, target, tolerance, ready) =
        switch (step) {
      _GuidedStep.lateral => (
          '1 / 3 · Inclinación lateral',
          'Pon el teléfono acostado, pantalla hacia arriba, sobre una superficie horizontal del soporte. Ajusta el lateral a 0°.',
          _lateralAngle,
          0.0,
          _lateralTolerance,
          _lateralReady,
        ),
      _GuidedStep.tilt => (
          '2 / 3 · Tilt vertical',
          'Ahora coloca el teléfono parado, alineado con el eje de la antena. Ajusta el tilt calculado.',
          _pitch,
          _tilt,
          _tiltTolerance,
          _tiltReady,
        ),
      _GuidedStep.azimuth => (
          '3 / 3 · Azimut',
          'Mantén el teléfono parado y apunta su parte superior hacia el azimut objetivo.',
          _heading,
          _targetAzimuth,
          _azimuthTolerance,
          _azimuthReady,
        ),
      _GuidedStep.fine => (
          'Alineamiento fino',
          _fineAligned
              ? 'Valores dentro de las tolerancias beta. Confirma el nivel del radio antes de cerrar el trabajo.'
              : 'Ajusta lateral, tilt y azimut. El indicador solo se pondrá verde cuando los tres estén dentro de tolerancia.',
          null,
          null,
          0.0,
          _fineAligned,
        ),
    };

    final difference = measured == null || target == null
        ? null
        : step == _GuidedStep.azimuth
            ? _angularError(measured, target)
            : measured - target;
    final background = step == _GuidedStep.fine
        ? (_fineAligned ? const Color(0xFFE4F4E9) : const Color(0xFFFFECEC))
        : Colors.white;
    final accent = step == _GuidedStep.fine && _fineAligned
        ? const Color(0xFF198754)
        : const Color(0xFFC62828);

    return RepaintBoundary(
      key: _guidedCaptureKey,
      child: Card(
        margin: EdgeInsets.zero,
        color: background,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(
                  step == _GuidedStep.fine
                      ? Icons.center_focus_strong
                      : Icons.screen_rotation_alt,
                  color: accent),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: accent))),
              if (step != _GuidedStep.fine)
                IconButton(
                    onPressed: () => setState(() => _guidedStep = null),
                    tooltip: 'Salir de guía',
                    icon: const Icon(Icons.close)),
            ]),
            Text(instruction,
                style: const TextStyle(fontSize: 12, height: 1.35)),
            if (step == _GuidedStep.azimuth && kIsWeb) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _requestingCompass ? null : _enableCompass,
                icon: Icon(_compassPermissionGranted
                    ? Icons.explore
                    : Icons.explore_outlined),
                label: Text(_requestingCompass
                    ? 'Solicitando acceso…'
                    : _compassPermissionGranted
                        ? 'Volver a activar brújula'
                        : 'Permitir acceso a la brújula'),
              ),
              if (_compassError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(_compassError!,
                      style: const TextStyle(
                          color: Color(0xFF9B2C2C), fontSize: 11)),
                ),
            ],
            if (step == _GuidedStep.azimuth || step == _GuidedStep.fine) ...[
              const SizedBox(height: 10),
              _azimuthReadout(),
            ],
            if (step == _GuidedStep.fine) ...[
              const SizedBox(height: 10),
              _fineMetric(
                  'Lateral', _lateralAngle, _lateralTolerance, _lateralReady),
              _fineMetric(
                  'Tilt',
                  _pitch == null || _tilt == null ? null : _pitch! - _tilt!,
                  _tiltTolerance,
                  _tiltReady),
              _fineMetric(
                  'Azimut', _azimuthError, _azimuthTolerance, _azimuthReady),
              const SizedBox(height: 6),
              Text(
                  _fineAligned
                      ? 'LISTO PARA COMPROBACIÓN DEL RADIO'
                      : 'AJUSTE PENDIENTE',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: accent,
                      letterSpacing: .5)),
            ] else ...[
              const SizedBox(height: 10),
              Text(
                measured == null || target == null
                    ? 'Esperando sensor o valores objetivo…'
                    : 'Medido ${measured.toStringAsFixed(1)}°  ·  Objetivo ${target.toStringAsFixed(1)}°  ·  Error ${difference!.abs().toStringAsFixed(1)}° (±${tolerance.toStringAsFixed(1)}°)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: ready ? _captureGuidedStep : null,
                  icon: const Icon(Icons.screenshot_outlined),
                  label: const Text('Capturar pantalla y continuar'),
                ),
              ),
            ],
            if (step == _GuidedStep.fine) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _captureGuidedStep,
                  icon: const Icon(Icons.screenshot_outlined),
                  label: const Text('Guardar captura de pantalla'),
                ),
              ),
            ],
            const Text(
                'Tolerancias beta: lateral ±1.5°, tilt ±1°, azimut ±2°. La brújula puede desviarse por metal y no sustituye la lectura del radio.',
                style: TextStyle(fontSize: 10, color: Color(0xFF66736B))),
          ]),
        ),
      ),
    );
  }

  Widget _fineMetric(
          String label, double? error, double tolerance, bool ready) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(ready ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 17,
              color: ready ? const Color(0xFF198754) : const Color(0xFFC62828)),
          const SizedBox(width: 7),
          Expanded(
              child: Text(
                  '$label · ${error == null ? 'sensor no disponible' : 'error ${error.abs().toStringAsFixed(1)}° / ±${tolerance.toStringAsFixed(1)}°'}')),
        ]),
      );

  double? get _pitch {
    if (_webTilt != null) return _webTilt;
    final acceleration = _acceleration;
    if (acceleration == null) return null;
    final verticalGravity = acceleration.y;
    if (verticalGravity.abs() < .01 && acceleration.z.abs() < .01) return null;
    // With the phone upright, Y follows its long edge and Z is perpendicular
    // to the screen; this gives the phone's tilt away from vertical.
    return math.atan2(-acceleration.z, verticalGravity) * 180 / math.pi;
  }

  void _onConnect() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'La conexión en vivo requiere configurar el servidor de sesiones. Usa coordenadas manuales en esta beta.'),
      duration: Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final geometry = _geometry;
    final targetAzimuth = _targetAzimuth;
    final targetDistance = _targetDistance;
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alineación beta'),
        actions: [
          IconButton(
              tooltip: 'Actualizar GPS',
              onPressed: _refreshLocation,
              icon: const Icon(Icons.my_location)),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            flex: 5,
            child: Stack(fit: StackFit.expand, children: [
              if (camera != null && camera.value.isInitialized)
                ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: camera.value.previewSize!.height,
                      height: camera.value.previewSize!.width,
                      child: CameraPreview(camera),
                    ),
                  ),
                )
              else
                Container(
                  color: const Color(0xFF263746),
                  alignment: Alignment.center,
                  child: _loadingCamera
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _error ??
                              'Permite cámara para ver la imagen en vivo.',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center),
                ),
              if (geometry != null && _heading != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _BearingGuidePainter(
                        relativeBearing:
                            _heading == null || targetAzimuth == null
                                ? 0
                                : targetAzimuth - _heading!,
                        headingAvailable:
                            _heading != null && targetAzimuth != null,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 14,
                right: 14,
                top: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .62),
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            geometry == null
                                ? (_siteA == null
                                    ? 'Obteniendo ubicación de Site A…'
                                    : 'Ingresa las coordenadas de Site B')
                                : 'AZIMUT OBJETIVO',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .5)),
                        if (geometry != null)
                          Text('${targetAzimuth!.toStringAsFixed(1)}°',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900)),
                        if (geometry != null)
                          Text('Distancia ${_distanceLabel(targetDistance!)}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        if (geometry != null) ...[
                          const SizedBox(height: 8),
                          _azimuthReadout(dark: true),
                          if (kIsWeb && !_compassPermissionGranted)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed:
                                    _requestingCompass ? null : _enableCompass,
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.white),
                                icon: const Icon(Icons.explore_outlined),
                                label: Text(_requestingCompass
                                    ? 'Solicitando acceso…'
                                    : 'Permitir acceso a la brújula'),
                              ),
                            ),
                        ],
                        if (kIsWeb && _compassError != null)
                          Text(_compassError!,
                              style: const TextStyle(
                                  color: Colors.orangeAccent, fontSize: 11)),
                        if (_error != null)
                          Text(_error!,
                              style: const TextStyle(
                                  color: Colors.orangeAccent, fontSize: 12)),
                      ]),
                ),
              ),
            ]),
          ),
          Expanded(
            flex: 6,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                Row(children: [
                  const Icon(Icons.my_location,
                      color: Color(0xFFC62828), size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_siteA == null
                          ? 'Site A: ubicación no disponible'
                          : 'Site A  ${_siteA!.latitude.toStringAsFixed(6)}, ${_siteA!.longitude.toStringAsFixed(6)}  •  ${_siteA!.altitude.toStringAsFixed(1)} m')),
                  IconButton(
                      onPressed: _refreshLocation,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar GPS'),
                ]),
                const SizedBox(height: 4),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                        value: false,
                        icon: Icon(Icons.edit_location_alt),
                        label: Text('Coordenadas')),
                    ButtonSegment(
                        value: true,
                        icon: Icon(Icons.people_outline),
                        label: Text('Conectar técnico')),
                  ],
                  selected: {_connectionMode},
                  onSelectionChanged: (values) {
                    setState(() => _connectionMode = values.first);
                  },
                ),
                if (!_connectionMode) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _numberField(
                            _siteBLat, 'Latitud Site B', 'Ej. -34.603722',
                            onChanged: _siteBCoordinatesChanged)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _numberField(
                            _siteBLon, 'Longitud Site B', 'Ej. -58.381592',
                            onChanged: _siteBCoordinatesChanged)),
                    IconButton(
                      tooltip: 'Pegar coordenadas de Google Maps',
                      onPressed: _pasteSiteBCoordinates,
                      icon: const Icon(Icons.content_paste_go),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(children: [
                      const Icon(Icons.terrain,
                          size: 18, color: Color(0xFF66736B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _profileLoading
                              ? 'Consultando perfil y elevación con MW Profile…'
                              : _profile != null
                                  ? 'Elevación Site B: ${_profile!.siteBGroundAltitudeMeters.toStringAsFixed(1)} m · MW Profile'
                                  : _loadingElevation
                                      ? 'Consultando elevación del terreno de Site B…'
                                      : _siteBGroundAltitude != null
                                          ? 'Elevación Site B: ${_siteBGroundAltitude!.toStringAsFixed(1)} m (estimada automáticamente)'
                                          : _elevationError ??
                                              'La elevación se consulta al ingresar coordenadas.',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF66736B)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _numberField(
                            _siteAAntennaHeight, 'Altura antena A (m)', '0',
                            onChanged: _profileInputsChanged)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _numberField(
                            _siteBAntennaHeight, 'Altura antena B (m)', '0',
                            onChanged: _profileInputsChanged)),
                  ]),
                  const SizedBox(height: 10),
                  _buildProfileResult(),
                ] else ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _numberField(_connectionCode, 'Código de sesión',
                            'Pega el código del técnico')),
                    const SizedBox(width: 8),
                    FilledButton(
                        onPressed: _onConnect, child: const Text('Unirse')),
                  ]),
                  const SizedBox(height: 4),
                  const Text(
                      'La sesión compartida se habilitará al conectar el backend. Mientras tanto, usa coordenadas manuales.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF66736B))),
                ],
                const SizedBox(height: 12),
                _guidedAlignmentCard(),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      Row(children: [
                        const Icon(Icons.screen_rotation_alt,
                            color: Color(0xFFC62828)),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text('Inclinómetro experimental',
                                style: TextStyle(fontWeight: FontWeight.w700))),
                        Switch(
                            value: _useInclinometer,
                            onChanged: (value) =>
                                setState(() => _useInclinometer = value)),
                      ]),
                      if (_useInclinometer)
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text(
                                  'Tilt teléfono  ${_pitch?.toStringAsFixed(1) ?? '—'}°'),
                              Text(
                                  'Tilt enlace  ${_tilt?.toStringAsFixed(2) ?? '—'}°'),
                            ]),
                      if (_useInclinometer)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                              'El sensor y la altitud GPS son orientativos. Confirma la alineación con el radio.',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF66736B))),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                    'La línea se orienta con la brújula del teléfono; estructuras metálicas pueden desviarla.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF66736B))),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildProfileResult() {
    final profile = _profile;
    if (profile == null) {
      if (!const MwProfileApi().isConfigured) {
        return const Text(
            'MW Profile pendiente de dominio. Se conectará al configurar MW_PROFILE_API_BASE_URL.',
            style: TextStyle(fontSize: 11, color: Color(0xFF66736B)));
      }
      if (_profileError != null) {
        return Text(
            'No se pudo obtener el perfil: $_profileError. Azimut/distancia locales siguen disponibles.',
            style: const TextStyle(fontSize: 11, color: Color(0xFF9B2C2C)));
      }
      return const SizedBox.shrink();
    }
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Perfil de línea de vista · MW Profile',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              '${_distanceLabel(profile.distanceMeters)}  ·  Az A ${profile.azimuthADegrees.toStringAsFixed(1)}°  ·  Tilt A ${profile.tiltADegrees.toStringAsFixed(2)}°',
              style: const TextStyle(fontSize: 12)),
          LinkProfileChart(profile: profile),
        ]),
      ),
    );
  }

  Widget _numberField(
          TextEditingController controller, String label, String hint,
          {VoidCallback? onChanged}) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.text,
        onChanged: (_) {
          setState(() {});
          onChanged?.call();
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  String _distanceLabel(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(2)} km'
      : '${meters.toStringAsFixed(0)} m';
}

class _BearingGuidePainter extends CustomPainter {
  const _BearingGuidePainter(
      {required this.relativeBearing, required this.headingAvailable});
  final double relativeBearing;
  final bool headingAvailable;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .54);
    final paint = Paint()
      ..color = headingAvailable ? const Color(0xFFFF3B30) : Colors.white70
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(relativeBearing * math.pi / 180);
    canvas.drawLine(const Offset(0, 48), const Offset(0, -90), paint);
    final arrow = Path()
      ..moveTo(0, -112)
      ..lineTo(-13, -86)
      ..lineTo(13, -86)
      ..close();
    canvas.drawPath(arrow, Paint()..color = paint.color);
    canvas.restore();
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: .82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 9, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _BearingGuidePainter oldDelegate) =>
      oldDelegate.relativeBearing != relativeBearing ||
      oldDelegate.headingAvailable != headingAvailable;
}
