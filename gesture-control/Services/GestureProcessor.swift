//
//  GestureProcessor.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import AppKit
import CoreGraphics
import CoreMedia
import Foundation

class GestureProcessor: ObservableObject, CameraManagerDelegate {

  // Dependencies
  private let detector = HandPoseDetector()
  private let simulator = InputSimulator()

  // Settings
  @Published var isEnabled: Bool = false
  @Published var pointerSmoothing: Int = 1  // Lower default for snappier cursor
  @Published var sensitivity: CGFloat = 2.0
  @Published var scrollSpeed: Double = 20.0  // Increased default slightly

  // Processing
  private struct PendingFrame {
    let sampleBuffer: CMSampleBuffer
    let generation: Int
  }

  private struct LowPassFilter {
    private var value: Double?

    mutating func filter(_ input: Double, alpha: Double) -> Double {
      guard let value else {
        self.value = input
        return input
      }
      let filtered = alpha * input + (1.0 - alpha) * value
      self.value = filtered
      return filtered
    }

    mutating func reset() {
      value = nil
    }
  }

  fileprivate struct OneEuroFilter {
    var minCutoff: Double
    var beta: Double
    var dCutoff: Double

    private var lastTimestamp: TimeInterval?
    private var lastRaw: Double?
    private var valueFilter = LowPassFilter()
    private var derivativeFilter = LowPassFilter()

    init(minCutoff: Double, beta: Double, dCutoff: Double) {
      self.minCutoff = minCutoff
      self.beta = beta
      self.dCutoff = dCutoff
    }

    mutating func filter(_ input: Double, timestamp: TimeInterval) -> Double {
      let dt: Double
      if let lastTimestamp {
        let delta = timestamp - lastTimestamp
        dt = max(delta, 1.0 / 120.0)
      } else {
        dt = 1.0 / 60.0
      }

      lastTimestamp = timestamp

      let derivative = lastRaw.map { (input - $0) / dt } ?? 0
      lastRaw = input

      let dAlpha = alpha(cutoff: dCutoff, dt: dt)
      let smoothedDerivative = derivativeFilter.filter(derivative, alpha: dAlpha)
      let cutoff = minCutoff + beta * abs(smoothedDerivative)
      let alphaValue = alpha(cutoff: cutoff, dt: dt)

      return valueFilter.filter(input, alpha: alphaValue)
    }

    mutating func reset() {
      lastTimestamp = nil
      lastRaw = nil
      valueFilter.reset()
      derivativeFilter.reset()
    }

    private func alpha(cutoff: Double, dt: Double) -> Double {
      let tau = 1.0 / (2.0 * Double.pi * cutoff)
      return 1.0 / (1.0 + tau / dt)
    }
  }

  private let visionQueue = DispatchQueue(label: "gesture.vision", qos: .userInitiated)
  private let bufferQueue = DispatchQueue(label: "gesture.buffer")
  private var isProcessingFrame = false
  private var pendingFrame: PendingFrame?
  private var processingGeneration = 0

  // State
  private var lastLandmarks: HandLandmarks?
  private var lastPointerScreenPoint: CGPoint?
  private var lastSmoothedPoint: CGPoint?
  private var lastWristTimestamp: TimeInterval?
  private var pointerFilterX = OneEuroFilter(minCutoff: 1.2, beta: 0.6, dCutoff: 1.0)
  private var pointerFilterY = OneEuroFilter(minCutoff: 1.2, beta: 0.6, dCutoff: 1.0)
  private var lastClickTime: Date = .distantPast
  private var lastNavigationTime: Date = .distantPast
  private let clickCooldown: TimeInterval = 0.35
  private let navigationCooldown: TimeInterval = 1.0
  private let pointerDeadzone: CGFloat = 0.0015
  private let pointerMinCutoff: Double = 0.3
  private let pointerMaxCutoff: Double = 1.5
  private let pointerMinBeta: Double = 0.05
  private let pointerMaxBeta: Double = 0.7
  private let pointerDerivativeCutoff: Double = 1.0
  private let scrollVelocityDeadzone: Double = 0.15
  private let scrollVelocityScale: Double = 100.0

  enum GestureState {
    case unknown
    case pointer  // Open Palm
    case fist  // All Closed (Scroll)
    case thumbLeft  // Fist + Thumb Left (Back)
    case thumbRight  // Fist + Thumb Right (Forward)
    // Two Fingers (Victory) - Kept for user preference or legacy, but detecting 'Fist' for scroll now per request.
    case scroll
  }

  static func detectState(for landmarks: HandLandmarks) -> GestureState? {
    guard let wrist = landmarks.wrist, let middleMCP = landmarks.middleMCP else { return nil }
    return detectState(for: landmarks, wrist: wrist, middleMCP: middleMCP)
  }

  private var currentState: GestureState = .unknown

  private var stateConfidenceCounter = 0
  private let stateConfidenceThreshold = 1
  // Lowered to cut gesture-to-action latency.
  private var pendingState: GestureState = .unknown

  // To track state transitions for Click
  private var previousState: GestureState = .unknown

