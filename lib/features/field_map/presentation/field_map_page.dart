import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart';

class FieldMapPage extends StatefulWidget {
  const FieldMapPage({super.key});

  @override
  State<FieldMapPage> createState() => _FieldMapPageState();
}

class _FieldMapPageState extends State<FieldMapPage> {
  static const _styleUrl = ml.MapLibreStyles.openfreemapLiberty;
  ml.MapLibreMapController? _map;
  ml.LatLng _mapCenter = const ml.LatLng(0, 0);
  Position? _latestPosition;
  StreamSubscription<Position>? _routeSubscription;
  final List<_RoutePoint> _route = [];
  final List<_RoutePhoto> _photos = [];
  final List<ml.Symbol> _photoSymbols = [];
  bool _recording = false;
  bool _navigatingRoute = false;
  bool _is3d = true;
  bool _downloadingOffline = false;
  double? _offlineProgress;
  int _nextRouteIndex = 0;
  double? _offRouteMeters;
  double? _nextPointMeters;
  double? _nextPointBearing;
  String? _mapError;
  String _routeName = 'Ruta de campo';
  final _routeNameController = TextEditingController(text: 'Ruta de campo');

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  @override
  void dispose() {
    _routeSubscription?.cancel();
    _routeNameController.dispose();
    super.dispose();
  }

  Future<Position> _requestPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Activa los servicios de ubicación.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Permite ubicación para centrar y grabar la ruta.');
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _locateUser() async {
    try {
      final position = await _requestPosition();
      _latestPosition = position;
      _mapCenter = ml.LatLng(position.latitude, position.longitude);
      _moveCamera(_mapCenter);
    } catch (error) {
      if (mounted)
        setState(
            () => _mapError = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _onMapCreated(ml.MapLibreMapController controller) {
    _map = controller;
    _moveCamera(_mapCenter);
    _redrawRoute();
  }

  void _moveCamera(ml.LatLng center) {
    _map?.animateCamera(ml.CameraUpdate.newCameraPosition(
      ml.CameraPosition(target: center, zoom: 15.5, tilt: _is3d ? 55 : 0),
    ));
  }

  Future<void> _startRecording() async {
    if (_navigatingRoute) await _stopRouteGuidance();
    try {
      final position = await _requestPosition();
      final first = _routePoint(position);
      setState(() {
        _route
          ..clear()
          ..add(first);
        _photos.clear();
        _latestPosition = position;
        _recording = true;
        _navigatingRoute = false;
        _mapError = null;
      });
      await _redrawRoute();
      _routeSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 4,
        ),
      ).listen(_onPosition, onError: (Object error) {
        if (mounted) setState(() => _mapError = 'GPS de ruta: $error');
      });
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  _RoutePoint _routePoint(Position position) => _RoutePoint(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        capturedAt: DateTime.now(),
      );

  void _onPosition(Position position) {
    _latestPosition = position;
    final point = _routePoint(position);
    if (_route.isNotEmpty) {
      final previous = _route.last;
      final distance = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < 3) return;
    }
    setState(() => _route.add(point));
    _mapCenter = ml.LatLng(point.latitude, point.longitude);
    _redrawRoute();
  }

  Future<void> _stopRecording() async {
    await _routeSubscription?.cancel();
    _routeSubscription = null;
    if (mounted) setState(() => _recording = false);
    await _redrawRoute();
    if (_route.length >= 2)
      _message('Ruta detenida. Ya puedes compartirla en KMZ.');
  }

  Future<void> _startRouteGuidance() async {
    if (_route.length < 2 || _recording) return;
    try {
      final position = await _requestPosition();
      setState(() {
        _navigatingRoute = true;
        _nextRouteIndex = 0;
        _mapError = null;
      });
      _onNavigationPosition(position);
      _routeSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
        ),
      ).listen(_onNavigationPosition, onError: (Object error) {
        if (mounted) setState(() => _mapError = 'GPS de navegación: $error');
      });
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _stopRouteGuidance() async {
    await _routeSubscription?.cancel();
    _routeSubscription = null;
    if (mounted) setState(() => _navigatingRoute = false);
  }

  void _onNavigationPosition(Position position) {
    if (_route.isEmpty) return;
    _latestPosition = position;
    var nearestIndex = _nextRouteIndex.clamp(0, _route.length - 1);
    var nearestDistance = double.infinity;
    for (var index = nearestIndex; index < _route.length; index++) {
      final point = _route[index];
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    var deviation = double.infinity;
    for (final point in _route) {
      final distance = Geolocator.distanceBetween(position.latitude,
          position.longitude, point.latitude, point.longitude);
      if (distance < deviation) deviation = distance;
    }
    final nextIndex =
        nearestIndex + 1 < _route.length ? nearestIndex + 1 : _route.length - 1;
    final next = _route[nextIndex];
    final metersToNext = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      next.latitude,
      next.longitude,
    );
    final bearing = Geolocator.bearingBetween(
      position.latitude,
      position.longitude,
      next.latitude,
      next.longitude,
    );
    setState(() {
      _nextRouteIndex = nearestIndex;
      _offRouteMeters = deviation;
      _nextPointMeters = metersToNext;
      _nextPointBearing = bearing;
    });
    _moveCamera(ml.LatLng(position.latitude, position.longitude));
    if (nearestIndex == _route.length - 1 && metersToNext < 8) {
      _stopRouteGuidance();
      _message('Llegaste al final de la ruta.');
    }
  }

  Future<void> _redrawRoute() async {
    final controller = _map;
    if (controller == null || _route.length < 2) return;
    try {
      await controller.clearLines();
      await controller.addLine(ml.LineOptions(
        geometry: _route
            .map((point) => ml.LatLng(point.latitude, point.longitude))
            .toList(),
        lineColor: '#C62828',
        lineWidth: 5,
        lineOpacity: .95,
      ));
    } catch (_) {
      // Map style may still be loading; onStyleLoadedCallback redraws it.
    }
  }

  Future<void> _captureReferencePhoto() async {
    final position = _latestPosition;
    if (!_recording || position == null) {
      _message(
          'Inicia la grabación y espera a obtener GPS para agregar una foto.');
      return;
    }
    final captured = await showDialog<_CapturedRoutePhoto>(
      context: context,
      builder: (_) => const _RoutePhotoDialog(),
    );
    if (captured == null || !mounted) return;
    final compressed = _compressPhoto(captured.bytes);
    final photo = _RoutePhoto(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      capturedAt: DateTime.now(),
      bytes: compressed,
      comment: captured.comment,
    );
    setState(() => _photos.add(photo));
    final symbol = await _map?.addSymbol(ml.SymbolOptions(
      geometry: ml.LatLng(photo.latitude, photo.longitude),
      textField: 'CAM',
      textSize: 12,
      textColor: '#C62828',
      textHaloColor: '#FFFFFF',
      textHaloWidth: 2,
    ));
    if (symbol != null) _photoSymbols.add(symbol);
    _message('Foto guardada en este punto de la ruta.');
  }

  Uint8List _compressPhoto(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final resized =
        decoded.width > 1000 ? img.copyResize(decoded, width: 1000) : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 68));
  }

