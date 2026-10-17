import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wizz_driver/services/offer_closure_inbox.dart';
import 'package:wizz_driver/models/wave_offer.dart';
import 'package:wizz_driver/services/push_notifications_service.dart';

Map<String, dynamic> closed(
        {String driver = 'driver1',
        String offer = 'offer1',
        String cycle = 'cycle1'}) =>
    {
      'type': 'offer_taken',
      'action': 'remove_offer',
      'driverId': driver,
      'offerId': offer,
      'orderId': 'order1',
      'cycleId': cycle,
      'eventId': 'DISPATCH_NOTICE:event1'
    };
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'a closure tap is stored only as an invalidation and routes home, never a new offer',
      () async {
    await PushNotificationsService.stashWaveOfferFromTap(
        RemoteMessage(data: closed()));
    await PushNotificationsService.stashPendingTabFromTap(
        RemoteMessage(data: closed()));
    expect(await PushNotificationsService.consumeStashedWaveOfferFromTap(),
        isNull);
    expect(await PushNotificationsService.consumePendingTabFromTap(), 0);
    expect((await OfferClosureInbox.read('driver1')).single.offerId, 'offer1');
  });
  test(
      'legacy malformed closure stash is discarded instead of becoming a 45 second offer',
      () async {
    SharedPreferences.setMockInitialValues({
      'pendingWaveOfferFromPushTap': jsonEncode(
          {'type': 'offer_taken', 'offerId': 'offer1', 'orderId': 'order1'})
    });
    expect(await PushNotificationsService.consumeStashedWaveOfferFromTap(),
        isNull);
    expect(await OfferClosureInbox.read('driver1'), isEmpty);
  });
  test(
      'socket and push converge on one stored invalidation and duplicate delivery emits once',
      () async {
    final events = <OfferClosure>[],
        sub = OfferClosureInbox.events.listen(events.add);
    await OfferClosureInbox.record(closed(), socketDriverId: 'driver1');
    await OfferClosureInbox.record(closed());
    await Future<void>.delayed(Duration.zero);
    expect(events.length, 1);
    expect((await OfferClosureInbox.read('driver1')).length, 1);
    await sub.cancel();
  });
  test(
      'owning driver and cycle isolate closures, and unknown cycle fails closed',
      () async {
    await OfferClosureInbox.record(closed());
    expect(await OfferClosureInbox.read('driver2'), isEmpty);
    final scope = OfferClosureScope()..bind('driver1'),
        expiry = DateTime.now().add(const Duration(minutes: 1));
    Future<bool> allows(String? cycle) => scope.allows(
        offerId: 'offer1',
        orderId: 'order1',
        cycleId: cycle,
        expiresAt: expiry);
    expect(await allows('cycle1'), false);
    expect(await allows(null), false);
    expect(await allows('cycle2'), true);
    scope.bind('driver2');
    expect(await allows('cycle1'), true);
  });
  test(
      'another account or logout invalidates a preference read already in flight',
      () async {
    final wait = Completer<List<OfferClosure>>(),
        scope = OfferClosureScope(read: (_) => wait.future)..bind('driver1');
    final pending = scope.allows(
        offerId: 'offer1',
        orderId: 'order1',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)));
    scope.bind(null);
    scope.bind('driver2');
    wait.complete([]);
    expect(await pending, false);
  });
  test(
      'closures survive a restarted preferences cache and different keys do not overwrite each other',
      () async {
    await Future.wait([
      OfferClosureInbox.record(closed()),
      OfferClosureInbox.record(closed(offer: 'offer2'))
    ]);
    expect(
        (await OfferClosureInbox.read('driver1')).map((e) => e.offerId).toSet(),
        {'offer1', 'offer2'});
  });
  test(
      'expiry and cleanup preserve unrelated preferences and prevent expired offers without a closure',
      () async {
    final at = DateTime.utc(2026, 10, 16);
    await OfferClosureInbox.record(closed(), now: at);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unrelated', 'keep');
    expect(
        await OfferClosureInbox.read('driver1',
            now: at.add(const Duration(hours: 25))),
        isEmpty);
    final scope = OfferClosureScope(now: () => at)..bind('driver1');
    expect(
        await scope.allows(offerId: 'offer1', orderId: 'order1', expiresAt: at),
        false);
    await OfferClosureInbox.clear();
    expect(prefs.getString('unrelated'), 'keep');
  });
  test(
      'invalid identity and malformed IDs cannot enter the socket owner namespace',
      () async {
    expect(
        await OfferClosureInbox.record(closed(driver: 'other'),
            socketDriverId: 'driver1'),
        isNull);
    expect(
        await OfferClosureInbox.record({...closed(), 'offerId': '../foreign'}),
        isNull);
    expect(await OfferClosureInbox.record({...closed(), 'driverId': null}),
        isNull);
    expect(await OfferClosureInbox.read('driver1'), isEmpty);
  });
  test(
      'a positive push stays separate and carries its owner, cycle and real expiry',
      () async {
    await PushNotificationsService.stashWaveOfferFromTap(
        const RemoteMessage(data: {
      'type': 'new_wave_offer',
      'driverId': 'driver1',
      'offerId': 'offer1',
      'orderId': 'order1',
      'cycleId': 'cycle1',
      'expiresAt': '2026-10-16T12:00:00Z'
    }));
    final payload =
        await PushNotificationsService.consumeStashedWaveOfferFromTap();
    expect(payload!['driverId'], 'driver1');
    expect(payload['cycleId'], 'cycle1');
    expect(payload['expiresAt'], '2026-10-16T12:00:00Z');
    expect(await OfferClosureInbox.read('driver1'), isEmpty);
  });
  test(
      'a background closure arriving before the old positive push still blocks resurrection',
      () async {
    await OfferClosureInbox.record(closed());
    await PushNotificationsService.stashWaveOfferFromTap(
        const RemoteMessage(data: {
      'type': 'new_wave_offer',
      'driverId': 'driver1',
      'offerId': 'offer1',
      'orderId': 'order1'
    }));
    final payload =
        await PushNotificationsService.consumeStashedWaveOfferFromTap();
    final scope = OfferClosureScope()..bind('driver1');
    expect(
        await scope.allows(
            offerId: payload!['offerId'],
            orderId: payload['orderId'],
            expiresAt: DateTime.now().add(const Duration(minutes: 1))),
        false);
  });
  test('failed local revalidation cannot permit display or submission',
      () async {
    final scope =
        OfferClosureScope(read: (_) async => throw StateError('read failed'))
          ..bind('driver1');
    expect(
        await scope.allows(
            offerId: 'offer1',
            orderId: 'order1',
            expiresAt: DateTime.now().add(const Duration(minutes: 1))),
        false);
  });
  test('returning to the original account does not revive its pre-switch read',
      () async {
    final wait = Completer<List<OfferClosure>>(),
        scope = OfferClosureScope(read: (_) => wait.future)..bind('driver1');
    final pending = scope.allows(
        offerId: 'offer1',
        orderId: 'order1',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)));
    scope.bind('driver2');
    scope.bind('driver1');
    wait.complete([]);
    expect(await pending, false);
  });
  test(
      'serializing an offer preserves the cycle used to enforce its stored closure',
      () async {
    await OfferClosureInbox.record(closed());
    final at = DateTime.now(),
        offer = WaveOffer.fromJson({
          'offerId': 'offer1',
          'orderId': 'order1',
          'jobId': 'job1',
          'dispatchCycleId': 'cycle1',
          'sentAt': at.toIso8601String(),
          'expiresAt': at.add(const Duration(minutes: 1)).toIso8601String()
        });
    final restored = WaveOffer.fromJson(offer.toJson()),
        scope = OfferClosureScope()..bind('driver1');
    expect(
        await scope.allows(
            offerId: restored.offerId,
            orderId: restored.orderId,
            cycleId: restored.dispatchCycleId,
            expiresAt: restored.expiresAt),
        false);
  });
}
