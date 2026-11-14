import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'support_conversation_checkpoint.dart';
import 'support_private_images.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';
import 'driver_auth_helper.dart';
import 'driver_service.dart';
import '../config/environment.dart';

class SupportIdentity {
  final String subject, token, name, phone;
  const SupportIdentity(this.subject, this.token, this.name, this.phone);
}

abstract class SupportTransport {
  Stream<dynamic> get stream;
  Future<void> get ready;
  void send(String value);
  Future<void> close();
}

class _SocketTransport implements SupportTransport {
  final IOWebSocketChannel channel;
  _SocketTransport(Uri uri, String token)
      : channel = IOWebSocketChannel.connect(uri,
            headers: {'Authorization': 'Bearer $token'});
  @override
  Stream<dynamic> get stream => channel.stream;
  @override
  Future<void> get ready => channel.ready;
  @override
  void send(String value) => channel.sink.add(value);
  @override
  Future<void> close() async {
    await channel.sink.close();
  }
}

/// Driver adapter for the colleague's deployed authenticated support protocol.
/// A message is confirmed by a server receipt, never by writing to a socket.
class AuthenticatedSupportChat extends ChangeNotifier {
  static const endpoint = String.fromEnvironment('SUPPORT_CHAT_WS_URL',
      defaultValue:
          Environment.isProduction || Environment.environment != 'staging'
              ? ''
              : 'wss://vzvnqu5jhl.execute-api.us-east-1.amazonaws.com/staging');
  final Future<SupportIdentity> Function() identity;
  final SupportTransport Function(Uri, String) transport;
  final Future<String?> Function(String) readSession;
  final Future<void> Function(String, String) saveSession;
  final Duration timeout;
  final List<Map<String, dynamic>> messages = [];
  String draft = '';
  String? _checkpointKey;
  Timer? _draftTimer;
  void setDraft(String value) {
    draft = value;
    _draftTimer?.cancel();
    final key = _checkpointKey;
    if (key != null)
      _draftTimer = Timer(const Duration(milliseconds: 350), () {
        unawaited(saveSession('$key:draft', value).catchError((Object _) {}));
      });
  }

  void flushDraft() {
    _draftTimer?.cancel();
    final key = _checkpointKey, value = draft;
    if (key != null)
      unawaited(saveSession('$key:draft', value).catchError((Object _) {}));
  }

  late final SupportPrivateImages _images = SupportPrivateImages(
      endpoint: attachmentsEndpoint,
      role: 'driver',
      token: () async {
        final actor = await identity();
        if (_disposed || actor.subject != _subject)
          throw StateError('SESSION_CHANGED');
        return actor.token;
      },
      client: imageClient);
  final http.Client? imageClient;
  static const attachmentsEndpoint = String.fromEnvironment(
      'SUPPORT_ATTACHMENTS_API_URL',
      defaultValue: Environment.environment == 'staging'
          ? 'https://5ytyphpnkc.execute-api.us-east-1.amazonaws.com/staging/support/attachments'
          : '');
  String? _imageDigest, _imageUploadId, _imageAttachment;
  bool uploading = false;
  Future<bool> sendImage(Uint8List bytes) async {
    if (!connected || sending || uploading || _sessionId == null) return false;
    final generation = _generation, sessionId = _sessionId!;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        sessionId == _sessionId &&
        connected;
    uploading = true;
    _changed();
    try {
      final digest = sha256.convert(bytes).toString();
      if (_imageDigest != digest) {
        _imageDigest = digest;
        _imageUploadId = const Uuid().v4();
        _imageAttachment = null;
      }
      _imageAttachment ??= await _images.upload(
          sessionId: sessionId,
          uploadId: _imageUploadId!,
          bytes: bytes,
          isCurrent: current);
      if (!current()) return false;
      final confirmed = await send('صورة مرفقة',
          attachmentId: _imageAttachment, clientMessageId: _imageUploadId);
      if (confirmed) {
        _imageDigest = null;
        _imageUploadId = null;
        _imageAttachment = null;
      }
      return confirmed;
    } catch (_) {
      return false;
    } finally {
      if (generation == _generation) uploading = false;
      _changed();
    }
  }

