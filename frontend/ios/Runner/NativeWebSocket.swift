import Foundation
import Flutter

/// Native iOS WebSocket using URLSessionWebSocketTask
/// This bypasses the Dart SDK bug that transforms wss:// to https://:0
public class NativeWebSocketPlugin: NSObject, FlutterPlugin {
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var channel: FlutterMethodChannel?
    private var eventSink: FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "com.whizz.driver/native_websocket",
            binaryMessenger: registrar.messenger()
        )
        
        let eventChannel = FlutterEventChannel(
            name: "com.whizz.driver/native_websocket_events",
            binaryMessenger: registrar.messenger()
        )
        
        let instance = NativeWebSocketPlugin()
        instance.channel = methodChannel
        
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let urlString = args["url"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing URL", details: nil))
                return
            }
            connect(urlString: urlString, result: result)
            
        case "send":
            guard let args = call.arguments as? [String: Any],
                  let message = args["message"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing message", details: nil))
                return
            }
            send(message: message, result: result)
            
        case "disconnect":
            disconnect(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func connect(urlString: String, result: @escaping FlutterResult) {
        print("🔌 [Native] Connecting to: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid WebSocket URL", details: nil))
            return
        }
        
        // Disconnect existing connection if any
        disconnect { _ in }
        
        // Create URLSession configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
        
        // Create WebSocket task
        webSocketTask = urlSession?.webSocketTask(with: url)
        
        // Resume (connect) FIRST
        webSocketTask?.resume()
        
        print("✅ [Native] WebSocket task created and resumed")
        
        // CRITICAL: Start receiving messages AFTER resume
        // This ensures the connection is established before listening
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            print("👂 [Native] Starting message listener...")
            self?.receiveMessage()
        }
        
        // Send connected event
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.eventSink?(["type": "connected", "timestamp": Date().timeIntervalSince1970])
        }
        
        result(true)
    }
    
    private func send(message: String, result: @escaping FlutterResult) {
        guard let task = webSocketTask else {
            result(FlutterError(code: "NOT_CONNECTED", message: "WebSocket not connected", details: nil))
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(message)
        
        task.send(message) { [weak self] error in
            if let error = error {
                print("❌ [Native] Send failed: \(error.localizedDescription)")
                result(FlutterError(code: "SEND_FAILED", message: error.localizedDescription, details: nil))
            } else {
                print("📤 [Native] Message sent: \(message)")
                result(true)
            }
        }
    }
    
    private func disconnect(result: @escaping FlutterResult) {
        print("🔌 [Native] Disconnecting...")
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        
        eventSink?(["type": "disconnected", "timestamp": Date().timeIntervalSince1970])
        
        result(true)
    }
    
    private func receiveMessage() {
        print("👂 [Native] Listening for messages...")
        print("👂 [Native] webSocketTask is nil: \(webSocketTask == nil)")
        print("👂 [Native] eventSink is nil: \(eventSink == nil)")
        
        webSocketTask?.receive { [weak self] result in
            print("📨 [Native] Receive callback triggered!")
            print("📨 [Native] Result type: \(result)")
            
            switch result {
            case .success(let message):
                print("✅ [Native] Receive SUCCESS")
                switch message {
                case .string(let text):
                    print("🔥🔥🔥 [Native] MESSAGE RECEIVED! 🔥🔥🔥")
                    print("📥 [Native] Received text length: \(text.count) chars")
                    print("📥 [Native] Received: \(text)")
                    print("📤 [Native] Sending to Flutter via eventSink...")
                    print("📤 [Native] eventSink is nil: \(self?.eventSink == nil)")
                    
                    let eventData: [String: Any] = [
                        "type": "message",
                        "data": text,
                        "timestamp": Date().timeIntervalSince1970
                    ]
                    print("📤 [Native] Event data prepared: \(eventData)")
                    
                    self?.eventSink?(eventData)
                    print("✅ [Native] Sent to Flutter!")
                    
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        print("📥 [Native] Received data: \(text)")
                        self?.eventSink?([
                            "type": "message",
                            "data": text,
                            "timestamp": Date().timeIntervalSince1970
                        ])
                    }
                    
                @unknown default:
                    print("⚠️ [Native] Unknown message type")
                }
                
                // Continue receiving
                self?.receiveMessage()
                
                case .failure(let error):
                print("❌ [Native] Receive failed: \(error.localizedDescription)")
                print("❌ [Native] Error code: \((error as NSError).code)")
                print("❌ [Native] Error domain: \((error as NSError).domain)")
                
                let nsError = error as NSError
                
                // Check if this is a connection closed error
                if nsError.code == 57 || nsError.domain == NSPOSIXErrorDomain {
                    print("🔌 [Native] Connection closed/lost - stopping receive loop")
                    self?.eventSink?([
                        "type": "error",
                        "message": "Connection closed",
                        "timestamp": Date().timeIntervalSince1970
                    ])
                    // Don't continue receiving on connection errors
                    return
                }
                
                print("🔄 [Native] Non-fatal error - attempting to continue receiving...")
                self?.eventSink?([
                    "type": "error",
                    "message": error.localizedDescription,
                    "timestamp": Date().timeIntervalSince1970
                ])
                
                // CRITICAL FIX: Continue receiving after non-fatal errors
                self?.receiveMessage()
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension NativeWebSocketPlugin: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ [Native] WebSocket opened with protocol: \(`protocol` ?? "none")")
        eventSink?(["type": "opened", "timestamp": Date().timeIntervalSince1970])
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🔌 [Native] WebSocket closed with code: \(closeCode.rawValue)")
        let reasonString = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "No reason"
        print("🔌 [Native] Close reason: \(reasonString)")
        eventSink?(["type": "closed", "code": closeCode.rawValue, "reason": reasonString, "timestamp": Date().timeIntervalSince1970])
    }
    
    // ✅ CRITICAL FIX: Detect network errors and connection failures
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("❌ [Native] Connection failed: \(error.localizedDescription)")
            eventSink?(["type": "error", "message": error.localizedDescription, "timestamp": Date().timeIntervalSince1970])
            
            // Also send closed event to trigger reconnection
            eventSink?(["type": "closed", "code": 1006, "reason": "Connection failed", "timestamp": Date().timeIntervalSince1970])
        }
    }
}

// MARK: - FlutterStreamHandler
extension NativeWebSocketPlugin: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("👂 [Native] Event stream listener attached")
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("🔇 [Native] Event stream listener cancelled")
        self.eventSink = nil
        return nil
    }
}
