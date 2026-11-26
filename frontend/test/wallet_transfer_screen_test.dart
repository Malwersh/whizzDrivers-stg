import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/features/wallet/screens/wallet_transfer_screen.dart';
import 'package:wizz_driver/services/wallet_transfer_service.dart';

class FakeTransferApi extends WalletTransferService {
  final requests = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, String>? query, Map<String, dynamic>? body}) async {
    if (path == 'context')
      return {
        'walletId': 'WALLET#DRIVER#test',
        'available': 25000,
        'dailyRemaining': 100000,
        'minAmount': 1000,
        'maxAmount': 100000,
        'dailyLimit': 100000,
        'canTransfer': true
      };
    if (path == 'history') return {'transactions': []};
    if (path == 'recipient')
      return {
        'walletId': 'WALLET#DRIVER#other',
        'name': 'محمد علي',
        'phone': '+9647800000000'
      };
    if (path == 'status') return {'status': 'NOT_FOUND'};
    if (path == 'cancel') return {'status': 'CANCELLED'};
    requests.add(Map.of(body!));
    throw TimeoutException('lost response');
  }
}

class VerificationTransferApi extends FakeTransferApi {
  final attempts = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> call(String path,
      {Map<String, String>? query, Map<String, dynamic>? body}) async {
    if (path == 'otp/send')
      return {
        'challengeId': 'challenge',
        'phoneHint': '••••7435',
        'resendAfter': 60
      };
    if (path == 'otp/verify') return {'verificationId': 'challenge'};
    if (path == 'request') {
      attempts.add(Map.of(body!));
      if (body['verificationId'] == null)
        throw WalletTransferException('تحقق مطلوب', 'REAUTH_REQUIRED');
      return {'status': 'COMPLETED'};
    }
    return super.call(path, query: query, body: body);
  }
}

void main() {
  testWidgets(
      'uncertain transfer survives screen reopening and uses the same request reference',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(450, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final api = FakeTransferApi();
    Future<void> open() async {
      await tester
          .pumpWidget(MaterialApp(home: WalletTransferScreen(service: api)));
      await tester.pumpAndSettle();
    }

    await open();
    await tester.enterText(find.byType(TextField).at(0), '07800000000');
    await tester.tap(find.text('البحث عن المستلم'));
    await tester.pumpAndSettle();
    expect(find.text('محمد علي'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '1000');
    await tester.enterText(find.byType(TextField).at(2), 'اختبار تحويل');
    await tester.ensureVisible(find.text('مراجعة التحويل'));
    await tester.tap(find.text('مراجعة التحويل'));
    await tester.pumpAndSettle();
    expect(api.requests, isEmpty);
    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.pumpAndSettle();
    expect(api.requests.length, 1);
    final id = api.requests.single['requestId'];
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await open();
    await tester.ensureVisible(find.text('التحقق وإكمال التحويل'));
    await tester.tap(find.text('التحقق وإكمال التحويل'));
    await tester.pumpAndSettle();
    expect(api.requests.length, 2);
    expect(api.requests.last['requestId'], id);
  });
  testWidgets('stale session verifies in place and retries the same transfer',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(450, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final api = VerificationTransferApi();
    await tester
        .pumpWidget(MaterialApp(home: WalletTransferScreen(service: api)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '07800000000');
    await tester.tap(find.text('البحث عن المستلم'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '5000');
    await tester.enterText(find.byType(TextField).at(2), 'اختبار تحويل');
    await tester.ensureVisible(find.text('مراجعة التحويل'));
    await tester.tap(find.text('مراجعة التحويل'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد وإرسال'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('تأكيد التحويل برمز الهاتف'), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('transfer_confirmation_code')), '123456');
    await tester.tap(find.text('تأكيد وإكمال التحويل'));
    await tester.pumpAndSettle();
    expect(api.attempts.length, 2);
    expect(api.attempts[1]['requestId'], api.attempts[0]['requestId']);
    expect(api.attempts[1]['verificationId'], 'challenge');
    expect(find.text('تم التحويل بنجاح'), findsOneWidget);
    expect(
        (await SharedPreferences.getInstance())
            .getString('wallet_pending_transfer_WALLET#DRIVER#test'),
        isNull);
  });
}