  Future<Uint8List> loadAttachment(String attachmentId) {
    final generation = _generation, sessionId = _sessionId;
    if (sessionId == null || _disposed) throw StateError('NO_SUPPORT_SESSION');
    return _images.load(
        sessionId: sessionId,
        attachmentId: attachmentId,
        isCurrent: () =>
            !_disposed && generation == _generation && sessionId == _sessionId);
  }

  SupportTransport? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  Timer? _historyTimer;
  Completer<void>? _handshake;
  Completer<bool>? _ack;
  String? _sessionId, _subject, _pendingId, _pendingText, _historyRequest;
  String? _pendingAttachment;
  String? nextCursor;
  String? historyError;
  String status = 'disconnected';
  bool sending = false, historyLoading = false, _disposed = false;
  int _generation = 0;
  String? get sessionId => _sessionId;
  bool get connected => status == 'connected';
  AuthenticatedSupportChat({
    Future<SupportIdentity> Function()? identity,
    SupportTransport Function(Uri, String)? transport,
    Future<String?> Function(String)? readSession,
    Future<void> Function(String, String)? saveSession,
    this.imageClient,
    this.timeout = const Duration(seconds: 15),
  })  : identity = identity ?? _identity,
        transport = transport ?? ((uri, token) => _SocketTransport(uri, token)),
        readSession = readSession ?? SupportConversationCheckpoint.read,
        saveSession = saveSession ?? SupportConversationCheckpoint.write;
  static Future<SupportIdentity> _identity() async {
    final token = await DriverAuthHelper.getCurrentAccessToken();
    final subject = await DriverAuthHelper.getCurrentUserId();
    final profile = await DriverService.getDriverProfile();
    if (token == null || subject == null || profile == null)
      throw StateError('AUTH_REQUIRED');
    return SupportIdentity(subject, token, profile.name, profile.phone);
  }

