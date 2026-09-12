import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let registry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: registry)

    // ── Register Liquid Glass platform view factory ──────────────────────────
    registry.register(
      LiquidGlassViewFactory(),
      withId: "enterprise_chess/liquid_glass_view"
    )

    // ── Accessibility Method Channel (Path A bridge) ─────────────────────────
    // Exposes UIAccessibility flags to the Flutter LiquidGlassBridge.
    let binaryMessenger: FlutterBinaryMessenger = registry.value(
      forKey: "FlutterBinaryMessenger"
    ) as? FlutterBinaryMessenger ?? engineBridge.binaryMessenger

    let channel = FlutterMethodChannel(
      name: "enterprise_chess/liquid_glass",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "accessibilityFlags":
        result([
          "reduceMotion":       UIAccessibility.isReduceMotionEnabled,
          "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
