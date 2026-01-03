//
//  HandPoseDetector.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import Vision
import CoreImage

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
    let middleMCP: CGPoint? // Knuckle
}

class HandPoseDetector {
    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    
    init() {
        handPoseRequest.maximumHandCount = 1
    }
    
    func process(sampleBuffer: CMSampleBuffer) -> HandLandmarks? {
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([handPoseRequest])
            
            guard let observation = handPoseRequest.results?.first else { return nil }
            
            let points = try observation.recognizedPoints(.all)
            
            return HandLandmarks(
                thumbTip: points[.thumbTip]?.location,
                indexTip: points[.indexTip]?.location,
                middleTip: points[.middleTip]?.location,
                ringTip: points[.ringTip]?.location,
                littleTip: points[.littleTip]?.location,
                
                indexPIP: points[.indexPIP]?.location,
                middlePIP: points[.middlePIP]?.location,
                ringPIP: points[.ringPIP]?.location,
                littlePIP: points[.littlePIP]?.location,
                
                wrist: points[.wrist]?.location,
                middleMCP: points[.middleMCP]?.location
            )
            
        } catch {
            print("Hand pose detection failed: \(error)")
            return nil
        }
    }
}
