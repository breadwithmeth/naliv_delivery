import Flutter
import UIKit

final class NativeLiquidGlassPlugin: NSObject, FlutterPlugin {
  static let registrationKey = "NativeLiquidGlassPlugin"
  private static let capabilityChannelName = "naliv/native_liquid_glass"
  fileprivate static let viewType = "naliv/native_liquid_glass_backdrop"

  private let capabilityChannel: FlutterMethodChannel

  private init(capabilityChannel: FlutterMethodChannel) {
    self.capabilityChannel = capabilityChannel
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let channel = FlutterMethodChannel(
      name: capabilityChannelName,
      binaryMessenger: messenger
    )
    let plugin = NativeLiquidGlassPlugin(capabilityChannel: channel)
    registrar.addMethodCallDelegate(plugin, channel: channel)
    registrar.publish(plugin)

    if #available(iOS 26.0, *) {
      registrar.register(
        NativeLiquidGlassFactory(messenger: messenger),
        withId: viewType
      )
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "isAvailable" else {
      result(FlutterMethodNotImplemented)
      return
    }
    if #available(iOS 26.0, *) {
      result(true)
    } else {
      result(false)
    }
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    capabilityChannel.setMethodCallHandler(nil)
  }
}

@available(iOS 26.0, *)
private final class NativeLiquidGlassFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    guard let parameters = NativeGlassParameters(arguments: args) else {
      preconditionFailure(
        "Invalid NativeLiquidGlassBackdrop creation parameters. " +
          "Rebuild Dart and iOS Runner together so their glass bridge schemas match."
      )
    }
    return NativeLiquidGlassPlatformView(
      frame: frame,
      viewId: viewId,
      parameters: parameters,
      messenger: messenger
    )
  }
}

private struct NativeGlassParameters: Equatable {
  let tint: UInt32
  let dark: Bool
  let interactive: Bool
  let cornerRadii: [Double]

  init?(arguments: Any?) {
    guard let values = arguments as? [String: Any],
      let tint = values["tint"] as? NSNumber,
      let dark = values["dark"] as? Bool,
      let interactive = values["interactive"] as? Bool,
      let cornerRadii = values["cornerRadii"] as? [Double],
      cornerRadii.count == 8,
      cornerRadii.allSatisfy({ $0.isFinite && $0 >= 0 })
    else {
      return nil
    }
    self.tint = tint.uint32Value
    self.dark = dark
    self.interactive = interactive
    self.cornerRadii = cornerRadii
  }

  var tintColor: UIColor {
    UIColor(
      red: CGFloat((tint >> 16) & 0xff) / 255,
      green: CGFloat((tint >> 8) & 0xff) / 255,
      blue: CGFloat(tint & 0xff) / 255,
      alpha: CGFloat((tint >> 24) & 0xff) / 255
    )
  }
}

@available(iOS 26.0, *)
private final class NativeLiquidGlassPlatformView: NSObject, FlutterPlatformView {
  private let effectView: PassthroughGlassEffectView
  private let channel: FlutterMethodChannel
  private var parameters: NativeGlassParameters?

  init(
    frame: CGRect,
    viewId: Int64,
    parameters: NativeGlassParameters,
    messenger: FlutterBinaryMessenger
  ) {
    effectView = PassthroughGlassEffectView(effect: nil)
    effectView.frame = frame
    effectView.backgroundColor = .clear
    effectView.isUserInteractionEnabled = false
    effectView.isAccessibilityElement = false
    effectView.accessibilityElementsHidden = true
    channel = FlutterMethodChannel(
      name: "\(NativeLiquidGlassPlugin.viewType)/\(viewId)",
      binaryMessenger: messenger
    )
    super.init()
    apply(parameters)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(
          code: "native_glass_view_disposed",
          message: "The native Liquid Glass backdrop has been disposed.",
          details: nil
        ))
        return
      }
      guard call.method == "update" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let updated = NativeGlassParameters(arguments: call.arguments) else {
        result(FlutterError(
          code: "invalid_native_glass_parameters",
          message: "Expected tint, dark, interactive and eight finite nonnegative corner radii.",
          details: nil
        ))
        return
      }
      self.apply(updated)
      result(nil)
    }
  }

  func view() -> UIView {
    effectView
  }

  private func apply(_ updated: NativeGlassParameters) {
    let previous = parameters
    if previous?.dark != updated.dark {
      effectView.overrideUserInterfaceStyle = updated.dark ? .dark : .light
    }
    if previous?.cornerRadii != updated.cornerRadii {
      // Apple accepts scalar native radii, not elliptical Flutter radii. Keep the
      // native lens intact instead of imposing a CALayer mask on its geometry.
      let radii = updated.cornerRadii
      let topLeft = min(radii[0], radii[1])
      let topRight = min(radii[2], radii[3])
      let bottomLeft = min(radii[4], radii[5])
      let bottomRight = min(radii[6], radii[7])
      if topLeft == topRight && topLeft == bottomLeft && topLeft == bottomRight {
        effectView.cornerConfiguration = .uniformCorners(radius: .fixed(topLeft))
      } else {
        effectView.cornerConfiguration = .corners(
          topLeftRadius: .fixed(topLeft),
          topRightRadius: .fixed(topRight),
          bottomLeftRadius: .fixed(bottomLeft),
          bottomRightRadius: .fixed(bottomRight)
        )
      }
    }
    if previous?.tint != updated.tint || previous?.interactive != updated.interactive {
      let glass = UIGlassEffect(style: .regular)
      glass.tintColor = updated.tintColor
      glass.isInteractive = updated.interactive
      effectView.effect = glass
    }
    parameters = updated
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }
}

@available(iOS 26.0, *)
private final class PassthroughGlassEffectView: UIVisualEffectView {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    nil
  }
}
