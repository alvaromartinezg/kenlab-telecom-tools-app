import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/location/elevation_service.dart';
import '../domain/link_calculator.dart';

class AlignmentPage extends StatefulWidget {
  const AlignmentPage({super.key});

  @override
  State<AlignmentPage> createState() => _AlignmentPageState();
}

class _AlignmentPageState extends State<AlignmentPage> {
  CameraController? _camera;
  Position? _siteA;
  AccelerometerEvent? _acceleration;
  MagnetometerEvent? _magneticField;
  double? _heading;
  bool _loadingCamera = true;
  bool _useInclinometer = true;
  bool _connectionMode = false;
  String? _error;
  double? _siteBGroundAltitude;
  bool _loadingElevation = false;
  String? _elevationError;
  Timer? _elevationDebounce;
  StreamSubscription<AccelerometerEvent>? _accSubscription;
  StreamSubscription<MagnetometerEvent>? _magSubscription;

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
    _siteBLat.dispose();
    _siteBLon.dispose();
    _elevationDebounce?.cancel();
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
          _error = null;
        });
    } catch (error) {
      if (mounted)
        setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _listenToSensors() {
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

  double? get _tilt {
    final start = _siteA;
    final endAltitude = _siteBGroundAltitude;
    final startHeight = double.tryParse(_siteAAntennaHeight.text.trim());
    final endHeight = double.tryParse(_siteBAntennaHeight.text.trim());
    final geometry = _geometry;
    if (start == null ||
        endAltitude == null ||
        startHeight == null ||
        endHeight == null ||
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

  void _siteBCoordinatesChanged() {
    setState(() {
      _siteBGroundAltitude = null;
      _elevationError = null;
    });
    _elevationDebounce?.cancel();
    final lat = double.tryParse(_siteBLat.text.trim().replaceAll('−', '-'));
    final lon = double.tryParse(_siteBLon.text.trim().replaceAll('−', '-'));
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) return;
    _elevationDebounce = Timer(const Duration(milliseconds: 500), () {
      _fetchSiteBElevation(lat, lon);
    });
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

  double? get _pitch {
    final acceleration = _acceleration;
    if (acceleration == null) return null;
    final gravity = math.sqrt(acceleration.x * acceleration.x +
        acceleration.y * acceleration.y +
        acceleration.z * acceleration.z);
    if (gravity == 0) return null;
    final sine = (-acceleration.z / gravity).clamp(-1.0, 1.0);
    return math.asin(sine) * 180 / math.pi;
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
              if (geometry != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _BearingGuidePainter(
                        relativeBearing: _heading == null
                            ? 0
                            : geometry.bearingDegrees - _heading!,
                        headingAvailable: _heading != null,
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
                                : 'AZIMUT OBJETIVO  ${geometry.bearingDegrees.toStringAsFixed(1)}°',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .5)),
                        if (geometry != null)
                          Text(
                              'Distancia ${_distanceLabel(geometry.distanceMeters)}${_heading == null ? '  •  rumbo de brújula no disponible' : '  •  brújula ${_heading!.toStringAsFixed(0)}°'}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
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
                          _loadingElevation
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
                            _siteAAntennaHeight, 'Altura antena A (m)', '0')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _numberField(
                            _siteBAntennaHeight, 'Altura antena B (m)', '0')),
                  ]),
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
