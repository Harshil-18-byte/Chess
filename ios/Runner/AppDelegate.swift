import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    weak var registrar = self.registrar(forPlugin: "enterprise_chess")
    if let registrar = registrar {
      registrar.register(
        LiquidGlassViewFactory(),
        withId: "enterprise_chess/liquid_glass_view"
      )

      let channel = FlutterMethodChannel(
        name: "enterprise_chess/liquid_glass",
        binaryMessenger: registrar.messenger()
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
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }


}