  // Logic
  func didOutput(sampleBuffer: CMSampleBuffer) {
    guard isEnabled else { return }
    var shouldProcess = false
    var generation = 0
    let buffer = sampleBuffer

    bufferQueue.sync {
      generation = processingGeneration

      if isProcessingFrame {
        pendingFrame = PendingFrame(sampleBuffer: buffer, generation: generation)
      } else {
        isProcessingFrame = true
        shouldProcess = true
      }
    }

    if shouldProcess {
      processSampleBufferAsync(buffer, generation: generation)
    }
  }

  private func processSampleBufferAsync(_ sampleBuffer: CMSampleBuffer, generation: Int) {
    visionQueue.async { [weak self] in
      guard let self else { return }

      defer {
        self.finishProcessing()
      }

      guard self.isEnabled else { return }
      let currentGeneration = self.bufferQueue.sync { self.processingGeneration }
      guard generation == currentGeneration else { return }

      let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
      let safeTimestamp = timestamp.isFinite ? timestamp : 0

      guard let landmarks = self.detector.process(sampleBuffer: sampleBuffer) else {
        return
      }

      self.processGestures(landmarks: landmarks, timestamp: safeTimestamp)
    }
  }

  private func finishProcessing() {
    var nextFrame: PendingFrame?

    bufferQueue.sync {
      if let pending = pendingFrame {
        nextFrame = pending
        pendingFrame = nil
      } else {
        isProcessingFrame = false
      }
    }

    if let nextFrame {
      processSampleBufferAsync(nextFrame.sampleBuffer, generation: nextFrame.generation)
    }
  }

  func resetState() {
    lastLandmarks = nil
    lastPointerScreenPoint = nil
    lastSmoothedPoint = nil
    lastWristTimestamp = nil
    pointerFilterX.reset()
    pointerFilterY.reset()
    currentState = .unknown
    pendingState = .unknown
    previousState = .unknown
    stateConfidenceCounter = 0
    lastClickTime = .distantPast
    lastNavigationTime = .distantPast

    bufferQueue.sync {
      processingGeneration += 1
      pendingFrame = nil
    }
  }

  private func processGestures(landmarks: HandLandmarks, timestamp: TimeInterval) {
    guard let wrist = landmarks.wrist,
      let middleMCP = landmarks.middleMCP
    else { return }

    let detectedState = Self.detectState(for: landmarks, wrist: wrist, middleMCP: middleMCP)

    // --- 2. State Hysteresis (Debounce) ---

    if detectedState == pendingState {
      stateConfidenceCounter += 1
    } else {
      pendingState = detectedState
      stateConfidenceCounter = 0
    }

    if stateConfidenceCounter >= stateConfidenceThreshold {
      // State Transition
      if currentState != pendingState {
        previousState = currentState
        currentState = pendingState

        handleStateTransition(from: previousState, to: currentState, landmarks: landmarks)
      }
    }

    // --- 3. Continuous Actions ---

    switch currentState {
    case .pointer:
      handlePointerBehavior(landmarks: landmarks, timestamp: timestamp)
    case .fist:
      // Fist is now Scroll per user request.
      handleScrollBehavior(landmarks: landmarks, timestamp: timestamp)
    case .scroll:
      // Victory is also Scroll.
      handleScrollBehavior(landmarks: landmarks, timestamp: timestamp)
    default:
      break
    }

    lastLandmarks = landmarks
  }

  private static func detectState(for landmarks: HandLandmarks, wrist: CGPoint, middleMCP: CGPoint)
    -> GestureState
  {
    func dist(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
      return hypot(p1.x - p2.x, p1.y - p2.y)
    }

    let handScale = dist(wrist, middleMCP)
    guard handScale > 0 else { return .unknown }

    func isFingerOpen(tip: CGPoint?, pip: CGPoint?) -> Bool {
      guard let tip = tip, let pip = pip else { return false }
      let tipDist = dist(tip, wrist)
      let pipDist = dist(pip, wrist)
      return tipDist > pipDist && tipDist > (handScale * 1.1)
    }

    let indexOpen = isFingerOpen(tip: landmarks.indexTip, pip: landmarks.indexPIP)
    let middleOpen = isFingerOpen(tip: landmarks.middleTip, pip: landmarks.middlePIP)
    let ringOpen = isFingerOpen(tip: landmarks.ringTip, pip: landmarks.ringPIP)
    let littleOpen = isFingerOpen(tip: landmarks.littleTip, pip: landmarks.littlePIP)
    let thumbOpen = isFingerOpen(tip: landmarks.thumbTip, pip: landmarks.middleMCP)

    let fourFingersOpen = indexOpen && middleOpen && ringOpen && littleOpen
    let fourFingersClosed = !indexOpen && !middleOpen && !ringOpen && !littleOpen

    if fourFingersOpen {
      return .pointer
    }

    if fourFingersClosed {
      if !thumbOpen {
        return .fist
      }

      if let tip = landmarks.thumbTip {
        let centerX = middleMCP.x
        if tip.x < centerX - 0.05 {
          return .thumbLeft
        }
        if tip.x > centerX + 0.05 {
          return .thumbRight
        }
      }

      return .fist
    }

    if indexOpen && middleOpen && !ringOpen && !littleOpen {
      return .scroll
    }

    return .unknown
  }

