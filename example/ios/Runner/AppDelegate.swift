import AdaptyUI
import AdaptyUIBuilder
import Flutter
import SwiftUI
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
    // Flows draw their custom elements with the resolver registered here. An element whose
    // custom type it does not serve shows the fallback set for it in the Adapty Flow Builder.
    AdaptyUI.setCustomElementsResolver(ExampleCustomElements())
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

/// Draws the custom elements of type `example_badge`; any other type falls back.
@MainActor
struct ExampleCustomElements: AdaptyUICustomElementsResolver {
  func view(forType type: String, id: String, context: AdaptyUICustomElementContext) -> AnyView? {
    switch type {
    case "example_badge":
      return AnyView(
        Text("Drawn by the app: \(id)")
          .font(.footnote.weight(.semibold))
          .padding(.horizontal, 12).padding(.vertical, 6)
          .background(Capsule().fill(Color.accentColor.opacity(0.15)))
      )
    default:
      return nil
    }
  }
}
