import Flutter
import UIKit

@main
// `@preconcurrency`: FlutterImplicitEngineDelegate isn't actor-annotated in the
// engine yet, so satisfying it with a @MainActor witness trips Swift 6 isolation
// checking. Stopgap until flutter/flutter#181033 lands; the engine always calls
// didInitializeImplicitFlutterEngine on the main thread.
@objc class AppDelegate: FlutterAppDelegate, @preconcurrency FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