  private func handleStateTransition(
    from old: GestureState, to new: GestureState, landmarks: HandLandmarks
  ) {
    // CLICK: Palm (Pointer) -> Fist (Scroll)
    if old == .pointer && new == .fist {
      if Date().timeIntervalSince(lastClickTime) > clickCooldown {
        print("Click Triggered (Palm -> Fist)")
        let clickPoint =
          lastPointerScreenPoint
          ?? {
            if let indexTip = landmarks.indexTip { return mapToScreen(point: indexTip) }
            return nil
          }()
        if let clickPoint {
          simulator.click(at: clickPoint)
          lastClickTime = Date()
        }
      }
    }

    if new == .fist || new == .scroll {
      lastWristTimestamp = nil
    }

    // Navigation One-Shots
    // We add a cooldown to prevent rapid firing if state flutters
    if Date().timeIntervalSince(lastNavigationTime) > navigationCooldown {
      if new == .thumbLeft {
        print("Thumb Left -> Back")
        simulator.navigateBack()
        lastNavigationTime = Date()
      } else if new == .thumbRight {
        print("Thumb Right -> Forward")
        simulator.navigateForward()
        lastNavigationTime = Date()
      }
    }
  }

  private func handlePointerBehavior(landmarks: HandLandmarks, timestamp: TimeInterval) {
    guard let indexTip = landmarks.indexTip else { return }

    // Move Pointer
    let smoothedPoint = smooth(point: indexTip, timestamp: timestamp)
    let targetPoint = mapToScreen(point: smoothedPoint)
    lastPointerScreenPoint = targetPoint
    simulator.moveMouse(to: targetPoint)
  }

  private func handleScrollBehavior(landmarks: HandLandmarks, timestamp: TimeInterval) {
    // Scroll using Fist Movement (Up/Down)
    guard let wrist = landmarks.wrist else { return }

    guard let lastWrist = lastLandmarks?.wrist,
      let lastTimestamp = lastWristTimestamp
    else {
      lastWristTimestamp = timestamp
      return
    }

    let dt = max(timestamp - lastTimestamp, 1.0 / 120.0)
    let dy = wrist.y - lastWrist.y
    let velocity = Double(dy) / dt

    if abs(velocity) > scrollVelocityDeadzone {
      let speed = Int32(velocity * scrollVelocityScale)
      let finalSpeed = Int32(Double(speed) * (scrollSpeed / 10.0))
      simulator.scroll(dx: 0, dy: finalSpeed)
    }

    lastWristTimestamp = timestamp
  }

  private func pointerFilterParameters() -> (minCutoff: Double, beta: Double) {
    let clamped = min(max(pointerSmoothing, 1), 20)
    let t = Double(clamped - 1) / 19.0
    let minCutoff = pointerMaxCutoff - t * (pointerMaxCutoff - pointerMinCutoff)
    let beta = pointerMaxBeta - t * (pointerMaxBeta - pointerMinBeta)
    return (minCutoff, beta)
  }

  private func smooth(point: CGPoint, timestamp: TimeInterval) -> CGPoint {
    let params = pointerFilterParameters()
    pointerFilterX.minCutoff = params.minCutoff
    pointerFilterY.minCutoff = params.minCutoff
    pointerFilterX.beta = params.beta
    pointerFilterY.beta = params.beta
    pointerFilterX.dCutoff = pointerDerivativeCutoff
    pointerFilterY.dCutoff = pointerDerivativeCutoff

    let filteredX = pointerFilterX.filter(Double(point.x), timestamp: timestamp)
    let filteredY = pointerFilterY.filter(Double(point.y), timestamp: timestamp)
    let filteredPoint = CGPoint(x: filteredX, y: filteredY)

    guard let lastPoint = lastSmoothedPoint else {
      lastSmoothedPoint = filteredPoint
      return filteredPoint
    }

    let dx = filteredPoint.x - lastPoint.x
    let dy = filteredPoint.y - lastPoint.y
    let distance = hypot(dx, dy)
    let deadzone = pointerDeadzone / max(sensitivity, 0.1)

    if distance < deadzone {
      return lastPoint
    }

    lastSmoothedPoint = filteredPoint
    return filteredPoint
  }

  private func mapToScreen(point: CGPoint) -> CGPoint {
    let activeRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    let normalizedX = (point.x - activeRect.minX) / activeRect.width
    let normalizedY = (point.y - activeRect.minY) / activeRect.height

    let scaledX = (normalizedX - 0.5) * sensitivity + 0.5
    let scaledY = (normalizedY - 0.5) * sensitivity + 0.5

    let clampedX = min(max(scaledX, 0), 1)
    let clampedY = min(max(scaledY, 0), 1)

    let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let screenX = (1 - clampedX) * screenFrame.width
    let screenY = (1 - clampedY) * screenFrame.height

    return CGPoint(x: screenX, y: screenY)
  }
}
