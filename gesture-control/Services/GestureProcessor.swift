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

  enum TrackingMode: String, CaseIterable, Identifiable, Hashable {
    case handPointer
    case eyePointer

    var id: String { rawValue }

    var title: String {
      switch self {
      case .handPointer:
        return "Hand Pointer"
      case .eyePointer:
        return "Eye Pointer"
      }
    }
  }

  enum EyeCalibrationState: Equatable {
    case needsCalibration
    case calibrating(step: Int, total: Int)
    case calibrated
    case failed
  }

  enum GestureState {
    case unknown
    case pointer
    case fist
    case indexLeft
    case indexRight
    case scroll
  }

  enum OverlayAction: Equatable {
    case idle
    case move
    case scroll
    case scrollUp
    case scrollDown
    case back
    case forward
    case click
  }

  private enum PointerInputMode {
    case hand
    case eye
  }

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

      self.lastTimestamp = timestamp

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

  private struct EyeCalibrationSession {
    static let warmupFrames = 8
    static let sampleFrames = 18

    let targets: [CGPoint]
    var targetIndex = 0
    var warmupFrameCount = 0
    var capturedVectors: [EyeFeatureVector] = []
    var samples: [EyeCalibrationSample] = []

    var totalSteps: Int { targets.count }

    var currentTarget: CGPoint? {
      guard targetIndex < targets.count else { return nil }
      return targets[targetIndex]
    }

    var currentStep: Int {
      min(targetIndex + 1, totalSteps)
    }

    mutating func ingest(_ feature: EyeFeatureVector) -> Outcome {
      guard let target = currentTarget else { return .failed }

      if warmupFrameCount < Self.warmupFrames {
        warmupFrameCount += 1
        return .collecting(step: currentStep, total: totalSteps)
      }

      capturedVectors.append(feature)
      guard capturedVectors.count >= Self.sampleFrames else {
        return .collecting(step: currentStep, total: totalSteps)
      }

      guard let averaged = EyeFeatureVector.average(capturedVectors) else {
        return .failed
      }

      samples.append(EyeCalibrationSample(feature: averaged, target: target))
      targetIndex += 1
      warmupFrameCount = 0
      capturedVectors.removeAll(keepingCapacity: true)

      if targetIndex >= totalSteps {
        guard let model = EyeCalibrationModel.fit(samples: samples) else {
          return .failed
        }
        return .completed(model)
      }

      guard let nextTarget = currentTarget else { return .failed }
      return .advanced(
        step: currentStep,
        total: totalSteps,
        nextTarget: nextTarget
      )
    }

    enum Outcome {
      case collecting(step: Int, total: Int)
      case advanced(step: Int, total: Int, nextTarget: CGPoint)
      case completed(EyeCalibrationModel)
      case failed
    }
  }

  private struct PersistedEyeCalibrationStore: Codable {
    var modelsByDevice: [String: EyeCalibrationModel] = [:]
  }

  // Dependencies
  private let detector = HandPoseDetector()
  private let eyeDetector = EyePoseDetector()
  private let simulator = InputSimulator()

  // Settings
  @Published var isEnabled: Bool = false
  @Published var isFloatingPreviewEnabled: Bool = true
  @Published var pointerSmoothing: Int = 1
  @Published var sensitivity: CGFloat = 2.0
  @Published var scrollSpeed: Double = 20.0
  @Published var trackingMode: TrackingMode = .handPointer {
    didSet {
      guard trackingMode != oldValue else { return }
      resetPointerTracking()
      if trackingMode == .eyePointer, eyeCalibrationModel == nil, !isEyeCalibrationActive {
        publishEyeCalibrationState(
          .needsCalibration,
          message: "Run the 5-point calibration to enable eye-based cursor movement."
        )
      }
    }
  }

  @Published private(set) var eyeCalibrationState: EyeCalibrationState = .needsCalibration
  @Published private(set) var eyeCalibrationMessage: String =
    "Run the 5-point calibration to enable eye-based cursor movement."
  @Published private(set) var eyeCalibrationTarget: CGPoint?
  @Published private(set) var isEyeCalibrationActive = false
  @Published private(set) var overlayAction: OverlayAction = .idle
  @Published private(set) var overlayHandBounds: CGRect?
  @Published private(set) var overlayHandPoint: CGPoint?

  var hasEyeCalibration: Bool {
    eyeCalibrationModel != nil
  }

  // Processing
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
  private var lastEyeTimestamp: TimeInterval?
  private var pointerFilterX = OneEuroFilter(minCutoff: 1.2, beta: 0.6, dCutoff: 1.0)
  private var pointerFilterY = OneEuroFilter(minCutoff: 1.2, beta: 0.6, dCutoff: 1.0)
  private var lastClickTime: Date = .distantPast
  private var lastNavigationTime: Date = .distantPast
  private var isPinchActive = false
  private let clickCooldown: TimeInterval = 0.35
  private let navigationCooldown: TimeInterval = 1.0
  private let pinchStartThreshold: CGFloat = 0.35
  private let pinchReleaseThreshold: CGFloat = 0.45
  private let pointerDeadzone: CGFloat = 0.0015
  private let pointerMinCutoff: Double = 0.3
  private let pointerMaxCutoff: Double = 1.5
  private let pointerMinBeta: Double = 0.05
  private let pointerMaxBeta: Double = 0.7
  private let pointerDerivativeCutoff: Double = 1.0
  private let scrollVelocityDeadzone: Double = 0.15
  private let scrollVelocityScale: Double = 100.0
  private let eyePointerMinCutoff: Double = 0.22
  private let eyePointerBeta: Double = 0.08
  private let eyePointerDeadzone: CGFloat = 0.0025
  private let eyePointerStepLimit: CGFloat = 100.0
  private let eyeObservationTimeout: TimeInterval = 0.45
  private let eyeCalibrationStoreKey = "gesture-control.eye-calibration.v1"
  private var currentCameraDeviceID: String?
  private var eyeCalibrationModel: EyeCalibrationModel?
  private var eyeCalibrationSession: EyeCalibrationSession?

  // Gesture tracking
  private var currentState: GestureState = .unknown
  private var stateConfidenceCounter = 0
  private let stateConfidenceThreshold = 1
  private var pendingState: GestureState = .unknown
  private var previousState: GestureState = .unknown
  private var overlayOverride: (action: OverlayAction, expiresAt: TimeInterval)?
  private var lastScrollDirection: OverlayAction?
  private var lastScrollDirectionTimestamp: TimeInterval = 0
  private let scrollDirectionHold: TimeInterval = 0.4

  static func detectState(for landmarks: HandLandmarks) -> GestureState? {
    guard let wrist = landmarks.wrist, let middleMCP = landmarks.middleMCP else { return nil }
    return detectState(for: landmarks, wrist: wrist, middleMCP: middleMCP)
  }

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

  func startEyeCalibration() {
    let session = EyeCalibrationSession(targets: Self.eyeCalibrationTargets)
    eyeCalibrationSession = session
    eyeCalibrationModel = nil
    resetPointerTracking()
    eyeCalibrationTarget = session.currentTarget
    isEyeCalibrationActive = true
    publishEyeCalibrationState(
      .calibrating(step: session.currentStep, total: session.totalSteps),
      message: "Look at each dot until it advances.",
      target: session.currentTarget,
      isActive: true
    )
  }

  func cancelEyeCalibration() {
    eyeCalibrationSession = nil
    eyeCalibrationTarget = nil
    isEyeCalibrationActive = false
    publishEyeCalibrationState(
      eyeCalibrationModel == nil ? .needsCalibration : .calibrated,
      message: eyeCalibrationModel == nil
        ? "Calibration stopped. Run the 5-point flow to enable eye-based cursor movement."
        : "Eye tracking is calibrated for the selected camera.",
      target: nil,
      isActive: false
    )
  }

  func updateCurrentCameraDevice(id: String?) {
    guard currentCameraDeviceID != id else { return }
    currentCameraDeviceID = id
    eyeCalibrationSession = nil
    eyeCalibrationTarget = nil
    isEyeCalibrationActive = false
    resetPointerTracking()

    guard let id else {
      eyeCalibrationModel = nil
      publishEyeCalibrationState(
        .needsCalibration,
        message: "Select a camera before calibrating eye tracking."
      )
      return
    }

    let store = loadEyeCalibrationStore()
    eyeCalibrationModel = store.modelsByDevice[id]

    if eyeCalibrationModel == nil {
      publishEyeCalibrationState(
        .needsCalibration,
        message: "Run the 5-point calibration for this camera before using eye pointer mode."
      )
    } else {
      publishEyeCalibrationState(
        .calibrated,
        message: "Eye tracking is calibrated for the selected camera."
      )
    }
  }

  func resetState() {
    lastLandmarks = nil
    resetPointerTracking()
    currentState = .unknown
    pendingState = .unknown
    previousState = .unknown
    stateConfidenceCounter = 0
    lastClickTime = .distantPast
    lastNavigationTime = .distantPast
    isPinchActive = false
    overlayOverride = nil
    lastScrollDirection = nil
    lastScrollDirectionTimestamp = 0
    if isEyeCalibrationActive {
      cancelEyeCalibration()
    }
    DispatchQueue.main.async {
      self.overlayAction = .idle
      self.overlayHandBounds = nil
      self.overlayHandPoint = nil
    }

    bufferQueue.sync {
      processingGeneration += 1
      pendingFrame = nil
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
      let shouldProcessEyes = self.trackingMode == .eyePointer || self.isEyeCalibrationActive

      let eyeObservation: EyeTrackingObservation?
      if shouldProcessEyes {
        eyeObservation = self.eyeDetector.process(sampleBuffer: sampleBuffer)
      } else {
        eyeObservation = nil
      }

      let handLandmarks = self.detector.process(sampleBuffer: sampleBuffer)

      self.processEyeObservation(eyeObservation, timestamp: safeTimestamp)

      if let handLandmarks {
        self.processGestures(landmarks: handLandmarks, timestamp: safeTimestamp)
      } else {
        self.handleMissingHand()
      }
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

  private func processGestures(landmarks: HandLandmarks, timestamp: TimeInterval) {
    guard let wrist = landmarks.wrist, let middleMCP = landmarks.middleMCP else {
      handleMissingHand()
      return
    }

    let detectedState = Self.detectState(for: landmarks, wrist: wrist, middleMCP: middleMCP)
    let handScale = hypot(wrist.x - middleMCP.x, wrist.y - middleMCP.y)
    let allowPinchClick = detectedState != .fist && detectedState != .scroll

    if handScale > 0 {
      handlePinchClick(
        landmarks: landmarks,
        handScale: handScale,
        allowClick: allowPinchClick
      )
    } else {
      isPinchActive = false
    }

    if detectedState == pendingState {
      stateConfidenceCounter += 1
    } else {
      pendingState = detectedState
      stateConfidenceCounter = 0
    }

    if stateConfidenceCounter >= stateConfidenceThreshold, currentState != pendingState {
      previousState = currentState
      currentState = pendingState
      handleStateTransition(from: previousState, to: currentState)
    }

    switch currentState {
    case .pointer where trackingMode == .handPointer:
      handleHandPointerBehavior(landmarks: landmarks, timestamp: timestamp)
    case .fist, .scroll:
      handleScrollBehavior(landmarks: landmarks, timestamp: timestamp)
    default:
      break
    }

    updateOverlay(for: currentState, landmarks: landmarks)
    lastLandmarks = landmarks
  }

  private func processEyeObservation(
    _ observation: EyeTrackingObservation?,
    timestamp: TimeInterval
  ) {
    guard let observation else {
      handleMissingEyeObservation(timestamp: timestamp)
      return
    }

    lastEyeTimestamp = timestamp

    let wasCalibrating = isEyeCalibrationActive
    if wasCalibrating, let feature = observation.featureVector {
      captureCalibration(feature: feature)
    }

    if wasCalibrating {
      return
    }

    guard
      trackingMode == .eyePointer,
      !isEyeCalibrationActive,
      let eyeCalibrationModel,
      let feature = observation.featureVector
    else {
      return
    }

    let normalizedPoint = eyeCalibrationModel.map(feature: feature)
    let smoothedPoint = smooth(
      point: normalizedPoint,
      timestamp: timestamp,
      mode: .eye
    )
    let targetPoint = mapNormalizedScreenPointToScreen(smoothedPoint)
    let stabilizedPoint = limitPointerStep(to: targetPoint, maxDistance: eyePointerStepLimit)

    guard shouldMovePointer(to: stabilizedPoint, minimumDistance: 2.0) else { return }

    lastPointerScreenPoint = stabilizedPoint
    simulator.moveMouse(to: stabilizedPoint)
  }

  private static func detectState(for landmarks: HandLandmarks, wrist: CGPoint, middleMCP: CGPoint)
    -> GestureState
  {
    func dist(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
      hypot(p1.x - p2.x, p1.y - p2.y)
    }

    let handScale = dist(wrist, middleMCP)
    guard handScale > 0 else { return .unknown }

    func isFingerOpen(tip: CGPoint?, pip: CGPoint?) -> Bool {
      guard let tip, let pip else { return false }
      let tipDist = dist(tip, wrist)
      let pipDist = dist(pip, wrist)
      return tipDist > pipDist && tipDist > (handScale * 1.1)
    }

    let indexOpen = isFingerOpen(tip: landmarks.indexTip, pip: landmarks.indexPIP)
    let middleOpen = isFingerOpen(tip: landmarks.middleTip, pip: landmarks.middlePIP)
    let ringOpen = isFingerOpen(tip: landmarks.ringTip, pip: landmarks.ringPIP)
    let littleOpen = isFingerOpen(tip: landmarks.littleTip, pip: landmarks.littlePIP)

    let fourFingersOpen = indexOpen && middleOpen && ringOpen && littleOpen
    let fourFingersClosed = !indexOpen && !middleOpen && !ringOpen && !littleOpen

    if fourFingersOpen {
      return .pointer
    }

    if indexOpen && !middleOpen && !ringOpen && !littleOpen, let indexTip = landmarks.indexTip {
      let dx = indexTip.x - middleMCP.x
      let dy = indexTip.y - middleMCP.y
      let horizontalBias = abs(dx) > abs(dy) * 1.2
      let threshold = handScale * 0.35
      if horizontalBias && abs(dx) > threshold {
        return dx < 0 ? .indexRight : .indexLeft
      }
    }

    if fourFingersClosed {
      return .fist
    }

    if indexOpen && middleOpen && !ringOpen && !littleOpen {
      return .scroll
    }

    return .unknown
  }

  private func handleStateTransition(from old: GestureState, to new: GestureState) {
    if new == .fist || new == .scroll {
      lastWristTimestamp = nil
    }

    if Date().timeIntervalSince(lastNavigationTime) <= navigationCooldown {
      return
    }

    if new == .indexLeft {
      simulator.navigateBack()
      lastNavigationTime = Date()
    } else if new == .indexRight {
      simulator.navigateForward()
      lastNavigationTime = Date()
    }
  }

  private func setOverlayOverride(_ action: OverlayAction, duration: TimeInterval) {
    overlayOverride = (action, ProcessInfo.processInfo.systemUptime + duration)
  }

  private func clearOverlayForMissingHand() {
    DispatchQueue.main.async {
      self.overlayAction = .idle
      self.overlayHandBounds = nil
      self.overlayHandPoint = nil
    }
  }

  private func updateOverlay(for state: GestureState, landmarks: HandLandmarks) {
    let now = ProcessInfo.processInfo.systemUptime
    var action = overlayAction(for: state, now: now)

    if let override = overlayOverride, override.expiresAt > now {
      action = override.action
    } else {
      overlayOverride = nil
    }

    let bounds = handBounds(for: landmarks)
    let point = palmCenter(for: landmarks) ?? landmarks.indexTip ?? landmarks.wrist

    DispatchQueue.main.async {
      self.overlayAction = action
      self.overlayHandBounds = bounds
      self.overlayHandPoint = point
    }
  }

  private func overlayAction(for state: GestureState, now: TimeInterval) -> OverlayAction {
    switch state {
    case .pointer:
      return trackingMode == .handPointer ? .move : .idle
    case .indexLeft:
      return .back
    case .indexRight:
      return .forward
    case .fist, .scroll:
      if let direction = lastScrollDirection,
        now - lastScrollDirectionTimestamp <= scrollDirectionHold
      {
        return direction
      }
      return .scroll
    case .unknown:
      return .idle
    }
  }

  private func handBounds(for landmarks: HandLandmarks) -> CGRect? {
    let points = [
      landmarks.thumbTip,
      landmarks.indexTip,
      landmarks.middleTip,
      landmarks.ringTip,
      landmarks.littleTip,
      landmarks.indexPIP,
      landmarks.middlePIP,
      landmarks.ringPIP,
      landmarks.littlePIP,
      landmarks.wrist,
      landmarks.middleMCP,
    ].compactMap { $0 }

    guard
      let minX = points.map(\.x).min(),
      let maxX = points.map(\.x).max(),
      let minY = points.map(\.y).min(),
      let maxY = points.map(\.y).max()
    else {
      return nil
    }

    let width = maxX - minX
    let height = maxY - minY
    let padding = max(width, height) * 0.15

    return CGRect(
      x: max(0, minX - padding),
      y: max(0, minY - padding),
      width: min(1, maxX + padding) - max(0, minX - padding),
      height: min(1, maxY + padding) - max(0, minY - padding)
    )
  }

  private func handleHandPointerBehavior(landmarks: HandLandmarks, timestamp: TimeInterval) {
    guard let pointerPoint = palmCenter(for: landmarks) ?? landmarks.indexTip else { return }

    let smoothedPoint = smooth(point: pointerPoint, timestamp: timestamp, mode: .hand)
    let targetPoint = mapHandPointToScreen(point: smoothedPoint)
    lastPointerScreenPoint = targetPoint
    simulator.moveMouse(to: targetPoint)
  }

  private func handleScrollBehavior(landmarks: HandLandmarks, timestamp: TimeInterval) {
    guard let wrist = landmarks.wrist else { return }

    guard
      let lastWrist = lastLandmarks?.wrist,
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
      lastScrollDirection = velocity > 0 ? .scrollUp : .scrollDown
      lastScrollDirectionTimestamp = ProcessInfo.processInfo.systemUptime
    }

    lastWristTimestamp = timestamp
  }

  private func handlePinchClick(
    landmarks: HandLandmarks,
    handScale: CGFloat,
    allowClick: Bool
  ) {
    guard allowClick else {
      isPinchActive = false
      return
    }

    guard let thumbTip = landmarks.thumbTip, let indexTip = landmarks.indexTip else {
      isPinchActive = false
      return
    }

    let distance = hypot(thumbTip.x - indexTip.x, thumbTip.y - indexTip.y) / handScale
    if isPinchActive {
      if distance >= pinchReleaseThreshold {
        isPinchActive = false
      }
      return
    }

    if distance <= pinchStartThreshold {
      isPinchActive = true
      guard Date().timeIntervalSince(lastClickTime) > clickCooldown else { return }

      let clickPoint =
        lastPointerScreenPoint
        ?? {
          if let palmPoint = palmCenter(for: landmarks) {
            return mapHandPointToScreen(point: palmPoint)
          }
          if let indexTip = landmarks.indexTip {
            return mapHandPointToScreen(point: indexTip)
          }
          return nil
        }()

      if let clickPoint {
        simulator.click(at: clickPoint)
        lastClickTime = Date()
        setOverlayOverride(.click, duration: 0.6)
      }
    }
  }

  private func palmCenter(for landmarks: HandLandmarks) -> CGPoint? {
    guard let wrist = landmarks.wrist, let middleMCP = landmarks.middleMCP else { return nil }
    return CGPoint(
      x: (wrist.x + middleMCP.x) * 0.5,
      y: (wrist.y + middleMCP.y) * 0.5
    )
  }

  private func filterParameters(for mode: PointerInputMode) -> (minCutoff: Double, beta: Double) {
    switch mode {
    case .hand:
      let clamped = min(max(pointerSmoothing, 1), 20)
      let t = Double(clamped - 1) / 19.0
      let minCutoff = pointerMaxCutoff - t * (pointerMaxCutoff - pointerMinCutoff)
      let beta = pointerMaxBeta - t * (pointerMaxBeta - pointerMinBeta)
      return (minCutoff, beta)
    case .eye:
      return (eyePointerMinCutoff, eyePointerBeta)
    }
  }

  private func smooth(point: CGPoint, timestamp: TimeInterval, mode: PointerInputMode) -> CGPoint {
    let params = filterParameters(for: mode)
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
    let deadzone: CGFloat

    switch mode {
    case .hand:
      deadzone = pointerDeadzone / max(sensitivity, 0.1)
    case .eye:
      deadzone = eyePointerDeadzone
    }

    if distance < deadzone {
      return lastPoint
    }

    lastSmoothedPoint = filteredPoint
    return filteredPoint
  }

  private func mapHandPointToScreen(point: CGPoint) -> CGPoint {
    let activeRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    let normalizedX = (point.x - activeRect.minX) / activeRect.width
    let normalizedY = (point.y - activeRect.minY) / activeRect.height

    let scaledX = (normalizedX - 0.5) * sensitivity + 0.5
    let scaledY = (normalizedY - 0.5) * sensitivity + 0.5

    let clampedX = min(max(scaledX, 0), 1)
    let clampedY = min(max(scaledY, 0), 1)

    let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
    return CGPoint(
      x: (1 - clampedX) * screenFrame.width,
      y: (1 - clampedY) * screenFrame.height
    )
  }

  private func mapNormalizedScreenPointToScreen(_ point: CGPoint) -> CGPoint {
    let clampedX = min(max(point.x, 0), 1)
    let clampedY = min(max(point.y, 0), 1)
    let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
    return CGPoint(
      x: clampedX * screenFrame.width,
      y: clampedY * screenFrame.height
    )
  }

  private func limitPointerStep(to targetPoint: CGPoint, maxDistance: CGFloat) -> CGPoint {
    guard let lastPointerScreenPoint else { return targetPoint }

    let dx = targetPoint.x - lastPointerScreenPoint.x
    let dy = targetPoint.y - lastPointerScreenPoint.y
    let distance = hypot(dx, dy)
    guard distance > maxDistance, distance > 0 else { return targetPoint }

    let scale = maxDistance / distance
    return CGPoint(
      x: lastPointerScreenPoint.x + dx * scale,
      y: lastPointerScreenPoint.y + dy * scale
    )
  }

  private func shouldMovePointer(to point: CGPoint, minimumDistance: CGFloat) -> Bool {
    guard let lastPointerScreenPoint else { return true }
    return hypot(point.x - lastPointerScreenPoint.x, point.y - lastPointerScreenPoint.y)
      >= minimumDistance
  }

  private func resetPointerTracking() {
    lastPointerScreenPoint = nil
    lastSmoothedPoint = nil
    lastWristTimestamp = nil
    lastEyeTimestamp = nil
    pointerFilterX.reset()
    pointerFilterY.reset()
  }

  private func handleMissingHand() {
    lastLandmarks = nil
    lastWristTimestamp = nil
    currentState = .unknown
    pendingState = .unknown
    stateConfidenceCounter = 0
    clearOverlayForMissingHand()
  }

  private func handleMissingEyeObservation(timestamp: TimeInterval) {
    guard trackingMode == .eyePointer, !isEyeCalibrationActive else { return }
    guard let lastEyeTimestamp, timestamp - lastEyeTimestamp > eyeObservationTimeout else { return }
    resetPointerTracking()
  }

  private func captureCalibration(feature: EyeFeatureVector) {
    guard var session = eyeCalibrationSession else { return }

    switch session.ingest(feature) {
    case .collecting(let step, let total):
      eyeCalibrationSession = session
      publishEyeCalibrationState(
        .calibrating(step: step, total: total),
        message: "Look at each dot until it advances.",
        target: session.currentTarget,
        isActive: true
      )

    case .advanced(let step, let total, let nextTarget):
      eyeCalibrationSession = session
      publishEyeCalibrationState(
        .calibrating(step: step, total: total),
        message: "Hold steady while the next point is captured.",
        target: nextTarget,
        isActive: true
      )

    case .completed(let model):
      eyeCalibrationSession = nil
      eyeCalibrationModel = model
      saveEyeCalibration(model)
      publishEyeCalibrationState(
        .calibrated,
        message: "Eye tracking is calibrated for the selected camera.",
        target: nil,
        isActive: false
      )

    case .failed:
      eyeCalibrationSession = nil
      eyeCalibrationModel = nil
      publishEyeCalibrationState(
        .failed,
        message: "Calibration failed. Re-run the 5-point flow in steady lighting.",
        target: nil,
        isActive: false
      )
    }
  }

  private func publishEyeCalibrationState(
    _ state: EyeCalibrationState,
    message: String,
    target: CGPoint? = nil,
    isActive: Bool? = nil
  ) {
    DispatchQueue.main.async {
      self.eyeCalibrationState = state
      self.eyeCalibrationMessage = message
      self.eyeCalibrationTarget = target
      if let isActive {
        self.isEyeCalibrationActive = isActive
      }
    }
  }

  private func loadEyeCalibrationStore() -> PersistedEyeCalibrationStore {
    let defaults = UserDefaults.standard
    guard let data = defaults.data(forKey: eyeCalibrationStoreKey) else {
      return PersistedEyeCalibrationStore()
    }

    return (try? JSONDecoder().decode(PersistedEyeCalibrationStore.self, from: data))
      ?? PersistedEyeCalibrationStore()
  }

  private func saveEyeCalibration(_ model: EyeCalibrationModel) {
    guard let currentCameraDeviceID else { return }

    var store = loadEyeCalibrationStore()
    store.modelsByDevice[currentCameraDeviceID] = model

    if let data = try? JSONEncoder().encode(store) {
      UserDefaults.standard.set(data, forKey: eyeCalibrationStoreKey)
    }
  }

  private static let eyeCalibrationTargets: [CGPoint] = [
    CGPoint(x: 0.50, y: 0.50),
    CGPoint(x: 0.18, y: 0.18),
    CGPoint(x: 0.82, y: 0.18),
    CGPoint(x: 0.18, y: 0.82),
    CGPoint(x: 0.82, y: 0.82),
  ]
}
