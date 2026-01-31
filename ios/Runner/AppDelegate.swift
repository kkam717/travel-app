import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Must be called before any Maps SDK usage - grey tiles = key invalid or restricted
    let plistKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String
    let key = plistKey.flatMap { $0.isEmpty ? nil : $0 } ?? ""
    GMSServices.provideAPIKey(key)
    #if DEBUG
    if !key.isEmpty {
      print("[GoogleMaps] API key configured: \(key.prefix(10))...\(key.suffix(4))")
    }
    #endif
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
