import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/driver_offer_audio.dart';

void main() {
  test('FCM and socket cues for one offer coalesce after successful playback',
      () async {
    final gate = Completer<bool>(), d = OfferAudioDeduplicator();
    int calls = 0;
    Future<bool> cue() {
      calls++;
      return gate.future;
    }

    final a = d.play('offer', cue), b = d.play('offer', cue);
    gate.complete(true);
    await Future.wait([a, b]);
    await d.play('offer', cue);
    expect(calls, 1);
  });
  test('a failed first cue does not suppress the socket retry', () async {
    final d = OfferAudioDeduplicator();
    int calls = 0;
    await d.play('offer', () async {
      calls++;
      return false;
    });
    await d.play('offer', () async {
      calls++;
      return true;
    });
    expect(calls, 2);
  });
}
