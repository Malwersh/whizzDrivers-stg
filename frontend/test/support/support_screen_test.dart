import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wizz_driver/features/more/screens/live_chat_screen.dart';
import 'package:wizz_driver/services/support_chat_identity.dart';
import 'support_fixture.dart';

class IdentitySource implements SupportChatIdentitySource {
  final changes = StreamController<void>.broadcast(sync: true);
  SupportDriverIdentity? owner = const SupportDriverIdentity('driver-sub');
  Completer<SupportDriverIdentity?>? pending;
  @override
  Stream<void> get invalidations => changes.stream;
  @override
  Future<SupportDriverIdentity?> read() async =>
      pending == null ? owner : await pending!.future;
  @override
  Future<String?> tokenFor(String subject) async =>
      owner?.subject == subject ? 'fresh-token' : null;
}

Future<void> mount(
    WidgetTester tester, IdentitySource identity, Fixture fixture) async {
  await tester.pumpWidget(MaterialApp(
      home: LiveChatScreen(
          identitySource: identity,
          chatFactory: (owner) {
            expect(owner.subject, 'driver-sub');
            return fixture.service;
          })));
  await tester.pump();
}

Future<void> confirm(WidgetTester tester, Fixture fixture) async {
  fixture.confirm();
  fixture.channels.last.receive({
    'type': 'session_messages',
    'sessionId': fixture.service.sessionId,
    'requestId': fixture.historyRequest,
    'messages': [],
    'nextCursor': null
  });
  await tester.pump();
}

Future<void> remove(WidgetTester tester, IdentitySource source) async {
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  await source.changes.close();
}

void main() {
  testWidgets('unsigned driver never gets a test identity or a chat connection',
      (tester) async {
    final identity = IdentitySource()..owner = null;
    var created = 0;
    await tester.pumpWidget(MaterialApp(
        home: LiveChatScreen(
            identitySource: identity,
            chatFactory: (_) {
              created++;
              return Fixture().service;
            })));
    await tester.pump();
    expect(
        find.text('سجّل الدخول إلى حسابك للتواصل مع الدعم.'), findsOneWidget);
    expect(created, 0);
    await remove(tester, identity);
  });
  testWidgets('identity resolving after leaving cannot open a conversation',
      (tester) async {
    final identity = IdentitySource()
      ..pending = Completer<SupportDriverIdentity?>();
    var created = 0;
    await tester.pumpWidget(MaterialApp(
        home: LiveChatScreen(
            identitySource: identity,
            chatFactory: (_) {
              created++;
              return Fixture().service;
            })));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    identity.pending!.complete(const SupportDriverIdentity('late'));
    await tester.pump();
    expect(created, 0);
    await identity.changes.close();
  });
  testWidgets(
      'opening support uses authenticated identity and never auto-sends a welcome',
      (tester) async {
    final identity = IdentitySource(), fixture = Fixture();
    await mount(tester, identity, fixture);
    expect(fixture.service.ready, false);
    expect(
        fixture.channels.single.sent.single['action'], 'chat_driver_connect');
    await confirm(tester, fixture);
    expect(
        fixture.channels.single.sent
            .where((m) => m['action'] == 'chat_message'),
        isEmpty);
    expect(find.text('يمكنك مراسلة فريق الدعم'), findsOneWidget);
    await remove(tester, identity);
  });
  testWidgets(
      'failed send keeps the screen draft and does not add a successful bubble',
      (tester) async {
    final identity = IdentitySource(), fixture = Fixture();
    await mount(tester, identity, fixture);
    await confirm(tester, fixture);
    await tester.enterText(find.byType(TextField), 'احتفظ بنصي');
    fixture.channels.single.fakeSink.fail = true;
    await tester.tap(find.byTooltip('إرسال'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'احتفظ بنصي');
    expect(fixture.service.messages, isEmpty);
    await remove(tester, identity);
  });
  testWidgets('screen shows pending then saved once for echo and receipt',
      (tester) async {
    final identity = IdentitySource(), fixture = Fixture();
    await mount(tester, identity, fixture);
    await confirm(tester, fixture);
    await tester.enterText(find.byType(TextField), 'طلب مساعدة');
    await tester.tap(find.byTooltip('إرسال'));
    await tester.pump();
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
    expect(find.text('تم الحفظ'), findsNothing);
    final sent = fixture.channels.single.sent.last;
    fixture.channels.single.receive({
      'type': 'chat_message',
      'sessionId': fixture.service.sessionId,
      'message': {
        'messageId': 'saved',
        'clientMessageId': sent['clientMessageId'],
        'senderType': 'driver',
        'text': 'طلب مساعدة'
      }
    });
    fixture.channels.single.receive({
      'type': 'message_ack',
      'sessionId': fixture.service.sessionId,
      'clientMessageId': sent['clientMessageId'],
      'messageId': 'saved'
    });
    await tester.pump();
    expect(fixture.service.messages.length, 1);
    expect(find.text('تم الحفظ'), findsOneWidget);
    await remove(tester, identity);
  });
  testWidgets(
      'agent reply is rendered and auth invalidation clears messages and draft',
      (tester) async {
    final identity = IdentitySource(), fixture = Fixture();
    await mount(tester, identity, fixture);
    await confirm(tester, fixture);
    fixture.channels.single.receive({
      'type': 'chat_message',
      'sessionId': fixture.service.sessionId,
      'message': {
        'messageId': 'reply',
        'senderType': 'agent',
        'text': 'جواب خاص بالحساب'
      }
    });
    await tester.pump();
    expect(find.text('جواب خاص بالحساب'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'مسودة خاصة');
    identity.owner = null;
    identity.changes.add(null);
    await tester.pump();
    expect(find.text('جواب خاص بالحساب'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(fixture.service.messages, isEmpty);
    expect(fixture.service.draft, '');
    await remove(tester, identity);
    expect(identity.changes.hasListener, false);
  });
  testWidgets(
      'auth change while identity is loading invalidates the late owner',
      (tester) async {
    final identity = IdentitySource()
      ..pending = Completer<SupportDriverIdentity?>();
    var created = 0;
    await tester.pumpWidget(MaterialApp(
        home: LiveChatScreen(
            identitySource: identity,
            chatFactory: (_) {
              created++;
              return Fixture().service;
            })));
    identity.changes.add(null);
    identity.pending!.complete(const SupportDriverIdentity('old-owner'));
    await tester.pump();
    expect(created, 0);
    expect(find.byType(TextField), findsNothing);
    await remove(tester, identity);
  });
}