  void invalidateIdentity() {
    flushDraft();
    ++_generation;
    _checkpointKey = null;
    draft = '';
    _subject = null;
    _sessionId = null;
    _pendingId = null;
    _pendingText = null;
    _pendingAttachment = null;
    _imageDigest = null;
    _imageUploadId = null;
    _imageAttachment = null;
    messages.clear();
    sending = false;
    uploading = false;
    nextCursor = null;
    unawaited(_subscription?.cancel());
    unawaited(_socket?.close());
    _fail('disconnected');
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _send(Map<String, dynamic> message) =>
      _socket!.send(jsonEncode(message));
  void _fail([String next = 'error']) {
    status = next;
    _heartbeat?.cancel();
    historyLoading = false;
    _historyTimer?.cancel();
    if (_handshake != null && !_handshake!.isCompleted) _handshake!.complete();
    if (_ack != null && !_ack!.isCompleted) _ack!.complete(false);
    _changed();
  }

  Future<void> connect({bool newConversation = false}) async {
    if (_disposed || status == 'connecting') return;
    final generation = ++_generation;
    status = 'connecting';
    _changed();
    _heartbeat?.cancel();
    try {
      await _subscription?.cancel();
      try {
        await _socket?.close().timeout(const Duration(seconds: 2));
      } catch (_) {}
      historyLoading = false;
      _historyTimer?.cancel();
      _historyRequest = null;
      final actor = await identity().timeout(timeout);
      if (_disposed || generation != _generation) return;
      if (actor.subject.trim().isEmpty || actor.token.isEmpty)
        throw StateError('AUTH_REQUIRED');
      if (_subject != null && _subject != actor.subject) {
        flushDraft();
        draft = '';
        _checkpointKey = null;
        _imageDigest = null;
        _imageUploadId = null;
        _imageAttachment = null;
      }
      if (_subject != actor.subject || newConversation) {
        _imageDigest = null;
        _imageUploadId = null;
        _imageAttachment = null;
        _pendingAttachment = null;
        messages.clear();
        _pendingId = null;
        _pendingText = null;
        nextCursor = null;
      }
      _subject = actor.subject;
      final key = jsonEncode([actor.subject, endpoint, 'driver']);
      _checkpointKey = key;
      final savedDraft = await readSession('$key:draft');
      if (_disposed || generation != _generation) return;
      if (draft.isEmpty) draft = savedDraft ?? '';
      final saved = newConversation ? null : await readSession(key);
      if (_disposed || generation != _generation) return;
      _sessionId = saved?.isNotEmpty == true
          ? saved
          : 'driver_${actor.subject}_${const Uuid().v4()}';
      final uri = Uri.parse(endpoint);
      if (uri.scheme != 'wss' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery) throw StateError('INVALID_SUPPORT_ENDPOINT');
      _socket = transport(
          uri.replace(queryParameters: {
            'userType': 'driver',
            'platform': 'wizzdriver_app'
          }),
          actor.token);
      _handshake = Completer<void>();
      _subscription = _socket!.stream.listen((event) {
        if (!_disposed && generation == _generation) _receive(event);
      }, onError: (_) {
        if (generation == _generation) _fail();
      }, onDone: () {
        if (generation == _generation && status != 'closed')
          _fail('disconnected');
      });
      await _socket!.ready.timeout(timeout);
      if (_disposed || generation != _generation) return;
      _send({
        'action': 'chat_driver_connect',
        'driverId': actor.subject,
        'driverName': actor.name,
        'driverPhone': actor.phone,
        'sessionId': _sessionId
      });
      await _handshake!.future.timeout(timeout);
      if (_disposed || generation != _generation) return;
      if (!connected) throw StateError('SUPPORT_NOT_READY');
      if (_pendingId == null) {
        try {
          final raw = await readSession('$key:pending');
          final pending = raw == null || raw.isEmpty ? null : jsonDecode(raw);
          if (_disposed || generation != _generation) return;
          if (pending is Map &&
              pending['sessionId'] == _sessionId &&
              pending['id'] is String &&
              (pending['id'] as String).isNotEmpty &&
              pending['text'] is String &&
              (pending['text'] as String).length <= 2000) {
            _pendingId = pending['id'];
            _pendingText = pending['text'];
            _pendingAttachment = pending['attachment'] as String?;
            _imageDigest = pending['imageDigest'] as String?;
            _imageUploadId = _imageDigest == null ? null : _pendingId;
            _imageAttachment = _pendingAttachment;
          }
        } catch (_) {/* invalid metadata cannot establish chat identity */}
      }

      await saveSession(key, _sessionId!);
      if (_disposed || generation != _generation) return;
      _heartbeat = Timer.periodic(const Duration(seconds: 40), (_) {
        if (connected) _send({'action': 'heartbeat'});
      });
      loadHistory();
    } catch (_) {
      if (!_disposed && generation == _generation && status != 'closed')
        _fail();
    }
  }

  void _merge(Map<String, dynamic> item) {
    final id = item['messageId'];
    if (id is! String ||
        id.isEmpty ||
        item['senderType'] is! String ||
        item['text'] is! String) return;
    final existing = messages.indexWhere((m) => m['messageId'] == id);
    if (existing >= 0) {
      messages[existing] = {...messages[existing], ...item};
    } else {
      messages.add({...item});
    }
    messages.sort((a, b) => '${a['createdAt']}'.compareTo('${b['createdAt']}'));
  }

  void _receive(dynamic raw) {
    try {
      final parsed = raw is String ? jsonDecode(raw) : raw;
      if (parsed is! Map) return;
      final event = Map<String, dynamic>.from(parsed);
      if (event['sessionId'] != null && event['sessionId'] != _sessionId)
        return;
      switch (event['type']) {
        case 'chat_session_created':
          if (event['sessionId'] != _sessionId) return;
          status = 'connected';
          if (!_handshake!.isCompleted) _handshake!.complete();
          break;
        case 'session_messages':
          if (event['requestId'] != _historyRequest) return;
          for (final m in (event['messages'] as List? ?? [])) {
            if (m is Map) _merge(Map<String, dynamic>.from(m));
          }
          nextCursor =
              event['nextCursor'] is String ? event['nextCursor'] : null;
          historyLoading = false;
          _historyTimer?.cancel();
          break;
        case 'history_error':
          if (event['requestId'] != _historyRequest) return;
          historyError = 'تعذر تحميل الرسائل السابقة';
          historyLoading = false;
          break;
        case 'chat_message':
          if (event['message'] is Map)
            _merge(Map<String, dynamic>.from(event['message']));
          break;
        case 'message_ack':
          if (event['clientMessageId'] == _pendingId &&
              event['messageId'] is String) {
            _merge({
              'messageId': event['messageId'],
              'senderType': 'driver',
              'text': _pendingText ?? '',
              if (_pendingAttachment != null)
                'attachment': {'attachmentId': _pendingAttachment},
              'createdAt': DateTime.now().toUtc().toIso8601String()
            });
            if (_ack != null && !_ack!.isCompleted) _ack!.complete(true);
          }
          break;
        case 'session_closed':
          _fail('closed');
          break;
        case 'error':
          _fail(event['code'] == 'SESSION_CLOSED' ? 'closed' : 'error');
          break;
      }
      _changed();
    } catch (_) {
      _fail();
    }
  }

  void loadHistory({bool older = false}) {
    if (!connected || historyLoading || older && nextCursor == null) return;
    historyLoading = true;
    historyError = null;
    _historyRequest = const Uuid().v4();
    _send({
      'action': 'get_session_messages',
      'sessionId': _sessionId,
      'requestId': _historyRequest,
      'limit': 30,
      if (older) 'cursor': nextCursor
    });
    _historyTimer?.cancel();
    _historyTimer = Timer(timeout, () {
      historyError = 'تعذر تحميل الرسائل السابقة';
      historyLoading = false;
      _changed();
    });
    _changed();
  }

  Future<bool> send(String text,
      {String? attachmentId, String? clientMessageId}) async {
    text = text.trim();
    if (!connected || sending || text.isEmpty || text.length > 2000)
      return false;
    if (_pendingText != text || _pendingAttachment != attachmentId) {
      _pendingAttachment = attachmentId;
      _pendingId = clientMessageId ?? const Uuid().v4();
      _pendingText = text;
    }
    final generation = _generation, key = _checkpointKey;
    sending = true;
    _ack = Completer<bool>();
    _changed();
    var confirmed = false;
    try {
      if (key != null)
        await saveSession(
            '$key:pending',
            jsonEncode({
              'sessionId': _sessionId,
              'id': _pendingId,
              'text': _pendingText,
              'attachment': _pendingAttachment,
              'imageDigest': _imageDigest,
            }));
      if (_disposed || generation != _generation || !connected) return false;
      _send({
        'action': 'chat_message',
        'sessionId': _sessionId,
        'senderType': 'driver',
        'messageText': text,
        'clientMessageId': _pendingId,
        if (attachmentId != null) 'attachmentId': attachmentId
      });
      confirmed = await _ack!.future.timeout(timeout, onTimeout: () => false);
      if (_disposed || generation != _generation) return false;
      if (confirmed) {
        if (key != null) await saveSession('$key:pending', '');
        if (_disposed || generation != _generation) return false;
        _pendingText = null;
        _pendingId = null;
      }
    } catch (_) {
      confirmed = false;
    } finally {
      if (generation == _generation) sending = false;
      _changed();
    }
    return confirmed;
  }

  @override
  void dispose() {
    flushDraft();
    _images.dispose();
    _disposed = true;
    ++_generation;
    _heartbeat?.cancel();
    _historyTimer?.cancel();
    if (_handshake != null && !_handshake!.isCompleted) _handshake!.complete();
    if (_ack != null && !_ack!.isCompleted) _ack!.complete(false);
    _subscription?.cancel();
    _socket?.close();
    super.dispose();
  }
}
