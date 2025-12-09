import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:upstyles_admin/src/screens/analytics/costs_tab.dart';
import 'package:upstyles_admin/src/services/moderation_api_service.dart';

import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

// Use a mock HTTP client to create a real ModerationApiService instance
ModerationApiService _makeFakeService() {
  final mockClient = MockClient((request) async {
    final path = request.url.path;
    if (path.contains('/api/admin/moderation/monthly-cost')) {
      return http.Response(jsonEncode({
        'success': true,
        'month': '2025-12',
        'totalCost': 5.5,
        'totalImages': 100,
        'averageCostPerImage': 0.0015,
      }), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/api/admin/moderation/stats')) {
      return http.Response(jsonEncode({
        'stats': {
          'byDay': {
            '2025-12-08': {'images': 40, 'cost': 0.06},
          }
        }
      }), 200, headers: {'content-type': 'application/json'});
    }
    return http.Response('Not Found', 404);
  });

  return ModerationApiService.withTokenProvider(
    httpClient: mockClient,
    tokenProvider: () async => 'fake-token',
  );
}

void main() {
  testWidgets('CostsTab shows cost numbers and recommendations', (WidgetTester tester) async {
    final fake = _makeFakeService();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CostsTab(api: fake))));
    await tester.pumpAndSettle();

    expect(find.text('Costs & Recommendations'), findsOneWidget);
    expect(find.text('\$5.50'), findsOneWidget);
    expect(find.text('Images Processed'), findsOneWidget);
    expect(find.text('Recommendations'), findsOneWidget);
  });
}
