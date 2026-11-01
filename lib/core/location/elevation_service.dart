import 'dart:convert';

import 'package:http/http.dart' as http;

/// Elevation lookup for the remote site using Open-Meteo's public elevation API.
class ElevationService {
  const ElevationService();

  Future<double> forCoordinate({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/elevation', {
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception(
          'No se pudo consultar la elevación (${response.statusCode}).');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final elevations = body['elevation'] as List<dynamic>?;
    if (elevations == null || elevations.isEmpty) {
      throw Exception('El servicio no devolvió una elevación válida.');
    }
    final elevation = elevations.first;
    if (elevation is! num || !elevation.isFinite) {
      throw Exception('El servicio no devolvió una elevación válida.');
    }
    return elevation.toDouble();
  }
}
