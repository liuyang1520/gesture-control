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

  @Test func detectStateIndexLeft() async throws {
    let landmarks = makeLandmarks(
      indexOpen: true,
      middleOpen: false,
      ringOpen: false,
      littleOpen: false,
      indexTipOverride: CGPoint(x: 0.2, y: 0.3),
      indexPIPOverride: CGPoint(x: 0.42, y: 0.26)
    )
    #expect(GestureProcessor.detectState(for: landmarks) == .indexLeft)
  }

  @Test func detectStateIndexRight() async throws {
    let landmarks = makeLandmarks(
      indexOpen: true,
      middleOpen: false,
      ringOpen: false,
      littleOpen: false,
      indexTipOverride: CGPoint(x: 0.8, y: 0.3),
      indexPIPOverride: CGPoint(x: 0.58, y: 0.26)
    )
    #expect(GestureProcessor.detectState(for: landmarks) == .indexRight)
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

}

private func makeLandmarks(
  indexOpen: Bool,
  middleOpen: Bool,
  ringOpen: Bool,
  littleOpen: Bool,
  thumbTip: CGPoint = CGPoint(x: 0.55, y: 0.2),
  indexTipOverride: CGPoint? = nil,
  indexPIPOverride: CGPoint? = nil
) -> HandLandmarks {
  let wrist = CGPoint(x: 0.5, y: 0.2)
  let middleMCP = CGPoint(x: 0.5, y: 0.3)

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
