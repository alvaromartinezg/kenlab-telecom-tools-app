import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;

class FieldCameraPage extends StatefulWidget {
  const FieldCameraPage({super.key});

  @override
  State<FieldCameraPage> createState() => _FieldCameraPageState();
}

class _FieldCameraPageState extends State<FieldCameraPage>
    with WidgetsBindingObserver {
  CameraController? _camera;
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
    if (camera == null || !camera.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      camera.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty)
        throw CameraException('NoCamera', 'No se encontró una cámara.');
      final backCamera = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.back);
      final controller = CameraController(
        backCamera.isNotEmpty ? backCamera.first : cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _cameraError = null;
        _loadingCamera = false;
      });
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
      if (mounted) _showMessage('Foto KenLab guardada con los datos visibles.');
    } catch (error) {
      if (mounted) _showMessage('No se pudo tomar la foto: $error');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Uint8List _stampPhoto(
      Uint8List bytes, Position? position, DateTime timestamp, String note) {
    final photo = img.decodeImage(bytes);
    if (photo == null) return bytes;
    final metadata = <String>[
      'KENLAB FIELD PHOTO',
      '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
      if (position != null)
        'GPS ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
      if (position != null)
        'ALT ${position.altitude.toStringAsFixed(1)} m  ACC +/-${position.accuracy.toStringAsFixed(0)} m',
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
      return 'Permite el acceso a la cámara en los ajustes del navegador o dispositivo.';
    }
    return error.description ?? 'No se pudo iniciar la cámara.';
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
        title: const Text('Cámara de campo'),
        actions: [
          IconButton(
              onPressed: _refreshLocation,
              tooltip: 'Actualizar GPS',
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
                  hintText: 'Descripción opcional de la foto',
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
              const SizedBox(height: 12),
              Row(children: [
                const Expanded(
                  child: Text(
                      'La foto se descarga con fecha, GPS, altitud y descripción incrustados.',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
                const SizedBox(width: 16),
                Semantics(
                  label: 'Tomar foto',
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
                            : const Color(0xFFC62828),
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
              label: const Text('Intentar de nuevo'),
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
      required this.locationError});

  final Position? position;
  final DateTime timestamp;
  final String note;
  final String? locationError;

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
              const Text('KENLAB  •  EVIDENCIA DE CAMPO',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, letterSpacing: .6)),
              Text(
                  '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}  ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}'),
              if (p != null) ...[
                Text(
                    'GPS  ${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}'),
                Text(
                    'Altitud  ${p.altitude.toStringAsFixed(1)} m  •  Precisión  ±${p.accuracy.toStringAsFixed(0)} m'),
              ] else
                Text(locationError ?? 'Obteniendo coordenadas GPS…'),
              if (note.trim().isNotEmpty)
                Text(note.trim(), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
      ),
    );
  }
}
