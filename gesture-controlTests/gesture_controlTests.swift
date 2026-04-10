//
//  gesture_controlTests.swift
//  gesture-controlTests
//
//  Created by Marvin on 2025-12-06.
//

import CoreGraphics
import Testing

@testable import gesture_control

struct GestureControlTests {
  @Test func detectStatePointer() async throws {
    let landmarks = makeLandmarks(
      indexOpen: true,
      middleOpen: true,
      ringOpen: true,
      littleOpen: true,
      thumbTip: CGPoint(x: 0.55, y: 0.2)
    )
    #expect(GestureProcessor.detectState(for: landmarks) == .pointer)
  }

  @Test func detectStateFist() async throws {
    let landmarks = makeLandmarks(
      indexOpen: false,
      middleOpen: false,
      ringOpen: false,
      littleOpen: false,
      thumbTip: CGPoint(x: 0.55, y: 0.2)
    )
    #expect(GestureProcessor.detectState(for: landmarks) == .fist)
  }

  @Test func detectStateImageLeftMapsToIndexRight() async throws {
    let landmarks = makeLandmarks(
      indexOpen: true,
      middleOpen: false,
      ringOpen: false,
      littleOpen: false,
      indexTipOverride: CGPoint(x: 0.2, y: 0.3),
      indexPIPOverride: CGPoint(x: 0.42, y: 0.26)
    )
    #expect(GestureProcessor.detectState(for: landmarks) == .indexRight)
  }

  @Test func detectStateImageRightMapsToIndexLeft() async throws {
    let landmarks = makeLandmarks(
      indexOpen: true,
      middleOpen: false,
      ringOpen: false,
      littleOpen: false,
      indexTipOverride: CGPoint(x: 0.8, y: 0.3),
      indexPIPOverride: CGPoint(x: 0.58, y: 0.26)
    )
    #expect(GestureProcessor.detectState(for: landmarks) == .indexLeft)
  }

  @Test func detectStateScroll() async throws {
    let landmarks = makeLandmarks(
      indexOpen: true,
      middleOpen: true,
      ringOpen: false,
      littleOpen: false,
      thumbTip: CGPoint(x: 0.55, y: 0.2)
    )
    #expect(GestureProcessor.detectState(for: landmarks) == .scroll)
  }

  @Test func detectStateMissingReferencePoints() async throws {
    let landmarks = HandLandmarks(
      thumbTip: nil,
      indexTip: nil,
      middleTip: nil,
      ringTip: nil,
      littleTip: nil,
      indexPIP: nil,
      middlePIP: nil,
      ringPIP: nil,
      littlePIP: nil,
      wrist: nil,
      middleMCP: nil
    )
    #expect(GestureProcessor.detectState(for: landmarks) == nil)
  }

  @Test func detectStateNilWhenMiddleMCPMissing() async throws {
    let landmarks = HandLandmarks(
      thumbTip: CGPoint(x: 0.55, y: 0.2),
      indexTip: CGPoint(x: 0.45, y: 0.45),
      middleTip: CGPoint(x: 0.5, y: 0.45),
      ringTip: CGPoint(x: 0.55, y: 0.45),
      littleTip: CGPoint(x: 0.6, y: 0.45),
      indexPIP: CGPoint(x: 0.45, y: 0.25),
      middlePIP: CGPoint(x: 0.5, y: 0.25),
      ringPIP: CGPoint(x: 0.55, y: 0.25),
      littlePIP: CGPoint(x: 0.6, y: 0.25),
      wrist: CGPoint(x: 0.5, y: 0.2),
      middleMCP: nil
    )
    #expect(GestureProcessor.detectState(for: landmarks) == nil)
  }

  @Test func detectStateUnknownWhenIndexGestureIsTooVertical() async throws {
    let landmarks = makeLandmarks(
      indexOpen: true,
      middleOpen: false,
      ringOpen: false,
      littleOpen: false,
      indexTipOverride: CGPoint(x: 0.46, y: 0.45),
      indexPIPOverride: CGPoint(x: 0.45, y: 0.28)
    )
    #expect(GestureProcessor.detectState(for: landmarks) == .unknown)
  }

  @Test func detectStateUnknownWhenIndexGestureDoesNotClearThreshold() async throws {
    let landmarks = makeLandmarks(
      indexOpen: true,
      middleOpen: false,
      ringOpen: false,
      littleOpen: false,
      indexTipOverride: CGPoint(x: 0.53, y: 0.33),
      indexPIPOverride: CGPoint(x: 0.5, y: 0.24)
    )
    #expect(GestureProcessor.detectState(for: landmarks) == .unknown)
  }

  @Test func detectStateUnknownWhenHandScaleIsZero() async throws {
    let landmarks = makeLandmarks(
      indexOpen: true,
      middleOpen: true,
      ringOpen: true,
      littleOpen: true,
      wrist: CGPoint(x: 0.5, y: 0.2),
      middleMCP: CGPoint(x: 0.5, y: 0.2)
    )
    #expect(GestureProcessor.detectState(for: landmarks) == .unknown)
  }

