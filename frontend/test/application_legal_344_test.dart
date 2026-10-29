import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wizz_driver/legal/application_legal_bundle.dart';
import 'package:wizz_driver/legal/application_legal_service.dart';
import 'package:wizz_driver/legal/application_legal_screen.dart';
import 'package:wizz_driver/legal/application_legal_consent.dart';

Map<String, dynamic> fixture() => jsonDecode(
    File('test/fixtures/application_legal_344.json').readAsStringSync());

class FakeLegal extends ApplicationLegalService {
  @override
  Future<ApplicationLegalBundle> load({bool refresh = false}) async =>
      ApplicationLegalBundle.fromJson(fixture());
}

void main() {
  test('published bundle belongs to this role and preserves its version', () {
    final b = ApplicationLegalBundle.fromJson(fixture());
    expect(b.audience, 'DRIVER');
    expect(b.documents.length, 4);
  });
  test('reader requests only this application policy', () async {
    final s = ApplicationLegalService(client: MockClient((r) async {
      expect(r.url.queryParameters['audience'], 'DRIVER');
      return http.Response.bytes(
          utf8.encode(jsonEncode({'bundle': fixture()})), 200);
    }));
    expect((await s.load()).audience, 'DRIVER');
  });
  testWidgets(
      'role-specific policy reader exposes company footer without overflow',
      (t) async {
    await t.binding.setSurfaceSize(const Size(375, 760));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
        MaterialApp(home: ApplicationLegalScreen(service: FakeLegal())));
    await t.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(4));
    await t.dragUntilVisible(find.text('شركة الانطلاق الخاطف'),
        find.byType(ListView), const Offset(0, -300));
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'registration checkbox starts false and opening policies does not silently accept them',
      (t) async {
    ApplicationLegalBundle? accepted;
    await t.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ApplicationLegalConsent(
                service: FakeLegal(), onChanged: (b) => accepted = b))));
    await t.pumpAndSettle();
    expect(
        t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, false);
    await t.tap(find.byType(CheckboxListTile));
    await t.pump();
    expect(accepted!.audience, 'DRIVER');
    await t.tap(find.byType(CheckboxListTile));
    await t.pump();
    expect(accepted, isNull);
  });
}
