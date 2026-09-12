import UIKit
import SwiftUI

/// Native Liquid Glass view using Apple's UIKit/SwiftUI material APIs.
///
/// Registered as platform view type `enterprise_chess/liquid_glass_view`
/// by [LiquidGlassViewFactory].
///
/// On iOS 26+ this hosts a SwiftUI `.glassEffect()` surface.
/// On iOS 13–25 it falls back to `UIVisualEffectView` with
/// `UIBlurEffect(style: .systemUltraThinMaterial)`.
///
/// Accessibility:
/// - When Reduce Transparency is enabled → renders a plain opaque surface.
/// - When Reduce Motion is enabled → disables animated specular transitions.
class LiquidGlassNativeView: NSObject, FlutterPlatformView {

  private var hostingController: UIViewController
  private let frame: CGRect
  private let viewId: Int64

  init(frame: CGRect, viewId: Int64) {
    self.frame = frame
    self.viewId = viewId

    let glassView = LiquidGlassSwiftUIView()
    hostingController = UIHostingController(rootView: glassView)
    hostingController.view.frame = frame
    hostingController.view.backgroundColor = .clear
    super.init()
  }

  func view() -> UIView {
    return hostingController.view
  }
}

// MARK: - SwiftUI glass surface

private struct LiquidGlassSwiftUIView: View {
  var body: some View {
    let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled
    let reduceMotion       = UIAccessibility.isReduceMotionEnabled

    Group {
      if reduceTransparency {
        // Accessibility flat fallback — opaque charcoal.
        Color(red: 0.1, green: 0.1, blue: 0.1)
      } else if #available(iOS 26, *) {
        // PATH A — Apple Liquid Glass (true hardware refraction).
        Rectangle()
          .glassEffect(in: RoundedRectangle(cornerRadius: 20))
          .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7),
                     value: reduceMotion)
      } else {
        // iOS 13-25 fallback — UIVisualEffectView blur material.
        _VisualEffectView(style: .systemUltraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 20))
      }
    }
  }
}

// MARK: - UIVisualEffectView bridge (iOS 13-25 fallback)

private struct _VisualEffectView: UIViewRepresentable {
  let style: UIBlurEffect.Style

  func makeUIView(context: Context) -> UIVisualEffectView {
    return UIVisualEffectView(effect: UIBlurEffect(style: style))
  }

  func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Factory

/// Registered in AppDelegate to vend [LiquidGlassNativeView] instances.
class LiquidGlassViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(withFrame frame: CGRect,
              viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    return LiquidGlassNativeView(frame: frame, viewId: viewId)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}
