import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;

import '../../../core/settings/app_settings.dart';
import '../../../core/settings/app_text.dart';

class FieldCameraPage extends StatefulWidget {
  const FieldCameraPage({super.key});

  @override
  State<FieldCameraPage> createState() => _FieldCameraPageState();
}

class _FieldCameraPageState extends State<FieldCameraPage>
    with WidgetsBindingObserver {
  CameraController? _camera;
  List<CameraDescription> _availableCameras = const [];
  CameraDescription? _selectedCamera;
  Position? _position;
  Uint8List? _lastPhoto;
  bool _loadingCamera = true;
  bool _capturing = false;
  String? _cameraError;
  String? _locationError;
  DateTime? _capturedAt;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _refreshLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (camera != null) camera.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed) {
      if (camera == null) _initializeCamera(preferred: _selectedCamera);
    }
  }

  Future<void> _initializeCamera({CameraDescription? preferred}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
            'NoCamera', appText(context, 'No hay cámaras disponibles.'));
      }
      final selected = preferred ??
          (cameras.any((camera) => camera.name == _selectedCamera?.name)
              ? cameras
                  .firstWhere((camera) => camera.name == _selectedCamera?.name)
              : cameras.firstWhere(
                  (camera) => camera.lensDirection == CameraLensDirection.back,
                  orElse: () => cameras.first,
                ));
      if (mounted) {
        setState(() {
          _availableCameras = cameras;
          _selectedCamera = selected;
        });
      }
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final previous = _camera;
      setState(() {
        _camera = controller;
        _cameraError = null;
        _loadingCamera = false;
      });
      if (previous != null && !identical(previous, controller)) {
        await previous.dispose();
      }
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = _cameraMessage(error);
        _loadingCamera = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'No se pudo iniciar la cámara: $error';
        _loadingCamera = false;
      });
    }
  }

  Future<void> _selectCamera(int index) async {
    if (index < 0 || index >= _availableCameras.length) return;
    final selected = _availableCameras[index];
    if (_selectedCamera?.name == selected.name) return;
    final previous = _camera;
    setState(() {
      _camera = null;
      _selectedCamera = selected;
      _loadingCamera = true;
      _cameraError = null;
    });
    await previous?.dispose();
    if (mounted) await _initializeCamera(preferred: selected);
  }

  String _cameraLabel(CameraDescription camera, int index) {
    final lens = switch (camera.lensDirection) {
      CameraLensDirection.front => appText(context, 'frontal'),
      CameraLensDirection.back => appText(context, 'trasera'),
      CameraLensDirection.external => appText(context, 'externa', 'external'),
    };
    final name = camera.name.trim();
    final looksLikeDeviceId =
        RegExp(r'^[0-9a-f-]{12,}$', caseSensitive: false).hasMatch(name);
    return name.isEmpty || looksLikeDeviceId
        ? '${appText(context, 'Cámara')} ${index + 1} · $lens'
        : '$lens · $name';
  }

  Future<void> _refreshLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled)
        throw Exception('Activa la ubicación del dispositivo.');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
            'Permite el acceso a ubicación para registrar los datos de la foto.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted)
        setState(() {
          _position = position;
          _locationError = null;
        });
    } catch (error) {
      if (mounted)
        setState(() =>
            _locationError = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _takePhoto() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await camera.takePicture();
      final original = await file.readAsBytes();
      final now = DateTime.now();
      final bytes =
          _stampPhoto(original, _position, now, _noteController.text.trim());
      await FileSaver.instance.saveFile(
        name:
            'KenLab_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}',
        bytes: bytes,
        fileExtension: 'jpg',
        mimeType: MimeType.jpeg,
      );
      if (mounted)
        setState(() {
          _lastPhoto = bytes;
          _capturedAt = now;
        });
      if (mounted)
        _showMessage(appText(context, 'Foto guardada con los datos visibles.'));
    } catch (error) {
      if (mounted) {
        _showMessage(
            '${appText(context, 'No se pudo tomar la foto', 'Could not take the photo')}: $error');
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Uint8List _stampPhoto(
      Uint8List bytes, Position? position, DateTime timestamp, String note) {
    final photo = img.decodeImage(bytes);
    if (photo == null) return bytes;
    final metadata = <String>[
      if (AppSettings.instance.companyName.trim().isNotEmpty)
        AppSettings.instance.companyName.trim(),
      '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
      if (position != null)
        '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
      if (position != null)
        appText(
          context,
          'Altitud ${position.altitude.toStringAsFixed(1)} m  ·  Precisión ±${position.accuracy.toStringAsFixed(0)} m',
          'Altitude ${position.altitude.toStringAsFixed(1)} m  ·  Accuracy ±${position.accuracy.toStringAsFixed(0)} m',
        ),
      if (note.isNotEmpty) note,
    ];
    final font = img.arial24;
    final lineHeight = font.lineHeight + 8;
    final blockHeight =
        (metadata.length * lineHeight + 20).clamp(70, photo.height);
    final startY = photo.height - blockHeight;
    img.fillRect(photo,
        x1: 0,
        y1: startY,
        x2: photo.width - 1,
        y2: photo.height - 1,
        color: img.ColorRgba8(10, 20, 28, 205));
    for (var index = 0; index < metadata.length; index++) {
      img.drawString(photo, metadata[index],
          font: font,
          x: 14,
          y: startY + 10 + index * lineHeight,
          color: img.ColorRgb8(255, 255, 255));
    }
    return Uint8List.fromList(img.encodeJpg(photo, quality: 90));
  }

  String _cameraMessage(CameraException error) {
    if (error.code == 'CameraAccessDenied' ||
        error.code == 'cameraPermission') {
      return appText(
        context,
        'Permite el acceso a la cámara en los ajustes del navegador o dispositivo.',
        'Allow camera access in your browser or device settings.',
      );
    }
    return error.description ??
        appText(context, 'No se pudo iniciar la cámara.',
            'Could not start the camera.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF17212B),
        foregroundColor: Colors.white,
        title: Text(appText(context, 'Cámara de campo')),
        actions: [
          PopupMenuButton<int>(
            tooltip: appText(context, 'Cambiar cámara'),
            enabled: !_loadingCamera && _availableCameras.length > 1,
            icon: const Icon(Icons.cameraswitch_outlined),
            onSelected: _selectCamera,
            itemBuilder: (context) => [
              for (var index = 0; index < _availableCameras.length; index++)
                PopupMenuItem(
                  value: index,
                  child: Row(children: [
                    Icon(_availableCameras[index].lensDirection ==
                            CameraLensDirection.front
                        ? Icons.camera_front_outlined
                        : Icons.camera_rear_outlined),
                    const SizedBox(width: 10),
                    Flexible(
                        child: Text(
                            _cameraLabel(_availableCameras[index], index))),
                    if (_selectedCamera?.name ==
                        _availableCameras[index].name) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check, size: 18),
                    ],
                  ]),
                ),
            ],
          ),
          IconButton(
              onPressed: _refreshLocation,
              tooltip: appText(context, 'Actualizar ubicación'),
              icon: const Icon(Icons.my_location)),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              _buildCameraPreview(),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: _MetadataOverlay(
                  position: position,
                  timestamp: _capturedAt ?? DateTime.now(),
                  note: _noteController.text,
                  locationError: _locationError,
                  companyName: AppSettings.instance.companyName,
                ),
              ),
              if (_lastPhoto != null)
                Positioned(
                  right: 16,
                  bottom: 18,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_lastPhoto!,
                        width: 70, height: 70, fit: BoxFit.cover),
                  ),
                ),
            ]),
          ),
          Container(
            color: const Color(0xFF17212B),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(children: [
              TextField(
                controller: _noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: appText(context, 'Descripción opcional de la foto'),
                  hintStyle: const TextStyle(color: Colors.white60),
                  prefixIcon:
                      const Icon(Icons.edit_note, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .1),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (AppSettings.instance.quickNotes.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: AppSettings.instance.quickNotes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final note = AppSettings.instance.quickNotes[index];
                      return ActionChip(
                        label: Text(note,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onPressed: () {
                          setState(() {
                            _noteController.text = note;
                            _noteController.selection =
                                TextSelection.collapsed(offset: note.length);
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Text(
                      appText(
                          context,
                          'La foto se guarda con fecha, coordenadas, altitud y descripción.',
                          'The photo is saved with date, coordinates, altitude and note.'),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
                const SizedBox(width: 16),
                Semantics(
                  label: appText(context, 'Tomar foto'),
                  child: GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: _capturing
                            ? Colors.white38
                            : AppSettings.instance.primaryColor,
                      ),
                      child: _capturing
                          ? const Padding(
                              padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.camera_alt, color: Colors.white),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final camera = _camera;
    if (_loadingCamera)
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    if (camera == null || !camera.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white, size: 52),
            const SizedBox(height: 16),
            Text(_cameraError ?? 'La cámara no está disponible.',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _loadingCamera = true;
                  _cameraError = null;
                });
                _initializeCamera();
              },
              icon: const Icon(Icons.refresh),
              label: Text(appText(context, 'Intentar de nuevo', 'Try again')),
            ),
          ]),
        ),
      );
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
            width: camera.value.previewSize!.height,
            height: camera.value.previewSize!.width,
            child: CameraPreview(camera)),
      ),
    );
  }
}

class _MetadataOverlay extends StatelessWidget {
  const _MetadataOverlay(
      {required this.position,
      required this.timestamp,
      required this.note,
      required this.locationError,
      required this.companyName});

  final Position? position;
  final DateTime timestamp;
  final String note;
  final String? locationError;
  final String companyName;

  @override
  Widget build(BuildContext context) {
    final p = position;
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Colors.white, height: 1.45);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .58),
          borderRadius: BorderRadius.circular(14)),
      child: DefaultTextStyle(
        style: style ?? const TextStyle(color: Colors.white),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (companyName.trim().isNotEmpty)
                Text(companyName.trim(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, letterSpacing: .4)),
              Text(
                  '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}  ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'),
              if (p != null) ...[
                Text(
                    '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}'),
                Text(
                    '${appText(context, 'Altitud', 'Altitude')}  ${p.altitude.toStringAsFixed(1)} m  •  ${appText(context, 'Precisión', 'Accuracy')}  ±${p.accuracy.toStringAsFixed(0)} m'),
              ] else
                Text(locationError ??
                    appText(context, 'Obteniendo coordenadas…',
                        'Getting coordinates…')),
              if (note.trim().isNotEmpty)
                Text(note.trim(), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
      ),
    );
  }
}
