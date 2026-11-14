import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/services/profile_completion_service.dart';

void main() {
  ProfileCompletionService service(int status, String body) =>
      ProfileCompletionService(
          tokenResolver: () async => 'test-token',
          client: MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer test-token');
            return http.Response(body, status);
          }));
  test('approved driver is not sent back to registration', () async {
    final result =
        await service(200, '{"data":{"status":"APPROVED","name":"Driver"}}')
            .checkProfileCompleteness();
    expect(result.canAccessMainApp, isTrue);
    expect(result.needsRedirect, isFalse);
  });
  for (final code in [401, 403, 429, 500, 502]) {
    test('HTTP $code never claims missing account or registers driver',
        () async {
      final result = await service(code, '{}').checkProfileCompleteness();
      expect(result.redirectPath, '/profile-check');
      expect(result.error, isNotNull);
      expect(result.canAccessMainApp, isFalse);
      expect(result.missingFields, isEmpty);
    });
  }
  test('network loss is retryable without registration', () async {
    final result = await ProfileCompletionService(
            tokenResolver: () async => 'test',
            client:
                MockClient((_) async => throw http.ClientException('offline')))
        .checkProfileCompleteness();
    expect(result.redirectPath, '/profile-check');
    expect(result.error, isNotNull);
  });
  test('confirmed missing profile still requires completion', () async {
    expect((await service(404, '{}').checkProfileCompleteness()).redirectPath,
        '/driver-profile-setup');
  });
  test('malformed successful response does not request registration', () async {
    expect((await service(200, '{}').checkProfileCompleteness()).redirectPath,
        '/profile-check');
  });
  test('no signed in session routes to login', () async {
    expect(
        (await ProfileCompletionService(tokenResolver: () async => null)
                .checkProfileCompleteness())
            .redirectPath,
        '/login');
  });
}
