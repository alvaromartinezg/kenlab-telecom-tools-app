import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../models/link_profile.dart';

class MwProfileApi {
  const MwProfileApi({
    this.baseUrl = AppConfig.mwProfileApiBaseUrl,
    this.path = AppConfig.mwProfileApiPath,
    this.client,
  });

  final String baseUrl;
  final String path;
  final http.Client? client;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  Future<LinkProfile> calculateProfile(LinkProfileRequest request) async {
    if (!isConfigured) {
      throw StateError(
          'Configura MW_PROFILE_API_BASE_URL para conectar MW Profile.');
    }
    final base = Uri.parse(baseUrl.trim());
    if (!base.hasScheme || base.host.isEmpty) {
      throw const FormatException(
          'MW_PROFILE_API_BASE_URL debe ser una URL completa.');
    }
    final uri = base.resolve(path);
    final ownsClient = client == null;
    final activeClient = client ?? http.Client();
    try {
      final response = await activeClient
          .post(uri,
              headers: const {'content-type': 'application/json'},
              body: jsonEncode(request.toJson()))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
            'MW Profile respondió HTTP ${response.statusCode}: ${response.body}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
            'MW Profile debe responder un objeto JSON.');
      }
      return LinkProfile.fromJson(decoded);
    } finally {
      if (ownsClient) activeClient.close();
    }
  }
}

class HttpException implements Exception {
  const HttpException(this.message);
  final String message;
  @override
  String toString() => message;
}
