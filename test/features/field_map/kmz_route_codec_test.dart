import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenlab_telecom_tools/features/field_map/domain/kmz_route_codec.dart';

void main() {
  test('round-trips a KenLab KMZ route, photo bytes and comment', () {
    final capturedAt = DateTime.utc(2026, 11, 2, 12, 30);
    final photoBytes = Uint8List.fromList([0, 1, 2, 255, 17, 42]);
    final original = KmzRouteData(
      name: 'Ruta & postes',
      points: const [
        KmzRouteCoordinate(
            latitude: -12.1, longitude: -77.2, altitudeMeters: 145.4),
        KmzRouteCoordinate(
            latitude: -12.2, longitude: -77.3, altitudeMeters: 151.8),
      ],
      photos: [
        KmzRoutePhoto(
          latitude: -12.15,
          longitude: -77.25,
          altitudeMeters: 148.1,
          capturedAt: capturedAt,
          bytes: photoBytes,
          comment: 'Revisar caja <óptica> & limpiar conectores',
        ),
      ],
    );

    final decoded = KmzRouteCodec.decode(KmzRouteCodec.encode(original));

    expect(decoded.name, original.name);
    expect(decoded.points, hasLength(2));
    expect(decoded.points.first.latitude, -12.1);
    expect(decoded.points.last.longitude, -77.3);
    expect(decoded.photos, hasLength(1));
    expect(decoded.photos.single.bytes, photoBytes);
    expect(decoded.photos.single.capturedAt, capturedAt);
    expect(decoded.photos.single.comment, original.photos.single.comment);
  });
}
