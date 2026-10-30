import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/features/more/screens/offer_sound_test_sheet.dart';

void main() {
  testWidgets(
      'test button reports low hardware volume without claiming audibility',
      (t) async {
    int count = 0;
    await t.pumpWidget(
        MaterialApp(home: Scaffold(body: OfferSoundTestSheet(play: () async {
      count++;
      return {'playing': true, 'volume': 0};
    }))));
    await t.tap(find.text('تشغيل الصوت'));
    await t.pumpAndSettle();
    expect(count, 1);
    expect(find.textContaining('مستوى صوت الوسائط منخفض'), findsOneWidget);
  });
  testWidgets('test button reports playback failure and allows retry',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: OfferSoundTestSheet(play: () async => {'playing': false}))));
    await t.tap(find.text('تشغيل الصوت'));
    await t.pumpAndSettle();
    expect(find.textContaining('تعذر تشغيل الصوت'), findsOneWidget);
    expect(find.text('تشغيل الصوت'), findsOneWidget);
  });
}
