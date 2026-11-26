import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/config/environment.dart';
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
  test(
      'staging absence leads to setup; production requires a valid profile response',
      () async {
    expect((await service(404, '{}').checkProfileCompleteness()).redirectPath,
        Environment.isProduction ? '/profile-check' : '/driver-profile-setup');
  });
  test('new verified driver enters the existing profile setup', () async {
    final result = await service(
      200,
      '{"data":{"status":"PENDING_PROFILE","isVerified":false}}',
    ).checkProfileCompleteness();
    expect(result.redirectPath, '/driver-profile-setup');
    expect(result.canAccessMainApp, isFalse);
    expect(result.error, isNull);
  });
  test('submitted profile stays in review on restart', () async {
    final result = await service(
      200,
      '{"data":{"status":"PENDING_REVIEW","isVerified":false}}',
    ).checkProfileCompleteness();
    expect(result.redirectPath, '/pending-review');
  });
  test('malformed successful response does not request registration', () async {
    expect((await service(200, '{}').checkProfileCompleteness()).redirectPath,
        '/profile-check');
  });
  test('profile authorization retries once with Cognito refresh', () async {
    var refreshes = 0;
    final tokens = <String?>[];
    final result = await ProfileCompletionService(
      tokenResolver: () async => 'short-lived',
      refreshedTokenResolver: () async {
        refreshes++;
        return 'renewed';
      },
      client: MockClient((request) async {
        final authorization = request.headers['Authorization'];
        tokens.add(authorization);
        return authorization == 'Bearer renewed'
            ? http.Response(
                '{"data":{"status":"APPROVED","isVerified":true}}', 200)
            : http.Response('{}', 401);
      }),
    ).checkProfileCompleteness();
    expect(refreshes, 1);
    expect(tokens, ['Bearer short-lived', 'Bearer renewed']);
    expect(result.canAccessMainApp, isTrue);
  });

  test('network failure during refresh keeps the existing sign-in retryable',
      () async {
    final result = await ProfileCompletionService(
      tokenResolver: () async => 'short-lived',
      refreshedTokenResolver: () async => throw http.ClientException('offline'),
      client: MockClient((_) async => http.Response('{}', 401)),
    ).checkProfileCompleteness();
    expect(result.redirectPath, '/profile-check');
  });

  test('confirmed expiration after refresh returns to phone login', () async {
    final result = await ProfileCompletionService(
      tokenResolver: () async => 'short-lived',
      refreshedTokenResolver: () async => null,
      client: MockClient((_) async => http.Response('{}', 401)),
    ).checkProfileCompleteness();
    expect(result.redirectPath, '/login');
  });

  test('no signed in session routes to login', () async {
    expect(
        (await ProfileCompletionService(tokenResolver: () async => null)
                .checkProfileCompleteness())
            .redirectPath,
        '/login');
  });
}