  Future<void> _downloadOfflineArea() async {
    if (kIsWeb) {
      _message(
          'La descarga de zonas offline está disponible en las versiones Android/iOS instalables; MapLibre Web no ofrece paquetes offline. La ruta y sus fotos sí pueden guardarse como KMZ.');
      return;
    }
    if (_mapCenter.latitude == 0 && _mapCenter.longitude == 0) {
      await _locateUser();
    }
    final radius = await showModalBottomSheet<double>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Descargar mapa sin conexión',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                    'Descarga el área alrededor del centro del mapa. Selecciona el tamaño para controlar el almacenamiento.'),
                const SizedBox(height: 12),
                for (final option in const [
                  (0.5, '500 m alrededor'),
                  (1.0, '1 km alrededor'),
                  (2.0, '2 km alrededor')
                ])
                  ListTile(
                    leading: const Icon(Icons.download_for_offline_outlined),
                    title: Text(option.$2),
                    onTap: () => Navigator.pop(context, option.$1),
                  ),
              ]),
        ),
      ),
    );
    if (radius == null) return;
    final lat = _mapCenter.latitude;
    final lon = _mapCenter.longitude;
    final deltaLat = radius / 111.32;
    final cosLat = math.max(.15, math.cos(lat * math.pi / 180));
    final deltaLon = radius / (111.32 * cosLat);
    setState(() {
      _downloadingOffline = true;
      _offlineProgress = 0;
    });
    try {
      await ml.downloadOfflineRegion(
        ml.OfflineRegionDefinition(
          bounds: ml.LatLngBounds(
            southwest: ml.LatLng(lat - deltaLat, lon - deltaLon),
            northeast: ml.LatLng(lat + deltaLat, lon + deltaLon),
          ),
          mapStyleUrl: _styleUrl,
          minZoom: 11,
          maxZoom: 16,
        ),
        metadata: {
          'name':
              'KenLab ${radius}km ${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}'
        },
        onEvent: (event) {
          if (!mounted) return;
          if (event is ml.InProgress)
            setState(() => _offlineProgress = event.progress);
          if (event is ml.Success) setState(() => _offlineProgress = 1);
          if (event is ml.Error)
            _message('Error descargando mapa: ${event.cause.message}');
        },
      );
      if (mounted)
        _message('Zona guardada para uso sin conexión en este dispositivo.');
    } catch (error) {
      if (mounted) _message('No se pudo descargar el área: $error');
    } finally {
      if (mounted)
        setState(() {
          _downloadingOffline = false;
          _offlineProgress = null;
        });
    }
  }

  Future<void> _exportKmz() async {
    if (_route.length < 2) {
      _message('Graba al menos dos ubicaciones para crear la ruta KMZ.');
      return;
    }
    final name = _xmlEscape(
        _routeName.trim().isEmpty ? 'Ruta KenLab' : _routeName.trim());
    final coordinates = _route
        .map((point) =>
            '${point.longitude.toStringAsFixed(7)},${point.latitude.toStringAsFixed(7)},${point.altitude.toStringAsFixed(1)}')
        .join(' ');
    final placemarks = StringBuffer();
    final archive = Archive();
    for (var index = 0; index < _photos.length; index++) {
      final photo = _photos[index];
      final imagePath = 'photos/reference_${index + 1}.jpg';
      archive.addFile(ArchiveFile(imagePath, photo.bytes.length, photo.bytes));
      final comment = _htmlEscape(photo.comment.trim());
      placemarks.write(
          '''<Placemark><name>Foto ${index + 1}</name><description><![CDATA[<img src="$imagePath" width="640"/><br/>Capturada: ${photo.capturedAt.toIso8601String()}${comment.isEmpty ? '' : '<br/>Comentario: $comment'}]]></description><Style><IconStyle><Icon><href>https://maps.google.com/mapfiles/kml/shapes/camera.png</href></Icon></IconStyle></Style><Point><altitudeMode>absolute</altitudeMode><coordinates>${photo.longitude},${photo.latitude},${photo.altitude}</coordinates></Point></Placemark>''');
    }
    final kml =
        '''<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2"><Document><name>$name</name><description>Ruta grabada con KenLab. Incluye ${_route.length} puntos y ${_photos.length} fotos.</description><Placemark><name>$name</name><Style><LineStyle><color>ff2828c6</color><width>5</width></LineStyle></Style><LineString><tessellate>1</tessellate><altitudeMode>absolute</altitudeMode><coordinates>$coordinates</coordinates></LineString></Placemark>$placemarks</Document></kml>''';
    final kmlBytes = utf8.encode(kml);
    archive.addFile(ArchiveFile('doc.kml', kmlBytes.length, kmlBytes));
    final kmz = Uint8List.fromList(ZipEncoder().encode(archive));
    final fileName = '${_safeFileName(_routeName)}.kmz';
    try {
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: fileName.replaceAll(RegExp(r'\.kmz$'), ''),
          bytes: kmz,
          fileExtension: 'kmz',
          mimeType: MimeType.custom,
          customMimeType: 'application/vnd.google-earth.kmz',
        );
      } else {
        await SharePlus.instance.share(ShareParams(files: [
          XFile.fromData(kmz,
              name: fileName, mimeType: 'application/vnd.google-earth.kmz'),
        ]));
      }
      if (mounted)
        _message('KMZ listo: incluye el recorrido y ${_photos.length} fotos.');
    } catch (error) {
      if (mounted) _message('No se pudo guardar/compartir el KMZ: $error');
    }
  }

  Future<void> _importKmz() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['kmz'],
      );
      if (files.isEmpty) return;
      final bytes = await files.single.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final kmlFile = archive.files
          .where((file) => file.name.toLowerCase().endsWith('.kml'))
          .firstOrNull;
      if (kmlFile == null)
        throw Exception('El KMZ no contiene un archivo KML.');
      final document = XmlDocument.parse(utf8.decode(kmlFile.content));
      final lineCoordinates = document
          .findAllElements('LineString')
          .expand((element) => element.findAllElements('coordinates'))
          .map((element) => element.innerText)
          .firstOrNull;
      if (lineCoordinates == null)
        throw Exception('No se encontró una ruta en el KMZ.');
      final importedPoints = <_RoutePoint>[];
      for (final tuple in lineCoordinates.trim().split(RegExp(r'\s+'))) {
        final values = tuple.split(',');
        if (values.length < 2) continue;
        final lon = double.tryParse(values[0]);
        final lat = double.tryParse(values[1]);
        final alt = values.length > 2 ? double.tryParse(values[2]) ?? 0.0 : 0.0;
        if (lat != null && lon != null)
          importedPoints.add(_RoutePoint(
            latitude: lat,
            longitude: lon,
            altitude: alt,
            capturedAt: DateTime.now(),
          ));
      }
      if (importedPoints.length < 2)
        throw Exception('La ruta no tiene suficientes puntos.');
      final importedPhotos = <_RoutePhoto>[];
      for (final placemark in document.findAllElements('Placemark')) {
        if (!placemark.findAllElements('Point').isNotEmpty) continue;
        final coordinates = placemark
            .findAllElements('Point')
            .expand((point) => point.findAllElements('coordinates'))
            .firstOrNull
            ?.innerText
            .trim();
        if (coordinates == null) continue;
        final coordinateParts = coordinates.split(',');
        if (coordinateParts.length < 2) continue;
        final longitude = double.tryParse(coordinateParts[0]);
        final latitude = double.tryParse(coordinateParts[1]);
        final altitude = coordinateParts.length > 2
            ? double.tryParse(coordinateParts[2]) ?? 0.0
            : 0.0;
        final description =
            placemark.findAllElements('description').firstOrNull?.innerText ??
                '';
        final imageMatch = RegExp(
                r'''(?:src|href)=["']([^"']+\.(?:jpg|jpeg|png))["']''',
                caseSensitive: false)
            .firstMatch(description);
        if (longitude == null || latitude == null || imageMatch == null)
          continue;
        final imageHref =
            Uri.parse(imageMatch.group(1)!).path.replaceAll('\\', '/');
        final kmlDirectory = kmlFile.name.contains('/')
            ? kmlFile.name.substring(0, kmlFile.name.lastIndexOf('/') + 1)
            : '';
        final candidates = {
          imageHref.replaceFirst(RegExp(r'^\./'), ''),
          '$kmlDirectory$imageHref'.replaceFirst(RegExp(r'^\./'), ''),
          imageHref.split('/').last,
        };
        final photoFile = archive.files
            .where(
                (file) => candidates.contains(file.name.replaceAll('\\', '/')))
            .firstOrNull;
        if (photoFile == null) continue;
        final commentMatch = RegExp(
          r'<br\s*/?>\s*Comentario:\s*(.*?)(?:<br\s*/?>|$)',
          caseSensitive: false,
          dotAll: true,
        ).firstMatch(description);
        final capturedMatch =
            RegExp(r'Capturada:\s*([^<\r\n]+)').firstMatch(description);
        importedPhotos.add(_RoutePhoto(
          latitude: latitude,
          longitude: longitude,
          altitude: altitude,
          capturedAt:
              DateTime.tryParse(capturedMatch?.group(1)?.trim() ?? '') ??
                  DateTime.now(),
          bytes: Uint8List.fromList(photoFile.content),
          comment: _htmlUnescape(commentMatch?.group(1)?.trim() ?? ''),
        ));
      }
      await _clearPhotoSymbols();
      setState(() {
        _route
          ..clear()
          ..addAll(importedPoints);
        _photos.clear();
        _photos.addAll(importedPhotos);
        _recording = false;
        _navigatingRoute = false;
        _nextRouteIndex = 0;
        _routeName = document
                .findAllElements('Document')
                .firstOrNull
                ?.findElements('name')
                .firstOrNull
                ?.innerText ??
            'Ruta importada';
        _mapCenter = ml.LatLng(
            importedPoints.first.latitude, importedPoints.first.longitude);
      });
      await _redrawRoute();
      for (final photo in importedPhotos) {
        final symbol = await _map?.addSymbol(ml.SymbolOptions(
          geometry: ml.LatLng(photo.latitude, photo.longitude),
          textField: 'CAM',
          textSize: 12,
          textColor: '#C62828',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2,
        ));
        if (symbol != null) _photoSymbols.add(symbol);
      }
      _moveCamera(_mapCenter);
      _message(
          'Ruta importada (${importedPoints.length} puntos y ${importedPhotos.length} fotos).');
    } catch (error) {
      _message('No se pudo abrir el KMZ: $error');
    }
  }

  Future<void> _clearPhotoSymbols() async {
    final map = _map;
    if (map == null || _photoSymbols.isEmpty) return;
    await map.removeSymbols(List<ml.Symbol>.from(_photoSymbols));
    _photoSymbols.clear();
  }

  Future<void> _showPhotoGallery() async {
    if (_photos.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(children: [
                const Expanded(
                  child: Text('Fotos de la ruta',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close)),
              ]),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(photo.bytes,
                          width: 58, height: 58, fit: BoxFit.cover),
                    ),
                    title: Text(
                        'Foto ${index + 1} · ${photo.capturedAt.toLocal()}'),
                    subtitle: Text(
                      photo.comment.isEmpty
                          ? '${photo.latitude.toStringAsFixed(6)}, ${photo.longitude.toStringAsFixed(6)}'
                          : photo.comment,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showPhoto(photo, index);
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _showPhoto(_RoutePhoto photo, int index) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Foto ${index + 1}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              InteractiveViewer(child: Image.memory(photo.bytes)),
              const SizedBox(height: 10),
              Text(
                  '${photo.latitude.toStringAsFixed(6)}, ${photo.longitude.toStringAsFixed(6)} · ${photo.capturedAt.toLocal()}'),
              if (photo.comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text(photo.comment)),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar')),
          ],
        ),
      );

  void _toggleMapDimension() {
    setState(() => _is3d = !_is3d);
    _map?.animateCamera(ml.CameraUpdate.newCameraPosition(
      ml.CameraPosition(
        target: _mapCenter,
        zoom: 15.5,
        tilt: _is3d ? 55 : 0,
      ),
    ));
  }

  String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  String _htmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  String _htmlUnescape(String value) => value
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
  String _safeFileName(String value) => value
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '')
          .isEmpty
      ? 'kenlab_route'
      : value
          .trim()
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');

  double get _distanceMeters {
    var distance = 0.0;
    for (var index = 1; index < _route.length; index++) {
      distance += Geolocator.distanceBetween(
        _route[index - 1].latitude,
        _route[index - 1].longitude,
        _route[index].latitude,
        _route[index].longitude,
      );
    }
    return distance;
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Mapa de trabajo'),
          actions: [
            IconButton(
                tooltip: 'Descargar zona offline',
                onPressed: _downloadingOffline ? null : _downloadOfflineArea,
                icon: const Icon(Icons.download_for_offline_outlined)),
            IconButton(
                tooltip: 'Importar KMZ de otro técnico',
                onPressed: _recording || _navigatingRoute ? null : _importKmz,
                icon: const Icon(Icons.upload_file_outlined)),
            if (_photos.isNotEmpty)
              IconButton(
                  tooltip: 'Ver fotos de la ruta',
                  onPressed: _showPhotoGallery,
                  icon: const Icon(Icons.photo_library_outlined)),
            const SizedBox(width: 4),
          ],
        ),
        body: Stack(children: [
          ml.MapLibreMap(
            styleString: _styleUrl,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _redrawRoute,
            onCameraMove: (position) => _mapCenter = position.target,
            initialCameraPosition: ml.CameraPosition(
              target: ml.LatLng(0, 0),
              zoom: 1.5,
              tilt: _is3d ? 55 : 0,
            ),
            trackCameraPosition: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),
          Positioned(
            left: 14,
            top: 14,
            child: Card(
              color: Colors.white.withValues(alpha: .94),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _toggleMapDimension,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_is3d ? Icons.view_in_ar : Icons.map_outlined,
                        color: const Color(0xFFC62828), size: 18),
                    const SizedBox(width: 6),
                    Text(_is3d ? 'Vista 3D' : 'Vista 2D',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 5),
                    const Icon(Icons.swap_horiz, size: 16),
                  ]),
                ),
              ),
            ),
          ),
          if (_mapError != null)
            Positioned(
                left: 14,
                right: 14,
                top: 70,
                child: Card(
                  color: Colors.white,
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_mapError!)),
                )),
          if (_downloadingOffline)
            Positioned(
                left: 16,
                right: 16,
                top: 70,
                child: Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        const Text('Descargando teselas del mapa…'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _offlineProgress),
                      ])),
                )),
          Positioned(
            right: 14,
            top: 70,
            child: FloatingActionButton.small(
              heroTag: 'my_location_map',
              onPressed: _locateUser,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              color: Colors.white.withValues(alpha: .97),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (_navigatingRoute)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        const Icon(Icons.directions_walk,
                            color: Color(0xFFC62828), size: 19),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Punto ${(_nextRouteIndex + 1).clamp(1, _route.length)} de ${_route.length} · ${_nextPointMeters?.toStringAsFixed(0) ?? '—'} m · rumbo ${_nextPointBearing?.toStringAsFixed(0) ?? '—'}° · ${_offRouteMeters != null && _offRouteMeters! > 15 ? 'fuera de ruta ${_offRouteMeters!.toStringAsFixed(0)} m' : 'siguiendo la ruta'}',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Detener guía de ruta',
                          visualDensity: VisualDensity.compact,
                          onPressed: _stopRouteGuidance,
                          icon: const Icon(Icons.close),
                        ),
                      ]),
                    ),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        enabled: !_recording,
                        controller: _routeNameController,
                        onChanged: (value) => _routeName = value,
                        decoration: const InputDecoration(
                            labelText: 'Nombre de ruta', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                        '${_route.length} pts  •  ${_distanceMeters < 1000 ? '${_distanceMeters.toStringAsFixed(0)} m' : '${(_distanceMeters / 1000).toStringAsFixed(2)} km'}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _recording ? _stopRecording : _startRecording,
                        style: FilledButton.styleFrom(
                            backgroundColor: _recording
                                ? const Color(0xFF263746)
                                : const Color(0xFFC62828)),
                        icon: Icon(_recording
                            ? Icons.stop
                            : Icons.fiber_manual_record),
                        label: Text(
                            _recording ? 'Detener ruta' : 'Grabar caminata'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Agregar foto en este punto',
                      onPressed: _captureReferencePhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      tooltip: 'Compartir ruta KMZ con fotos',
                      onPressed: _route.length >= 2 ? _exportKmz : null,
                      icon: const Icon(Icons.share_outlined),
                    ),
                  ]),
                  if (_route.length >= 2 && !_recording)
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _navigatingRoute
                              ? _stopRouteGuidance
                              : _startRouteGuidance,
                          icon: Icon(_navigatingRoute
                              ? Icons.stop_circle_outlined
                              : Icons.directions_walk),
                          label: Text(_navigatingRoute
                              ? 'Detener guía de ruta'
                              : 'Guiarme por esta ruta'),
                        ),
                      ),
                    ),
                  if (_photos.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _showPhotoGallery,
                        icon:
                            const Icon(Icons.photo_library_outlined, size: 16),
                        label: Text('${_photos.length} fotos · Ver galería'),
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Text(
                        'Mapas © OpenFreeMap / OpenStreetMap · Los paquetes offline requieren la app instalable Android/iOS.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 10, color: Color(0xFF66736B))),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      );
}

class _RoutePoint {
  const _RoutePoint(
      {required this.latitude,
      required this.longitude,
      required this.altitude,
      required this.capturedAt});
  final double latitude;
  final double longitude;
  final double altitude;
  final DateTime capturedAt;
}

class _RoutePhoto extends _RoutePoint {
  const _RoutePhoto(
      {required super.latitude,
      required super.longitude,
      required super.altitude,
      required super.capturedAt,
      required this.bytes,
      this.comment = ''});
  final Uint8List bytes;
  final String comment;
}

class _CapturedRoutePhoto {
  const _CapturedRoutePhoto({required this.bytes, required this.comment});
  final Uint8List bytes;
  final String comment;
}

class _RoutePhotoDialog extends StatefulWidget {
  const _RoutePhotoDialog();

  @override
  State<_RoutePhotoDialog> createState() => _RoutePhotoDialogState();
}

class _RoutePhotoDialogState extends State<_RoutePhotoDialog> {
  CameraController? _camera;
  String? _error;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _openCamera();
  }

  @override
  void dispose() {
    _camera?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No hay cámara disponible.');
      final back = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.back);
      final camera = CameraController(
          back.isNotEmpty ? back.first : cameras.first, ResolutionPreset.medium,
          enableAudio: false);
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      setState(() => _camera = camera);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _takePhoto() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    try {
      final file = await camera.takePicture();
      if (mounted) {
        Navigator.pop(
          context,
          _CapturedRoutePhoto(
            bytes: await file.readAsBytes(),
            comment: _commentController.text.trim(),
          ),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'No se pudo tomar la foto: $error');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Foto de referencia'),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 330,
              child: _camera != null && _camera!.value.isInitialized
                  ? CameraPreview(_camera!)
                  : Center(child: Text(_error ?? 'Abriendo cámara…')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                hintText: 'Describe qué debe observar otro técnico',
                border: OutlineInputBorder(),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton.icon(
              onPressed: _camera == null ? null : _takePhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capturar')),
        ],
      );
}
