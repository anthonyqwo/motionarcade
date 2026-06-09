import Flutter
import CoreHaptics
import CoreMotion
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let fusedMotionHandler = FusedMotionStreamHandler()
  private var hapticManager: Any?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterEventChannel(
      name: "motionarcade/fused_motion",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setStreamHandler(fusedMotionHandler)

    let hapticChannel = FlutterMethodChannel(
      name: "motionarcade/haptics",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    if #available(iOS 13.0, *) {
      if hapticManager == nil {
        hapticManager = PreciseHapticManager()
      }
    }
    hapticChannel.setMethodCallHandler { [weak self] call, result in
      self?.handleHapticMethodCall(call: call, result: result)
    }
  }

  private func handleHapticMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "play" {
      guard let args = call.arguments as? [String: Any],
            let intensity = args["intensity"] as? Double,
            let sharpness = args["sharpness"] as? Double,
            let duration = args["duration"] as? Double else {
        result(FlutterError(code: "invalid_arguments", message: "Missing arguments for play", details: nil))
        return
      }

      if #available(iOS 13.0, *), let manager = hapticManager as? PreciseHapticManager {
        manager.play(intensity: Float(intensity), sharpness: Float(sharpness), duration: duration)
      } else {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = intensity > 0.7 ? .heavy : (intensity > 0.4 ? .medium : .light)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
      }
      result(nil)
    } else if call.method == "playPattern" {
      guard let args = call.arguments as? [String: Any],
            let pattern = args["pattern"] as? [[String: Any]] else {
        result(FlutterError(code: "invalid_arguments", message: "Missing pattern for playPattern", details: nil))
        return
      }

      if #available(iOS 13.0, *), let manager = hapticManager as? PreciseHapticManager {
        manager.playPattern(pattern)
      } else {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
      }
      result(nil)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}

@available(iOS 13.0, *)
class PreciseHapticManager {
  private var engine: CHHapticEngine?

  init() {
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
    do {
      engine = try CHHapticEngine()
      try engine?.start()
    } catch {
      print("Failed to initialize Core Haptics engine: \(error)")
    }
  }

  func play(intensity: Float, sharpness: Float, duration: Double) {
    guard let engine = engine else {
      let style: UIImpactFeedbackGenerator.FeedbackStyle = intensity > 0.7 ? .heavy : (intensity > 0.4 ? .medium : .light)
      let generator = UIImpactFeedbackGenerator(style: style)
      generator.prepare()
      generator.impactOccurred()
      return
    }

    do {
      try engine.start()
      let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
      let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)

      let event: CHHapticEvent
      if duration > 0 {
        event = CHHapticEvent(
          eventType: .hapticContinuous,
          parameters: [intensityParam, sharpnessParam],
          relativeTime: 0,
          duration: duration
        )
      } else {
        event = CHHapticEvent(
          eventType: .hapticTransient,
          parameters: [intensityParam, sharpnessParam],
          relativeTime: 0
        )
      }

      let pattern = try CHHapticPattern(events: [event], parameters: [])
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: 0)
    } catch {
      print("Error playing haptic: \(error)")
    }
  }

  func playPattern(_ patternData: [[String: Any]]) {
    guard let engine = engine else {
      let generator = UIImpactFeedbackGenerator(style: .medium)
      generator.prepare()
      generator.impactOccurred()
      return
    }

    do {
      try engine.start()
      var events: [CHHapticEvent] = []

      for data in patternData {
        let typeStr = data["type"] as? String ?? "transient"
        let time = data["time"] as? Double ?? 0.0
        let duration = data["duration"] as? Double ?? 0.1
        let intensity = data["intensity"] as? Double ?? 1.0
        let sharpness = data["sharpness"] as? Double ?? 0.5

        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity))
        let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(sharpness))

        let eventType: CHHapticEvent.EventType = typeStr == "continuous" ? .hapticContinuous : .hapticTransient

        let event: CHHapticEvent
        if eventType == .hapticContinuous {
          event = CHHapticEvent(
            eventType: eventType,
            parameters: [intensityParam, sharpnessParam],
            relativeTime: time,
            duration: duration
          )
        } else {
          event = CHHapticEvent(
            eventType: eventType,
            parameters: [intensityParam, sharpnessParam],
            relativeTime: time
          )
        }
        events.append(event)
      }

      let pattern = try CHHapticPattern(events: events, parameters: [])
      let player = try engine.makePlayer(with: pattern)
      try player.start(atTime: 0)
    } catch {
      print("Error playing haptic pattern: \(error)")
    }
  }
}


final class FusedMotionStreamHandler: NSObject, FlutterStreamHandler {
  private let motionManager = CMMotionManager()
  private let queue = OperationQueue()
  private var eventSink: FlutterEventSink?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    guard motionManager.isDeviceMotionAvailable else {
      return FlutterError(
        code: "fused_motion_unavailable",
        message: "Device motion is unavailable on this device.",
        details: nil
      )
    }

    eventSink = events
    queue.name = "motionarcade.fused_motion"
    motionManager.deviceMotionUpdateInterval = 1.0 / 60.0

    let availableFrames = CMMotionManager.availableAttitudeReferenceFrames()
    let referenceFrame: CMAttitudeReferenceFrame =
      availableFrames.contains(.xArbitraryCorrectedZVertical)
      ? .xArbitraryCorrectedZVertical
      : .xArbitraryZVertical

    motionManager.startDeviceMotionUpdates(
      using: referenceFrame,
      to: queue
    ) { [weak self] motion, error in
      guard let self else { return }
      if let error {
        DispatchQueue.main.async {
          self.eventSink?(
            FlutterError(
              code: "fused_motion_error",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
        return
      }
      guard let motion else { return }
      self.emit(motion: motion, source: self.sourceName(for: referenceFrame))
    }

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motionManager.stopDeviceMotionUpdates()
    eventSink = nil
    return nil
  }

  private func emit(motion: CMDeviceMotion, source: String) {
    let metersPerSecondSquared = 9.80665
    let quaternion = motion.attitude.quaternion
    let gravity = motion.gravity
    let userAcceleration = motion.userAcceleration
    let rotationRate = motion.rotationRate
    let payload: [String: Any] = [
      "attitudeX": quaternion.x,
      "attitudeY": quaternion.y,
      "attitudeZ": quaternion.z,
      "attitudeW": quaternion.w,
      "gravityX": gravity.x * metersPerSecondSquared,
      "gravityY": gravity.y * metersPerSecondSquared,
      "gravityZ": gravity.z * metersPerSecondSquared,
      "userAccelerationX": userAcceleration.x * metersPerSecondSquared,
      "userAccelerationY": userAcceleration.y * metersPerSecondSquared,
      "userAccelerationZ": userAcceleration.z * metersPerSecondSquared,
      "rotationRateX": rotationRate.x,
      "rotationRateY": rotationRate.y,
      "rotationRateZ": rotationRate.z,
      "timestampMillis": Date().timeIntervalSince1970 * 1000,
      "source": source,
      "isAvailable": true,
    ]

    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(payload)
    }
  }

  private func sourceName(for frame: CMAttitudeReferenceFrame) -> String {
    switch frame {
    case .xArbitraryCorrectedZVertical:
      return "ios_core_motion_corrected"
    case .xArbitraryZVertical:
      return "ios_core_motion"
    case .xMagneticNorthZVertical:
      return "ios_core_motion_magnetic"
    case .xTrueNorthZVertical:
      return "ios_core_motion_true_north"
    default:
      return "ios_core_motion"
    }
  }
}
