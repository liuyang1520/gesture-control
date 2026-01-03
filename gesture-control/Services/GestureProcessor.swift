//
//  GestureProcessor.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import Foundation
import CoreGraphics
import AppKit
import CoreMedia

class GestureProcessor: ObservableObject, CameraManagerDelegate {
    
    // Dependencies
    private let detector = HandPoseDetector()
    private let simulator = InputSimulator()
    
    // Settings
    @Published var isEnabled: Bool = false
    @Published var pointerSmoothing: Int = 1 // Lower default for snappier cursor
    @Published var sensitivity: CGFloat = 2.0
    @Published var scrollSpeed: Double = 20.0 // Increased default slightly
    
    // State
    private var pointBuffer: [CGPoint] = []
    private var lastLandmarks: HandLandmarks?
    private var lastPointerScreenPoint: CGPoint?
    private var lastActionTime: Date = Date()
    private let actionCooldown: TimeInterval = 0.5
    
    // Screen Dimensions
    private let screenWidth = NSScreen.main?.frame.width ?? 1920
    private let screenHeight = NSScreen.main?.frame.height ?? 1080
    
    enum GestureState {
        case unknown
        case pointer // Open Palm
        case fist    // All Closed (Scroll)
        case thumbLeft  // Fist + Thumb Left (Back)
        case thumbRight // Fist + Thumb Right (Forward)
        case scroll  // Two Fingers (Victory) - Kept for user preference or legacy, but detecting 'Fist' for scroll now per request
    }
    
    @Published var currentState: GestureState = .unknown
    
    private var stateConfidenceCounter = 0
    private let stateConfidenceThreshold = 1 // Lowered to cut gesture-to-action latency
    private var pendingState: GestureState = .unknown
    
    // To track state transitions for Click
    private var previousState: GestureState = .unknown
    
    // Logic
    func didOutput(sampleBuffer: CMSampleBuffer) {
        guard isEnabled else { return }
        
        guard let landmarks = detector.process(sampleBuffer: sampleBuffer) else {
            DispatchQueue.main.async {
                // Signal "No Hand" to UI if needed
            }
            return
        }
        
        processGestures(landmarks: landmarks)
    }

    private func processGestures(landmarks: HandLandmarks) {
        guard let wrist = landmarks.wrist,
              let middleMCP = landmarks.middleMCP else { return }
        
        // --- 1. Robust Pose Detection (Scale Invariant) ---
        
        func dist(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
            return hypot(p1.x - p2.x, p1.y - p2.y)
        }
        
        // Scale Reference
        let handScale = dist(wrist, middleMCP)
        guard handScale > 0 else { return }
        
        func isFingerOpen(tip: CGPoint?, pip: CGPoint?) -> Bool {
            guard let tip = tip, let pip = pip else { return false }
            let tipDist = dist(tip, wrist)
            let pipDist = dist(pip, wrist)
            return tipDist > pipDist && tipDist > (handScale * 1.1) // Lowered threshold slightly
        }
        
        let indexOpen = isFingerOpen(tip: landmarks.indexTip, pip: landmarks.indexPIP)
        let middleOpen = isFingerOpen(tip: landmarks.middleTip, pip: landmarks.middlePIP)
        let ringOpen = isFingerOpen(tip: landmarks.ringTip, pip: landmarks.ringPIP)
        let littleOpen = isFingerOpen(tip: landmarks.littleTip, pip: landmarks.littlePIP)
        
        // Thumb is special. Check Tip vs IP distance to wrist? 
        // Or just use geometry.
        let thumbOpen = isFingerOpen(tip: landmarks.thumbTip, pip: landmarks.middleMCP) // Approximate pivot
        
        // Determine Raw State
        var detectedState: GestureState = .unknown
        
        let fourFingersOpen = indexOpen && middleOpen && ringOpen && littleOpen
        let fourFingersClosed = !indexOpen && !middleOpen && !ringOpen && !littleOpen
        
        if fourFingersOpen {
            detectedState = .pointer
        } else if fourFingersClosed {
            if !thumbOpen {
                // All 5 closed -> Fist -> Scroll
                detectedState = .fist
            } else {
                // 4 Closed, Thumb Open -> Directional
                if let tip = landmarks.thumbTip, let _ = landmarks.middleMCP { // Use _ to ignore unused 'ip'
                    // Compare X. Vision X is 0 (Left) to 1 (Right).
                    // Hand center X
                    let centerX = middleMCP.x
                    
                    if tip.x < centerX - 0.05 {
                        detectedState = .thumbLeft
                    } else if tip.x > centerX + 0.05 {
                        detectedState = .thumbRight
                    } else {
                        detectedState = .fist // Ambiguous, fallback to scroll
                    }
                }
            }
        } else if indexOpen && middleOpen && !ringOpen && !littleOpen {
            detectedState = .scroll // Victory Scroll (Legacy/Alternative)
        }
        
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
            handlePointerBehavior(landmarks: landmarks)
        case .fist:
            handleScrollBehavior(landmarks: landmarks) // Fist is now Scroll per user request
        case .scroll:
            handleScrollBehavior(landmarks: landmarks) // Victory is also Scroll
        default:
            break
        }
        
