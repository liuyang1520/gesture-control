//
//  EyePoseDetector.swift
//  gesture-control
//
//  Created by Codex on 2026-04-04.
//

import CoreGraphics
import CoreMedia
import Foundation
import Vision
import simd

struct EyeTrackingObservation {
  let faceBounds: CGRect
  let faceCenter: CGPoint
  let leftEyeCenter: CGPoint?
  let rightEyeCenter: CGPoint?
  let leftPupil: CGPoint?
  let rightPupil: CGPoint?
  let confidence: VNConfidence

  var trackingPoint: CGPoint {
    let pupils = [leftPupil, rightPupil].compactMap { $0 }
    guard !pupils.isEmpty else { return faceCenter }

    let count = CGFloat(pupils.count)
    let sum = pupils.reduce(CGPoint.zero) { partialResult, point in
      CGPoint(x: partialResult.x + point.x, y: partialResult.y + point.y)
    }
    return CGPoint(x: sum.x / count, y: sum.y / count)
  }

  var featureVector: EyeFeatureVector? {
    let offsets = pupilOffsets
    guard !offsets.isEmpty else { return nil }

    let count = Double(offsets.count)
    let averageX = offsets.reduce(0.0) { $0 + Double($1.x) } / count
    let averageY = offsets.reduce(0.0) { $0 + Double($1.y) } / count

    return EyeFeatureVector(
      faceCenterX: Double(faceCenter.x),
      faceCenterY: Double(faceCenter.y),
      pupilOffsetX: averageX,
      pupilOffsetY: averageY
    )
  }

  private var pupilOffsets: [CGPoint] {
    let eyePairs = [(leftEyeCenter, leftPupil), (rightEyeCenter, rightPupil)]
    let scale = max(interEyeDistance ?? faceBounds.width, 0.001)

    return eyePairs.compactMap { eyeCenter, pupil in
      guard let eyeCenter, let pupil else { return nil }
      return CGPoint(
        x: (pupil.x - eyeCenter.x) / scale,
        y: (pupil.y - eyeCenter.y) / scale
      )
    }
  }

  private var interEyeDistance: CGFloat? {
    guard let leftEyeCenter, let rightEyeCenter else { return nil }
    return hypot(leftEyeCenter.x - rightEyeCenter.x, leftEyeCenter.y - rightEyeCenter.y)
  }
}

final class EyePoseDetector {
  private let faceLandmarksRequest = VNDetectFaceLandmarksRequest()
  private let minimumConfidence: VNConfidence = 0.5

  func process(sampleBuffer: CMSampleBuffer) -> EyeTrackingObservation? {
    let handler = VNImageRequestHandler(
      cmSampleBuffer: sampleBuffer,
      orientation: .up,
      options: [:]
    )

    do {
      try handler.perform([faceLandmarksRequest])

      guard
        let observation = faceLandmarksRequest.results?
          .max(by: { weightedArea($0) < weightedArea($1) }),
        observation.confidence >= minimumConfidence,
        let landmarks = observation.landmarks
      else {
        return nil
      }

      let faceBounds = observation.boundingBox
      let leftEyeCenter = averagePoint(in: landmarks.leftEye, faceBounds: faceBounds)
      let rightEyeCenter = averagePoint(in: landmarks.rightEye, faceBounds: faceBounds)
      let leftPupil = averagePoint(in: landmarks.leftPupil, faceBounds: faceBounds)
      let rightPupil = averagePoint(in: landmarks.rightPupil, faceBounds: faceBounds)

      return EyeTrackingObservation(
        faceBounds: faceBounds,
        faceCenter: CGPoint(x: faceBounds.midX, y: faceBounds.midY),
        leftEyeCenter: leftEyeCenter,
        rightEyeCenter: rightEyeCenter,
        leftPupil: leftPupil,
        rightPupil: rightPupil,
        confidence: observation.confidence
      )
    } catch {
      print("Eye pose detection failed: \(error)")
      return nil
    }
  }

  private func weightedArea(_ observation: VNFaceObservation) -> CGFloat {
    observation.boundingBox.width * observation.boundingBox.height * CGFloat(observation.confidence)
  }

  private func averagePoint(in region: VNFaceLandmarkRegion2D?, faceBounds: CGRect) -> CGPoint? {
    guard let region, region.pointCount > 0 else { return nil }

    var totalX: CGFloat = 0
    var totalY: CGFloat = 0

    for index in 0..<region.pointCount {
      let point = region.normalizedPoints[index]
      totalX += CGFloat(point.x)
      totalY += CGFloat(point.y)
    }

    let count = CGFloat(region.pointCount)
    let localPoint = CGPoint(x: totalX / count, y: totalY / count)
    return CGPoint(
      x: faceBounds.minX + localPoint.x * faceBounds.width,
      y: faceBounds.minY + localPoint.y * faceBounds.height
    )
  }
}
