import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/home/widgets/decline_acceptance_impact.dart';

Map<String, dynamic> snapshot(List<String> statuses) => {
      'projection': {'status': 'CURRENT'},
      'acceptanceRate': statuses.isEmpty
          ? null
          : statuses.where((s) => s == 'ACCEPTED').length / statuses.length,
      'acceptance': {
        'accepted': statuses.where((s) => s == 'ACCEPTED').length,
        'sampleSize': statuses.length,
        'windowComplete': true
      },
      'details': {
        'acceptance': statuses
            .asMap()
            .entries
            .map((e) => {
                  'offerId': 'old${e.key}',
                  'status': e.value,
                  'sentAt': DateTime.utc(2026, 10, 25)
                      .subtract(Duration(minutes: e.key + 1))
                      .toIso8601String()
                })
            .toList()
      },
    };
void main() {
  final sent = DateTime.utc(2026, 10, 25, 1);
  DeclineAcceptanceEstimate preview(Map<String, dynamic> s) =>
      DeclineAcceptanceEstimate.read(s, offerId: 'new', sentAt: sent);
  test('short window uses actual denominator, not percentage minus one', () {
    final r = preview(snapshot(['ACCEPTED', 'ACCEPTED', 'DECLINED']));
    expect(r.current, closeTo(2 / 3, 1e-9));
    expect(r.after, .5);
  });
  test('full rolling window evicts an accepted oldest offer', () {
    final r = preview(snapshot(List.filled(100, 'ACCEPTED')));
    expect(r.current, 1);
    expect(r.after, .99);
  });
  test('evicting a rejection leaves acceptance unchanged', () {
    final r = preview(snapshot([...List.filled(99, 'ACCEPTED'), 'DECLINED']));
    expect(r.current, .99);
    expect(r.after, .99);
  });
  test('empty history has no invented current rate, first decline becomes zero',
      () {
    final r = preview(snapshot([]));
    expect(r.current, isNull);
    expect(r.after, 0);
  });
  test('stale or incomplete projection never fabricates a prediction', () {
    final s = snapshot(['ACCEPTED']);
    s['projection'] = {'status': 'UPDATING'};
    expect(preview(s).after, isNull);
    s['projection'] = {'status': 'CURRENT'};
    s['acceptance']['windowComplete'] = false;
    expect(preview(s).after, isNull);
  });
  test('already recorded offer cannot be counted twice', () {
    final s = snapshot(['ACCEPTED']);
    s['details']['acceptance'][0]['offerId'] = 'new';
    expect(preview(s).after, isNull);
  });
  test('old offer outside full newest-100 window does not change rate', () {
    final s = snapshot(List.filled(100, 'ACCEPTED'));
    final r = DeclineAcceptanceEstimate.read(s,
        offerId: 'new', sentAt: DateTime.utc(2026, 10, 1));
    expect(r.after, 1);
  });
  testWidgets('both percentages render in the very first sheet frame',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DeclineAcceptanceImpact(
                offerId: 'new',
                sentAt: sent,
                snapshot: snapshot(['ACCEPTED', 'ACCEPTED', 'DECLINED'])))));
    expect(find.text('66.7٪'), findsOneWidget);
    expect(find.text('50.0٪'), findsOneWidget);
    expect(find.text('—'), findsNothing);
    expect(find.byType(FutureBuilder<Map<String, dynamic>?>), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('failed preloading shows a clear fallback without loading dashes',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DeclineAcceptanceImpact(
                offerId: 'new', sentAt: sent, snapshot: null))));
    expect(find.text('—'), findsNothing);
    expect(find.textContaining('تعذر تحميل تقدير'), findsOneWidget);
  });
}