        lastLandmarks = landmarks
    }
    
    private func handleStateTransition(from old: GestureState, to new: GestureState, landmarks: HandLandmarks) {
        // CLICK: Palm (Pointer) -> Fist (Scroll)
        if old == .pointer && new == .fist {
            print("Click Triggered (Palm -> Fist)")
            let clickPoint = lastPointerScreenPoint ?? {
                if let indexTip = landmarks.indexTip { return mapToScreen(point: indexTip) }
                return nil
            }()
            if let clickPoint { simulator.click(at: clickPoint) }
        }
        
        // Navigation One-Shots
        // We add a cooldown to prevent rapid firing if state flutters
        if Date().timeIntervalSince(lastActionTime) > 1.0 {
            if new == .thumbLeft {
                print("Thumb Left -> Back")
                simulator.navigateBack()
                lastActionTime = Date()
            } else if new == .thumbRight {
                print("Thumb Right -> Forward")
                simulator.navigateForward()
                lastActionTime = Date()
            }
        }
    }
    
    private func handlePointerBehavior(landmarks: HandLandmarks) {
        guard let indexTip = landmarks.indexTip else { return }
        
        // Move Pointer
        let smoothedPoint = smooth(point: indexTip)
        let targetPoint = mapToScreen(point: smoothedPoint)
        lastPointerScreenPoint = targetPoint
        simulator.moveMouse(to: targetPoint)
    }
    
    private func handleScrollBehavior(landmarks: HandLandmarks) {
        // Scroll using Fist Movement (Up/Down)
        guard let wrist = landmarks.wrist else { return }
        
        if let lastWrist = lastLandmarks?.wrist {
            let dy = wrist.y - lastWrist.y
            
            if abs(dy) > 0.002 { // Lower deadzone for responsiveness
                let speed = Int32(dy * 3000.0) // Multiplier
                // Apply user preference
                let finalSpeed = Int32(Double(speed) * (scrollSpeed / 10.0))
                
                simulator.scroll(dx: 0, dy: finalSpeed)
            }
        }
    }
    
    private func smooth(point: CGPoint) -> CGPoint {
        pointBuffer.append(point)
        if pointBuffer.count > pointerSmoothing {
            pointBuffer.removeFirst()
        }
        
        let sumX = pointBuffer.reduce(0) { $0 + $1.x }
        let sumY = pointBuffer.reduce(0) { $0 + $1.y }
        let count = CGFloat(pointBuffer.count)
        
        return CGPoint(x: sumX / count, y: sumY / count)
    }
    
    private func mapToScreen(point: CGPoint) -> CGPoint {
        let activeRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        let normalizedX = (point.x - activeRect.minX) / activeRect.width
        let normalizedY = (point.y - activeRect.minY) / activeRect.height
        
        let clampedX = min(max(normalizedX, 0), 1)
        let clampedY = min(max(normalizedY, 0), 1)
        
        let screenX = (1 - clampedX) * screenWidth
        let screenY = (1 - clampedY) * screenHeight
        
        return CGPoint(x: screenX, y: screenY)
    }
}
