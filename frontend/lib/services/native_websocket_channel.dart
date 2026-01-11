import 'dart:async';
import 'package:flutter/services.dart';

/// Native iOS WebSocket Channel
/// Uses Platform Channels to access URLSessionWebSocketTask
/// This bypasses the Dart SDK bug that transforms wss:// to https://:0
class NativeWebSocketChannel {
  static const MethodChannel _methodChannel = MethodChannel('com.whizz.driver/native_websocket');
  static const EventChannel _eventChannel = EventChannel('com.whizz.driver/native_websocket_events');
  
  StreamController<String>? _messageController;
  StreamController<String>? _errorController;
  StreamSubscription? _eventSubscription;
  
  bool _isConnected = false;
  
  /// Get stream of incoming messages
  Stream<String> get stream {
    _messageController ??= StreamController<String>.broadcast();
    return _messageController!.stream;
  }
  
  /// Get stream of errors
  Stream<String> get errors {
    _errorController ??= StreamController<String>.broadcast();
    return _errorController!.stream;
  }
  
  /// Check if connected
  bool get isConnected => _isConnected;
  
  /// Connect to WebSocket
  Future<void> connect(String url) async {
    try {
      print('🔌 [Native Channel] Connecting to: $url');
      
      // ✅ Initialize controllers BEFORE listening to events
      _messageController ??= StreamController<String>.broadcast();
      _errorController ??= StreamController<String>.broadcast();
      print('✅ [Native Channel] Controllers initialized');
      
      // Start listening to events
      print('👂 [Native Channel] Starting event stream listener...');
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          print('📨 [Native Channel] Event received: ${event.runtimeType}');
          print('📨 [Native Channel] Event data: $event');
          
          if (event is Map) {
            final type = event['type'] as String?;
            print('📨 [Native Channel] Event type: $type');
            
            switch (type) {
              case 'connected':
              case 'opened':
                print('✅ [Native Channel] Connected');
                _isConnected = true;
                break;
                
              case 'message':
                final data = event['data'] as String?;
                print('📥 [Native Channel] Message event received');
                print('📥 [Native Channel] Data is null: ${data == null}');
                if (data != null) {
                  print('📥 [Native Channel] Message length: ${data.length} chars');
                  print('📥 [Native Channel] Message: $data');
                  print('📤 [Native Channel] Adding to _messageController...');
                  print('📤 [Native Channel] _messageController is null: ${_messageController == null}');
                  _messageController?.add(data);
                  print('✅ [Native Channel] Added to stream!');
                }
                break;
                
              case 'error':
                final message = event['message'] as String?;
                print('❌ [Native Channel] Error: $message');
                _errorController?.add(message ?? 'Unknown error');
                _isConnected = false;
                break;
                
              case 'closed':
              case 'disconnected':
                print('🔌 [Native Channel] Disconnected - closeCode: ${event['code']}');
                _isConnected = false;
                // ✅ FIX: Close the stream to trigger onDone handler in websocket_service
                _messageController?.close();
                _messageController = null;
                break;
                
              default:
                print('⚠️ [Native Channel] Unknown event type: $type');
            }
          }
        },
        onError: (error) {
          print('❌ [Native Channel] Stream error: $error');
          _errorController?.add(error.toString());
          _isConnected = false;
        },
      );
      
      // Call native connect method
      final result = await _methodChannel.invokeMethod('connect', {'url': url});
      
      if (result == true) {
        print('✅ [Native Channel] Connect method returned success');
      } else {
        throw Exception('Native connect returned false');
      }
      
    } catch (e) {
      print('❌ [Native Channel] Connect failed: $e');
      _isConnected = false;
      rethrow;
    }
  }
  
  /// Send message
  Future<void> send(String message) async {
    if (!_isConnected) {
      throw Exception('WebSocket not connected');
    }
    
    try {
      print('📤 [Native Channel] Sending: $message');
      await _methodChannel.invokeMethod('send', {'message': message});
      print('✅ [Native Channel] Message sent');
    } catch (e) {
      print('❌ [Native Channel] Send failed: $e');
      rethrow;
    }
  }
  
  /// Disconnect
  Future<void> disconnect() async {
    try {
      print('🔌 [Native Channel] Disconnecting...');
      await _methodChannel.invokeMethod('disconnect');
      _isConnected = false;
      
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      
      await _messageController?.close();
      _messageController = null;
      
      await _errorController?.close();
      _errorController = null;
      
      print('✅ [Native Channel] Disconnected');
    } catch (e) {
      print('❌ [Native Channel] Disconnect failed: $e');
    }
  }
  
  /// Close (alias for disconnect)
  Future<void> close() => disconnect();
}