  @Test func detectStateUnknownForUnsupportedThreeFingerPose() async throws {
    let landmarks = makeLandmarks(
      indexOpen: true,
      middleOpen: true,
      ringOpen: true,
      littleOpen: false
    )
    #expect(GestureProcessor.detectState(for: landmarks) == .unknown)
  }

  @Test func eyeCalibrationModelFitsLinearMapping() async throws {
    let samples = eyeCalibrationTrainingVectors.map { feature in
      EyeCalibrationSample(feature: feature, target: expectedCalibrationTarget(for: feature))
    }

    let model = try #require(EyeCalibrationModel.fit(samples: samples))
    let probe = EyeFeatureVector(
      faceCenterX: 0.51,
      faceCenterY: 0.41,
      pupilOffsetX: 0.02,
      pupilOffsetY: -0.03
    )
    let mappedPoint = model.map(feature: probe)
    let expectedPoint = expectedCalibrationTarget(for: probe)

    #expect(abs(mappedPoint.x - expectedPoint.x) < 0.0001)
    #expect(abs(mappedPoint.y - expectedPoint.y) < 0.0001)
  }

  @Test func eyeCalibrationModelNeedsFiveSamples() async throws {
    let samples = Array(
      eyeCalibrationTrainingVectors.prefix(4).map { feature in
        EyeCalibrationSample(feature: feature, target: expectedCalibrationTarget(for: feature))
      }
    )
    #expect(EyeCalibrationModel.fit(samples: samples) == nil)
  }
}

private func makeLandmarks(
  indexOpen: Bool,
  middleOpen: Bool,
  ringOpen: Bool,
  littleOpen: Bool,
  thumbTip: CGPoint = CGPoint(x: 0.55, y: 0.2),
  wrist: CGPoint = CGPoint(x: 0.5, y: 0.2),
  middleMCP: CGPoint = CGPoint(x: 0.5, y: 0.3),
  indexTipOverride: CGPoint? = nil,
  indexPIPOverride: CGPoint? = nil
) -> HandLandmarks {
  func fingerPoints(open: Bool, baseX: CGFloat) -> (CGPoint, CGPoint) {
    if open {
      return (CGPoint(x: baseX, y: 0.45), CGPoint(x: baseX, y: 0.25))
    }
    return (CGPoint(x: baseX, y: 0.23), CGPoint(x: baseX, y: 0.25))
  }

  let (defaultIndexTip, defaultIndexPIP) = fingerPoints(open: indexOpen, baseX: 0.45)
  let indexTip = indexTipOverride ?? defaultIndexTip
  let indexPIP = indexPIPOverride ?? defaultIndexPIP
  let (middleTip, middlePIP) = fingerPoints(open: middleOpen, baseX: 0.5)
  let (ringTip, ringPIP) = fingerPoints(open: ringOpen, baseX: 0.55)
  let (littleTip, littlePIP) = fingerPoints(open: littleOpen, baseX: 0.6)

  return HandLandmarks(
    thumbTip: thumbTip,
    indexTip: indexTip,
    middleTip: middleTip,
    ringTip: ringTip,
    littleTip: littleTip,
    indexPIP: indexPIP,
    middlePIP: middlePIP,
    ringPIP: ringPIP,
    littlePIP: littlePIP,
    wrist: wrist,
    middleMCP: middleMCP
  )
}

private let eyeCalibrationTrainingVectors: [EyeFeatureVector] = [
  EyeFeatureVector(faceCenterX: 0.40, faceCenterY: 0.45, pupilOffsetX: -0.05, pupilOffsetY: 0.02),
  EyeFeatureVector(faceCenterX: 0.55, faceCenterY: 0.35, pupilOffsetX: 0.04, pupilOffsetY: -0.01),
  EyeFeatureVector(faceCenterX: 0.62, faceCenterY: 0.58, pupilOffsetX: 0.03, pupilOffsetY: 0.05),
  EyeFeatureVector(faceCenterX: 0.35, faceCenterY: 0.68, pupilOffsetX: -0.04, pupilOffsetY: -0.03),
  EyeFeatureVector(faceCenterX: 0.48, faceCenterY: 0.52, pupilOffsetX: 0.01, pupilOffsetY: -0.04),
]

private func expectedCalibrationTarget(for feature: EyeFeatureVector) -> CGPoint {
  let x =
    0.05
    + 0.42 * feature.faceCenterX
    + 0.18 * feature.faceCenterY
    + 0.75 * feature.pupilOffsetX
    - 0.12 * feature.pupilOffsetY
  let y =
    0.08
    + 0.15 * feature.faceCenterX
    + 0.56 * feature.faceCenterY
    - 0.10 * feature.pupilOffsetX
    + 0.62 * feature.pupilOffsetY

  return CGPoint(x: x, y: y)
}
