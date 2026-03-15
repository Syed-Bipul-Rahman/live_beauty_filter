import Flutter
import UIKit

public class LiveBeautyFilterPlugin: NSObject, FlutterPlugin {

  private var textureRegistry: FlutterTextureRegistry
  private var cameraController: MilkyCameraController?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "live_beauty_filter",
      binaryMessenger: registrar.messenger()
    )
    let instance = LiveBeautyFilterPlugin(textureRegistry: registrar.textures())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  init(textureRegistry: FlutterTextureRegistry) {
    self.textureRegistry = textureRegistry
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      let controller = MilkyCameraController(textureRegistry: textureRegistry)
      controller.start { textureId, error in
        if let error = error {
          result(FlutterError(code: "CAMERA_ERROR",
            message: error.localizedDescription,
            details: nil))
        } else {
          result(textureId)
        }
      }
      self.cameraController = controller

    case "setFilterIntensity":
      if let args = call.arguments as? [String: Any],
      let intensity = args["intensity"] as? Double {
        cameraController?.setFilterIntensity(Float(intensity))
      }
      result(nil)

    case "dispose":
      cameraController?.stop()
      cameraController = nil
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}