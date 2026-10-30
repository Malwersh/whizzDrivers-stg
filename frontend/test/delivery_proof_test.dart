import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:wizz_driver/features/active_order/services/delivery_proof_service.dart';
import 'package:wizz_driver/features/active_order/widgets/delivery_proof_card.dart';
import 'package:wizz_driver/features/active_order/models/active_order_model.dart';

void main() {
  test('preprocessing produces JPEG with no EXIF and bounded dimensions', () {
    final image = img.Image(width: 1800, height: 200);
    image.exif.imageIfd['Make'] = 'TEST';
    final result =
        prepareDeliveryPhoto(Uint8List.fromList(img.encodeJpg(image)));
    final decoded = img.decodeJpg(result)!;
    expect(decoded.width, 1600);
    expect(decoded.exif.isEmpty, isTrue);
    expect(result.length, lessThan(1500001));
  });
  test('transport pins login across upload', () async {
    String? token = 'a';
    final bytes = Uint8List.fromList([1, 2, 3]);
    final service = DeliveryProofService(
        token: () async => token,
        client: MockClient((request) async {
          token = 'b';
          return http.Response(
              jsonEncode({
                'success': true,
                'orderId': 'order1',
                'proof': {
                  'id': 'proof1',
                  'sha256': sha256.convert(bytes).toString()
                }
              }),
              200);
        }));
    await expectLater(
        service.upload('order1', 'proof1', bytes, null), throwsException);
  });
  testWidgets('saved label waits for receipt; retry uses identical photo ID',
      (t) async {
    final ids = <String>[];
    final response = Completer<http.Response>();
    final service = DeliveryProofService(
        token: () async => 'token',
        client: MockClient((request) async {
          if (request.method == 'GET')
            return http.Response(
                '{"success":true,"orderId":"order1","proofs":[]}', 200);
          final body = jsonDecode(request.body);
          ids.add(body['proofId']);
          if (ids.length == 1) throw Exception('lost');
          return response.future;
        }));
    final photo =
        Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DeliveryProofCard(
                order: ActiveOrder.fromJson({'orderId': 'order1', 'items': []}),
                onBusy: (_) {},
                service: service,
                pick: () async => photo))));
    await t.pumpAndSettle();
    await t.tap(find.text('التقاط وحفظ صورة'));
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pumpAndSettle();
    expect(find.text('صورة محفوظة مع الطلب'), findsNothing);
    expect(find.text('إعادة محاولة حفظ الصورة'), findsOneWidget);
    await t.tap(find.text('إعادة محاولة حفظ الصورة'));
    await t.pump();
    expect(ids.length, 2);
    expect(ids[0], ids[1]);
    expect(find.text('صورة محفوظة مع الطلب'), findsNothing);
    final prepared = prepareDeliveryPhoto(photo);
    response.complete(http.Response(
        jsonEncode({
          'success': true,
          'orderId': 'order1',
          'proof': {
            'id': ids.last,
            'sha256': sha256.convert(prepared).toString(),
            'uploadedAt': '2026-10-23T04:00:00Z'
          }
        }),
        200));
    await t.pumpAndSettle();
    expect(find.text('صورة محفوظة مع الطلب'), findsOneWidget);
  });
}
