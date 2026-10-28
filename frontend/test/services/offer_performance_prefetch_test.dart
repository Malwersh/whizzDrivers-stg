import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/offer_performance_prefetch.dart';

void main() {
  var clock = DateTime.utc(2026, 10, 25, 12);
  Map<String, dynamic> data(double rate) => {
        'projection': {
          'status': 'CURRENT',
          'validUntil': clock.add(const Duration(minutes: 5)).toIso8601String()
        },
        'acceptanceRate': rate
      };
  setUp(() => clock = DateTime.utc(2026, 10, 25, 12));
  test('arrival prefetch and opening share one load and reuse the fresh result',
      () async {
    var calls = 0;
    final gate = Completer<Map<String, dynamic>?>();
    final c = OfferPerformancePrefetch(
        load: () {
          calls++;
          return gate.future;
        },
        now: () => clock);
    final preload = c.prefetch('driver'), opening = c.read('driver');
    gate.complete(data(.9));
    await preload;
    expect((await opening)?['acceptanceRate'], .9);
    expect((await c.read('driver'))?['acceptanceRate'], .9);
    expect(calls, 1);
  });
  test('old data refreshes before opening', () async {
    var calls = 0;
    final c = OfferPerformancePrefetch(
        load: () async {
          calls++;
          return data(calls == 1 ? 0.9 : 0.8);
        },
        now: () => clock);
    await c.prefetch('driver');
    clock = clock.add(const Duration(seconds: 6));
    expect((await c.read('driver'))?['acceptanceRate'], .8);
    expect(calls, 2);
  });
  test('published validity overrides local freshness', () async {
    var calls = 0;
    final c = OfferPerformancePrefetch(
        load: () async {
          calls++;
          final row = data(.9);
          if (calls == 1)
            row['projection']['validUntil'] =
                clock.add(const Duration(seconds: 1)).toIso8601String();
          return row;
        },
        now: () => clock);
    await c.prefetch('driver');
    clock = clock.add(const Duration(seconds: 2));
    await c.read('driver');
    expect(calls, 2);
  });
  test('an old account response cannot replace the new account result',
      () async {
    final old = Completer<Map<String, dynamic>?>();
    var calls = 0;
    final c = OfferPerformancePrefetch(
        load: () {
          calls++;
          return calls == 1 ? old.future : Future.value(data(.8));
        },
        now: () => clock);
    final previous = c.read('old');
    expect((await c.read('new'))?['acceptanceRate'], .8);
    old.complete(data(.2));
    expect(await previous, isNull);
    expect((await c.read('new'))?['acceptanceRate'], .8);
    expect(calls, 2);
  });
  test('decision invalidation drops in-flight old results', () async {
    final gate = Completer<Map<String, dynamic>?>();
    final c =
        OfferPerformancePrefetch(load: () => gate.future, now: () => clock);
    final pending = c.read('driver');
    c.clear();
    gate.complete(data(.9));
    expect(await pending, isNull);
  });
  test('a pending projection is retried before it can be presented', () async {
    var calls = 0;
    final c = OfferPerformancePrefetch(
        load: () async {
          calls++;
          return calls == 1
              ? {
                  'projection': {'status': 'UPDATING'}
                }
              : data(.9);
        },
        now: () => clock,
        pause: () async {});
    expect((await c.read('driver'))?['acceptanceRate'], .9);
    expect(calls, 2);
  });
  test('network failure is bounded and never returns a stale rate', () async {
    var calls = 0;
    final c = OfferPerformancePrefetch(
        load: () async {
          calls++;
          throw StateError('offline');
        },
        now: () => clock,
        pause: () async {});
    expect(await c.read('driver'), isNull);
    expect(calls, 3);
  });
}
