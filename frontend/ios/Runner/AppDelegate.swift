import Flutter
import UIKit
import GoogleMaps
import FirebaseCore

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
        
        disconnect { _ in }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = urlSession?.webSocketTask(with: url)
        
        receiveMessage()
        webSocketTask?.resume()
        
        print("✅ [Native] WebSocket task created and resumed")
        
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
        
        task.send(message) { error in
            if let error = error {
                print("❌ [Native] Send failed: \(error.localizedDescription)")
                result(FlutterError(code: "SEND_FAILED", message: error.localizedDescription, details: nil))
            } else {
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
        webSocketTask?.receive { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        print("📥 [Native] Received: \(text)")
                        self?.eventSink?([
                            "type": "message",
                            "data": text,
                            "timestamp": Date().timeIntervalSince1970
                        ])
                        
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self?.eventSink?([
                                "type": "message",
                                "data": text,
                                "timestamp": Date().timeIntervalSince1970
                            ])
                        }
                        
                    @unknown default:
                        break
                    }
                    
                    self?.receiveMessage()
                    
                case .failure(let error):
                    print("❌ [Native] Receive failed: \(error.localizedDescription)")
                    self?.eventSink?([
                        "type": "error",
                        "message": error.localizedDescription,
                        "timestamp": Date().timeIntervalSince1970
                    ])
                }
            }
        }
    }
}

extension NativeWebSocketPlugin: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("✅ [Native] WebSocket opened")
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(["type": "opened", "timestamp": Date().timeIntervalSince1970])
        }
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("🔌 [Native] WebSocket closed")
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(["type": "closed", "code": closeCode.rawValue, "timestamp": Date().timeIntervalSince1970])
        }
    }
}

extension NativeWebSocketPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps API Key - shared across Wizz apps
    GMSServices.provideAPIKey("AIzaSyDrvzgil3g2SwE8zl_44IGM35n7khAyoVI")

        // Configure Firebase only when a valid plist exists and matches this app.
        // This prevents a hard crash when the plist is missing/invalid.
        if FirebaseApp.app() == nil {
            if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                 let options = FirebaseOptions(contentsOfFile: filePath),
                 let appBundleId = Bundle.main.bundleIdentifier,
                 !options.googleAppID.isEmpty,
                 options.bundleID == appBundleId {
                FirebaseApp.configure(options: options)
            } else {
                print("⚠️ Firebase not configured: missing/invalid GoogleService-Info.plist or bundleId mismatch")
            }
        }
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Register Native WebSocket plugin
    NativeWebSocketPlugin.register(with: self.registrar(forPlugin: "NativeWebSocketPlugin")!)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
