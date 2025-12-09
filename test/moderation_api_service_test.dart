import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:upstyles_admin/src/services/moderation_api_service.dart';

void main() {
  test('getModerationMonthlyCost parses response', () async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/api/admin/moderation/monthly-cost')) {
        return http.Response(jsonEncode({
          'success': true,
          'month': '2025-12',
          'totalCost': 12.34,
          'totalImages': 820,
          'requestCount': 200,
          'averageCostPerImage': 0.0015
        }), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('Not Found', 404);
    });

    final service = ModerationApiService.withTokenProvider(
      httpClient: mockClient,
      tokenProvider: () async => 'fake-token',
    );

    final resp = await service.getModerationMonthlyCost();
    expect(resp['success'], true);
    expect(resp['totalCost'], 12.34);
    expect(resp['totalImages'], 820);
  });

  test('getModerationStats parses response', () async {
    final mockClient = MockClient((request) async {
      if (request.url.path.endsWith('/api/admin/moderation/stats')) {
        return http.Response(jsonEncode({
          'success': true,
          'stats': {
            'totalImages': 820,
            'totalCost': 12.34,
            'byDay': {
              '2025-12-08': {'images': 40, 'cost': 0.06},
              '2025-12-09': {'images': 50, 'cost': 0.075}
            }
          }
        }), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('Not Found', 404);
    });

    final service = ModerationApiService.withTokenProvider(
      httpClient: mockClient,
      tokenProvider: () async => 'fake-token',
    );

    final stats = await service.getModerationStats();
    expect(stats['stats']['totalImages'], 820);
    expect(stats['stats']['byDay']['2025-12-09']['images'], 50);
  });
}
