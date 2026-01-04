//
//  HandPoseDetector.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import Vision

struct HandLandmarks {
  // Tips
  let thumbTip: CGPoint?
  let indexTip: CGPoint?
  let middleTip: CGPoint?
  let ringTip: CGPoint?
  let littleTip: CGPoint?

  // PIP Joints (Proximal Interphalangeal - for finger closure check)
  let indexPIP: CGPoint?
  let middlePIP: CGPoint?
  let ringPIP: CGPoint?
  let littlePIP: CGPoint?

  // Reference (for scale)
  let wrist: CGPoint?
  let middleMCP: CGPoint?  // Knuckle
}

class HandPoseDetector {
  private let handPoseRequest = VNDetectHumanHandPoseRequest()
  private let minimumConfidence: VNConfidence = 0.3

  init() {
    handPoseRequest.maximumHandCount = 1
  }

  func process(sampleBuffer: CMSampleBuffer) -> HandLandmarks? {
    let handler = VNImageRequestHandler(
      cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])

    do {
      try handler.perform([handPoseRequest])

      guard let observation = handPoseRequest.results?.first else { return nil }

      let points = try observation.recognizedPoints(.all)
      func point(_ joint: VNHumanHandPoseObservation.JointName) -> CGPoint? {
        guard let point = points[joint], point.confidence >= minimumConfidence else { return nil }
        return point.location
      }

      return HandLandmarks(
        thumbTip: point(.thumbTip),
        indexTip: point(.indexTip),
        middleTip: point(.middleTip),
        ringTip: point(.ringTip),
        littleTip: point(.littleTip),

        indexPIP: point(.indexPIP),
        middlePIP: point(.middlePIP),
        ringPIP: point(.ringPIP),
        littlePIP: point(.littlePIP),

        wrist: point(.wrist),
        middleMCP: point(.middleMCP)
      )

    } catch {
      print("Hand pose detection failed: \(error)")
      return nil
    }
  }
}
