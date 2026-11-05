import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:wizz_driver/services/wizzcentral_support_chat_service.dart';
import 'package:wizz_driver/services/support_conversation_store.dart';

class MemoryStore implements SupportConversationStore {
  String? value;
  bool failRead = false;
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('locked');
    return value;
  }

  @override
  Future<void> write(String next) async {
    value = next;
  }
}

class FakeSink implements WebSocketSink {
  FakeSink(this.channel);
  final FakeChannel channel;
  bool fail = false;
  @override
  void add(dynamic data) {
    if (fail) throw StateError('offline');
    channel.sent.add(jsonDecode(data as String) as Map<String, dynamic>);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!channel.input.isClosed) await channel.input.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeChannel implements WebSocketChannel {
  final input = StreamController<dynamic>(sync: true);
  final sent = <Map<String, dynamic>>[];
  late final fakeSink = FakeSink(this);
  @override
  Stream<dynamic> get stream => input.stream;
  @override
  WebSocketSink get sink => fakeSink;
  @override
  Future<void> get ready => Future.value();
  void receive(Map<String, dynamic> frame) => input.add(jsonEncode(frame));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Fixture {
  Fixture({this.imageClient});
  final http.Client? imageClient;
  String get historyRequest => channels.last.sent.lastWhere(
        (m) => m['action'] == 'get_session_messages',
      )['requestId'] as String;
  final channels = <FakeChannel>[];
  final uris = <Uri>[];
  late final service = WizzCentralSupportChatService(
    tokenProvider: () async => 'fresh-token',
    attachmentsEndpoint: 'https://support.invalid/images',
    attachmentClient: imageClient,
    channelFactory: (uri) {
      uris.add(uri);
      final channel = FakeChannel();
      channels.add(channel);
      return channel;
    },
  );
  void confirm() => channels.last.receive({
        'type': 'chat_session_created',
        'sessionId': service.sessionId,
      });
}
