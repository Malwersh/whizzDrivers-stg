import Flutter
import UIKit
import GoogleMaps
import FirebaseCore
import AVFoundation
import CoreLocation

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
            connect(urlString: urlString, headers: args["headers"] as? [String: String] ?? [:], result: result)
            
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
    
    private func connect(urlString: String, headers: [String: String], result: @escaping FlutterResult) {
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
        var request = URLRequest(url: url)
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
        webSocketTask = urlSession?.webSocketTask(with: request)
        
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
                        print("Native socket message received")
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
    if let registrar = self.registrar(forPlugin: "DriverLocationLabel") {
      FlutterMethodChannel(name: "com.whizz.driver/location_label", binaryMessenger: registrar.messenger()).setMethodCallHandler { call, result in
        guard call.method == "describe", let args = call.arguments as? [String: Double], let lat = args["latitude"], let lng = args["longitude"] else { result(FlutterMethodNotImplemented); return }
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude:lat,longitude:lng),preferredLocale:Locale(identifier:"ar")) { marks, _ in
          let p=marks?.first
          let values=[p?.locality,p?.administrativeArea,p?.country].compactMap{$0}.filter{!$0.isEmpty}
          var unique=[String]();for v in values {if !unique.contains(v){unique.append(v)}}
          DispatchQueue.main.async {result(unique.isEmpty ? nil : unique.joined(separator:"، "))}
        }
      }
    }
    if let soundRegistrar = self.registrar(forPlugin: "NotificationSoundFiles") { NotificationSoundFiles.register(with: soundRegistrar) }
    
    // Register Native WebSocket plugin
    NativeWebSocketPlugin.register(with: self.registrar(forPlugin: "NativeWebSocketPlugin")!)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

final class NotificationSoundFiles: NSObject, FlutterPlugin {
 private var offerPlayer: AVAudioPlayer?
 private static let offerCueFilePattern = #"^(driver_original|driver_offer|online_chime|soft_chime|merchant_bell|first_nitification_sound|custom_[a-f0-9]{64})\.wav$"#
 private static let customSoundFilePattern = #"^custom_[a-f0-9]{64}\.wav$"#
 static func register(with registrar: FlutterPluginRegistrar) {
  let channel=FlutterMethodChannel(name:"wizz/notification-sound-files",binaryMessenger:registrar.messenger())
  registrar.addMethodCallDelegate(NotificationSoundFiles(),channel:channel)
 }
 func handle(_ call: FlutterMethodCall,result: @escaping FlutterResult) {
  if call.method == "playOfferCue" { playOfferCue(call,result:result);return }
  guard call.method == "install" else { result(FlutterMethodNotImplemented);return }
  guard let args=call.arguments as? [String:Any],let name=args["file"] as? String,name.range(of:Self.customSoundFilePattern,options:.regularExpression) != nil,let value=args["bytes"] as? FlutterStandardTypedData,value.data.count>=44,value.data.count<=256000 else {result(FlutterError(code:"INVALID_SOUND",message:nil,details:nil));return}
  do {
   let dir=FileManager.default.urls(for:.libraryDirectory,in:.userDomainMask)[0].appendingPathComponent("Sounds",isDirectory:true)
   try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
   let file=dir.appendingPathComponent(name)
   if !FileManager.default.fileExists(atPath:file.path){try value.data.write(to:file,options:.atomic)}
   result(["path":file.path,"uri":file.absoluteString])
  } catch {result(FlutterError(code:"SOUND_INSTALL_FAILED",message:nil,details:nil))}
 }
}


extension NotificationSoundFiles {
 private func playOfferCue(_ call: FlutterMethodCall,result: @escaping FlutterResult) {
  guard UIApplication.shared.applicationState == .active else {
   let status:[String:Any]=["playing":false,"reason":"APP_NOT_ACTIVE","recordedAt":ISO8601DateFormatter().string(from:Date())]
   saveCueDiagnostic(status);result(status);return
  }
  guard let args=call.arguments as? [String:Any],let file=args["file"] as? String,
        file.range(of:Self.offerCueFilePattern,options:.regularExpression) != nil else {
   let status:[String:Any]=["playing":false,"reason":"INVALID_SOUND","recordedAt":ISO8601DateFormatter().string(from:Date())]
   saveCueDiagnostic(status);result(status);return
  }
  do {
   let session=AVAudioSession.sharedInstance()
   try session.setCategory(.playback,mode:.default,options:[.mixWithOthers])
   try session.setActive(true)
   let library=FileManager.default.urls(for:.libraryDirectory,in:.userDomainMask)[0].appendingPathComponent("Sounds",isDirectory:true)
   let custom=library.appendingPathComponent(file)
   let selected=file.hasPrefix("custom_") && FileManager.default.fileExists(atPath:custom.path) ? custom : Bundle.main.url(forResource:URL(fileURLWithPath:file).deletingPathExtension().lastPathComponent,withExtension:"wav")
   let fallback=Bundle.main.url(forResource:"driver_original",withExtension:"wav")
   guard let url=selected ?? fallback else {throw NSError(domain:"OfferAudio",code:1)}
   offerPlayer?.stop()
   do {offerPlayer=try AVAudioPlayer(contentsOf:url)}
   catch {guard let original=fallback else {throw error};offerPlayer=try AVAudioPlayer(contentsOf:original)}
   offerPlayer?.volume=1
   offerPlayer?.prepareToPlay()
   let playing=offerPlayer?.play() == true
   let status:[String:Any]=["playing":playing,"volume":session.outputVolume,"route":session.currentRoute.outputs.map{$0.portType.rawValue},"file":file,"recordedAt":ISO8601DateFormatter().string(from:Date())]
   saveCueDiagnostic(status)
   result(status)
  }catch {
   let error=error as NSError
   let status:[String:Any]=["playing":false,"reason":"NATIVE_AUDIO_FAILED","domain":error.domain,"code":error.code,"recordedAt":ISO8601DateFormatter().string(from:Date())]
   saveCueDiagnostic(status)
   result(status)
  }
 }
 private func saveCueDiagnostic(_ status:[String:Any]) {
  guard let dir=FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask).first,
        let data=try? JSONSerialization.data(withJSONObject:status) else {return}
  try? FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
  try? data.write(to:dir.appendingPathComponent("driver-offer-audio-diagnostic.json"),options:.atomic)
 }
}
