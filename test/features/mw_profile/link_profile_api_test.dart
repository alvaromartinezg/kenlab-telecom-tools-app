import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kenlab_telecom_tools/features/mw_profile/data/mw_profile_api.dart';
import 'package:kenlab_telecom_tools/features/mw_profile/models/link_profile.dart';

void main() {
  test('serializes both signed site coordinates and antenna heights', () {
    const request = LinkProfileRequest(
      siteA: SiteProfileInput(
          latitude: -12.1, longitude: -77.2, antennaHeightMeters: 30),
      siteB: SiteProfileInput(
          latitude: 4.6, longitude: 3.2, antennaHeightMeters: 24),
    );

    expect(request.toJson(), {
      'site_a': {'lat': -12.1, 'long': -77.2, 'height_m': 30},
      'site_b': {'lat': 4.6, 'long': 3.2, 'height_m': 24},
    });
  });

  test('posts the documented contract and parses the returned profile',
      () async {
    http.Request? capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'distance_m': 1420.7,
          'azimuth_a_deg': 106.2,
          'azimuth_b_deg': 286.2,
          'site_a_ground_altitude_m': 154.8,
          'site_b_ground_altitude_m': 162.1,
          'tilt_a_deg': 0.29,
          'tilt_b_deg': -0.29,
          'profile': [
            {
              'distance_m': 0,
              'terrain_altitude_m': 154.8,
              'line_of_sight_altitude_m': 184.8,
              'fresnel_radius_m': 0,
            },
            {
              'distance_m': 1420.7,
              'terrain_altitude_m': 162.1,
              'line_of_sight_altitude_m': 186.1,
              'fresnel_radius_m': 0,
            },
          ],
        }),
        200,
      );
    });

    final api = MwProfileApi(
      baseUrl: 'https://mwprofile.example',
      path: '/api/v1/line-of-sight/profile',
      client: client,
    );
    final result = await api.calculateProfile(const LinkProfileRequest(
      siteA: SiteProfileInput(
          latitude: -12.1, longitude: -77.2, antennaHeightMeters: 30),
      siteB: SiteProfileInput(
          latitude: -12.2, longitude: -77.3, antennaHeightMeters: 24),
    ));
    client.close();

    expect(capturedRequest!.method, 'POST');
    expect(capturedRequest!.url.path, '/api/v1/line-of-sight/profile');
    expect(capturedRequest!.headers['content-type'], 'application/json');
    expect(jsonDecode(capturedRequest!.body), {
      'site_a': {'lat': -12.1, 'long': -77.2, 'height_m': 30},
      'site_b': {'lat': -12.2, 'long': -77.3, 'height_m': 24},
    });
    expect(result.distanceMeters, 1420.7);
    expect(result.siteBGroundAltitudeMeters, 162.1);
    expect(result.profile, hasLength(2));
    expect(result.profile.last.lineOfSightAltitudeMeters, 186.1);
  });
}
