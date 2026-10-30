import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/wallet_funding_service.dart';

String token(String sub) =>
    'x.${base64Url.encode(utf8.encode(jsonEncode({'sub': sub})))}.x';
Map<String, dynamic> payload(String sub) => {
      'amount': 25000,
      'method': 'MANUAL_VERIFICATION',
      'evidenceRef': 'receipts/$sub/12345678-1234-4123-8123-123456789012.jpg',
      'transferReference': 'REF1234',
      'configVersion': 1
    };
Map<String, dynamic> saved(String sub, Map<String, dynamic> body,
        {String status = 'PENDING'}) =>
    {...body, 'topupId': 'topup1', 'driverId': sub, 'status': status};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('first definitive amount-limit rejection releases draft for correction',()async{
    final api=WalletFundingService(token:()async=>token('driverA'),client:MockClient((req)async=>http.Response(jsonEncode({'error':{'code':'FUNDING_AMOUNT_LIMIT','message':'Funding limits changed'}}),409)));
    await api.initialize();await expectLater(api.submit(payload:{...payload('driverA'),'amount':15000}),throwsA(isA<FundingRejected>()));expect(api.hasPending,isFalse);
  });
  test(
      'lost response survives reopening and retries the exact immutable request',
      () async {
    final posts = <Map<String, dynamic>>[];
    final api = WalletFundingService(
        token: () async => token('driverA'),
        client: MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          posts.add(body);
          throw TimeoutException('lost');
        }));
    await api.initialize();
    await expectLater(api.submit(payload: payload('driverA')),
        throwsA(isA<TimeoutException>()));
    expect(api.hasPending, isTrue);
    final retry = WalletFundingService(
        token: () async => token('driverA'),
        client: MockClient((req) async {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          posts.add(body);
          return http.Response(
              jsonEncode(
                  {'success': true, 'topupRequest': saved('driverA', body)}),
              201);
        }));
    await retry.initialize();
    expect(retry.pending, posts.first);
    await retry.submit(payload: {...payload('driverA'), 'amount': 99999});
    expect(posts.last, posts.first);
    expect(retry.hasPending, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('wallet_funding_pending')),
        isEmpty);
  });
  test(
      'account change blocks outgoing request and does not expose old pending draft',
      () async {
    var current = token('driverA');
    var writes = 0;
    final api = WalletFundingService(
        token: () async => current,
        client: MockClient((req) async {
          writes++;
          throw TimeoutException('lost');
        }));
    await api.initialize();
    await expectLater(api.submit(payload: payload('driverA')),
        throwsA(isA<TimeoutException>()));
    current = token('driverB');
    await expectLater(api.submit(), throwsA(isA<FundingSessionChanged>()));
    expect(writes, 1);
    final b = WalletFundingService(
        token: () async => current,
        client: MockClient((_) async => http.Response('{}', 200)));
    await b.initialize();
    expect(b.pending, isNull);
  });
  test('late account-A response is rejected after switching accounts',
      () async {
    var current = token('driverA');
    final response = Completer<http.Response>();
    final api = WalletFundingService(
        token: () async => current, client: MockClient((_) => response.future));
    await api.initialize();
    final reading = api.call('/wallet/funding/config');
    await Future<void>.delayed(Duration.zero);
    current = token('driverB');
    response.complete(http.Response(
        jsonEncode({
          'manual': {'phone': 'private-A'}
        }),
        200));
    await expectLater(reading, throwsA(isA<FundingSessionChanged>()));
  });
  test('refreshing a token for the same account is allowed', () async {
    var current = token('driverA');
    final api = WalletFundingService(
        token: () async => current,
        client: MockClient((_) async {
          current = 'new.${token('driverA').split('.')[1]}.new';
          return http.Response('{}', 200);
        }));
    await api.initialize();
    expect(await api.call('/wallet/funding/config'), isEmpty);
  });
  test('history resolves only an exact owned receipt/reference/amount match',
      () async {
    var history = <Map<String, dynamic>>[];
    final api = WalletFundingService(
        token: () async => token('driverA'),
        client: MockClient((req) async {
          if (req.method == 'POST') throw TimeoutException('lost');
          return http.Response(jsonEncode({'requests': history}), 200);
        }));
    await api.initialize();
    await expectLater(api.submit(payload: payload('driverA')),
        throwsA(isA<TimeoutException>()));
    history = [
      saved('other', payload('driverA')),
      saved('driverA', {...payload('driverA'), 'amount': 30000})
    ];
    await api.history();
    expect(api.hasPending, isTrue);
    history = [saved('driverA', payload('driverA'), status: 'APPROVED')];
    await api.history();
    expect(api.hasPending, isFalse);
  });
  test('malformed success cannot clear retry evidence', () async {
    final api = WalletFundingService(
        token: () async => token('driverA'),
        client:
            MockClient((_) async => http.Response('{"success":true}', 201)));
    await api.initialize();
    await expectLater(api.submit(payload: payload('driverA')), throwsException);
    expect(api.hasPending, isTrue);
  });
  test(
      'definite precreation rejection unlocks a new attempt; after uncertainty preserves it',
      () async {
    var first = true;
    final api = WalletFundingService(
        token: () async => token('driverA'),
        client: MockClient((_) async {
          if (first) {
            first = false;
            throw TimeoutException('lost');
          }
          return http.Response(
              jsonEncode({
                'error': {
                  'code': 'CONFIG_CHANGED',
                  'message': 'تغيرت الإعدادات'
                }
              }),
              409,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    await api.initialize();
    await expectLater(api.submit(payload: payload('driverA')),
        throwsA(isA<TimeoutException>()));
    await expectLater(api.submit(), throwsA(isA<FundingRejected>()));
    expect(api.hasPending, isTrue);
    final fresh = WalletFundingService(
        token: () async => token('driverB'),
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'error': {'code': 'CONFIG_CHANGED', 'message': 'تغيرت الإعدادات'}
            }),
            409,
            headers: {'content-type': 'application/json; charset=utf-8'})));
    await fresh.initialize();
    await expectLater(fresh.submit(payload: payload('driverB')),
        throwsA(isA<FundingRejected>()));
    expect(fresh.hasPending, isFalse);
  });
  test('concurrent submit cannot create a second request', () async {
    var posts = 0;
    final response = Completer<http.Response>();
    final api = WalletFundingService(
        token: () async => token('driverA'),
        client: MockClient((_) {
          posts++;
          return response.future;
        }));
    await api.initialize();
    final pending = api.submit(payload: payload('driverA'));
    await Future<void>.delayed(Duration.zero);
    await expectLater(api.submit(payload: payload('driverA')), throwsException);
    response.complete(http.Response(
        jsonEncode({
          'success': true,
          'topupRequest': saved('driverA', payload('driverA'))
        }),
        201));
    await pending;
    expect(posts, 1);
  });
}
