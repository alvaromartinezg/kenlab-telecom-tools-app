import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class KmzRouteCoordinate {
  const KmzRouteCoordinate({
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
  });

  final double latitude;
  final double longitude;
  final double altitudeMeters;
}

class KmzRoutePhoto {
  const KmzRoutePhoto({
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.capturedAt,
    required this.bytes,
    this.comment = '',
  });

  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final DateTime capturedAt;
  final Uint8List bytes;
  final String comment;
}

class KmzRouteData {
  const KmzRouteData({
    required this.name,
    required this.points,
    required this.photos,
  });

  final String name;
  final List<KmzRouteCoordinate> points;
  final List<KmzRoutePhoto> photos;
}

/// Encodes and decodes the KMZ package format used by Field Map.
class KmzRouteCodec {
  const KmzRouteCodec._();

  static Uint8List encode(KmzRouteData route) {
    if (route.points.length < 2) {
      throw const FormatException('La ruta KMZ necesita al menos dos puntos.');
    }
    final archive = Archive();
    final photoPlacemarks = StringBuffer();
    for (var index = 0; index < route.photos.length; index++) {
      final photo = route.photos[index];
      final imagePath = 'photos/reference_${index + 1}.jpg';
      archive.addFile(ArchiveFile.bytes(imagePath, photo.bytes));
      final comment = _escapeHtml(photo.comment.trim());
      photoPlacemarks.write(
        '<Placemark><name>Foto ${index + 1}</name>'
        '<description><![CDATA[<img src="$imagePath" width="640"/><br/>'
        'Capturada: ${photo.capturedAt.toIso8601String()}'
        '${comment.isEmpty ? '' : '<br/>Comentario: $comment'}]]></description>'
        '<Style><IconStyle><Icon><href>https://maps.google.com/mapfiles/kml/shapes/camera.png</href></Icon></IconStyle></Style>'
        '<Point><altitudeMode>absolute</altitudeMode><coordinates>'
        '${photo.longitude},${photo.latitude},${photo.altitudeMeters}'
        '</coordinates></Point></Placemark>',
      );
    }
    final name = _escapeXml(
        route.name.trim().isEmpty ? 'Ruta KenLab' : route.name.trim());
    final coordinates = route.points
        .map((point) =>
            '${point.longitude.toStringAsFixed(7)},${point.latitude.toStringAsFixed(7)},${point.altitudeMeters.toStringAsFixed(1)}')
        .join(' ');
    final kml = '<?xml version="1.0" encoding="UTF-8"?>'
        '<kml xmlns="http://www.opengis.net/kml/2.2"><Document>'
        '<name>$name</name><description>Ruta grabada con KenLab. '
        'Incluye ${route.points.length} puntos y ${route.photos.length} fotos.</description>'
        '<Placemark><name>$name</name><Style><LineStyle>'
        '<color>ff2828c6</color><width>5</width></LineStyle></Style>'
        '<LineString><tessellate>1</tessellate><altitudeMode>absolute</altitudeMode>'
        '<coordinates>$coordinates</coordinates></LineString></Placemark>'
        '$photoPlacemarks</Document></kml>';
    archive.addFile(ArchiveFile.string('doc.kml', kml));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static KmzRouteData decode(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final kmlFile = archive.files
        .where((file) =>
            file.isFile && file.name.toLowerCase().trim().endsWith('.kml'))
        .firstOrNull;
    if (kmlFile == null) {
      throw const FormatException('El archivo no contiene un KML.');
    }
    var kmlText = utf8.decode(kmlFile.content, allowMalformed: true);
    if (kmlText.startsWith('\uFEFF')) kmlText = kmlText.substring(1);
    final document = XmlDocument.parse(kmlText);
    final lineString = _descendants(document)
        .where((element) => element.name.local == 'LineString')
        .firstOrNull;
    final lineCoordinates = lineString == null
        ? null
        : _descendants(lineString)
            .where((element) => element.name.local == 'coordinates')
            .firstOrNull
            ?.innerText;
    if (lineCoordinates == null) {
      throw const FormatException(
          'No se encontró una ruta LineString en el KMZ.');
    }

    final points = <KmzRouteCoordinate>[];
    for (final tuple in lineCoordinates.trim().split(RegExp(r'\s+'))) {
      final values = tuple.split(',');
      if (values.length < 2) continue;
      final longitude = double.tryParse(values[0]);
      final latitude = double.tryParse(values[1]);
      final altitude =
          values.length > 2 ? double.tryParse(values[2]) ?? 0 : 0.0;
      if (latitude == null ||
          longitude == null ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        continue;
      }
      points.add(KmzRouteCoordinate(
        latitude: latitude,
        longitude: longitude,
        altitudeMeters: altitude,
      ));
    }
    if (points.length < 2) {
      throw const FormatException(
          'La ruta del KMZ no tiene suficientes puntos válidos.');
    }

    final kmlDirectory = kmlFile.name.contains('/')
        ? kmlFile.name.substring(0, kmlFile.name.lastIndexOf('/') + 1)
        : '';
    final photos = <KmzRoutePhoto>[];
    for (final placemark in _descendants(document)
        .where((element) => element.name.local == 'Placemark')) {
      final point = _descendants(placemark)
          .where((element) => element.name.local == 'Point')
          .firstOrNull;
      if (point == null) continue;
      final coordinateText = _descendants(point)
          .where((element) => element.name.local == 'coordinates')
          .firstOrNull
          ?.innerText
          .trim();
      if (coordinateText == null) continue;
      final values = coordinateText.split(',');
      if (values.length < 2) continue;
      final longitude = double.tryParse(values[0]);
      final latitude = double.tryParse(values[1]);
      final altitude =
          values.length > 2 ? double.tryParse(values[2]) ?? 0 : 0.0;
      if (latitude == null ||
          longitude == null ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        continue;
      }
      final description = _descendants(placemark)
              .where((element) => element.name.local == 'description')
              .firstOrNull
              ?.innerText ??
          '';
      final imageMatch = RegExp(
        r'''(?:src|href)=["']([^"']+\.(?:jpg|jpeg|png))(?:\?[^"']*)?["']''',
        caseSensitive: false,
      ).firstMatch(description);
      if (imageMatch == null) continue;
      final imageHref =
          Uri.decodeComponent(Uri.parse(imageMatch.group(1)!).path)
              .replaceAll('\\', '/')
              .replaceFirst(RegExp(r'^/'), '');
      final candidates = {
        imageHref.replaceFirst(RegExp(r'^\./'), ''),
        '$kmlDirectory$imageHref'.replaceFirst(RegExp(r'^\./'), ''),
        imageHref.split('/').last,
      };
      final photoFile = archive.files
          .where((file) =>
              file.isFile &&
              candidates.contains(file.name.replaceAll('\\', '/')))
          .firstOrNull;
      if (photoFile == null) continue;
      final comment = RegExp(
        r'<br\s*/?>\s*Comentario:\s*(.*?)(?:<br\s*/?>|$)',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(description)?.group(1);
      final capturedAt = RegExp(r'Capturada:\s*([^<\r\n]+)')
          .firstMatch(description)
          ?.group(1)
          ?.trim();
      photos.add(KmzRoutePhoto(
        latitude: latitude,
        longitude: longitude,
        altitudeMeters: altitude,
        capturedAt: DateTime.tryParse(capturedAt ?? '') ?? DateTime.now(),
        bytes: Uint8List.fromList(photoFile.content),
        comment: _unescapeHtml(comment?.trim() ?? ''),
      ));
    }

    final routeName = _descendants(document)
            .where((element) => element.name.local == 'Document')
            .firstOrNull
            ?.children
            .whereType<XmlElement>()
            .where((element) => element.name.local == 'name')
            .firstOrNull
            ?.innerText
            .trim() ??
        'Ruta importada';
    return KmzRouteData(name: routeName, points: points, photos: photos);
  }
}

Iterable<XmlElement> _descendants(XmlNode node) =>
    node.descendants.whereType<XmlElement>();

String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _escapeHtml(String value) => _escapeXml(value);

String _unescapeHtml(String value) => value
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');
