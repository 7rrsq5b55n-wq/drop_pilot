import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    // Read the iOS Google Maps key from Info.plist
    let apiKey =
      (Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    // Provide key to Google Maps iOS SDK (prevents GMSServices precondition crash)
    if !apiKey.isEmpty {
      GMSServices.provideAPIKey(apiKey)
    } else {
      NSLog("⚠️ GMSApiKey is missing/empty in Info.plist")
    }

    // Expose the same key to Dart so HTTP calls can use it too
    if let registrar = self.registrar(forPlugin: "AppConfigPlugin") {
      let channel = FlutterMethodChannel(
        name: "ecoroute/app_config",
        binaryMessenger: registrar.messenger()
      )

      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "getGmsApiKey":
          result(apiKey)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
