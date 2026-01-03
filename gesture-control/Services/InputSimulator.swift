//
//  InputSimulator.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import Foundation
import ApplicationServices
import Cocoa

class InputSimulator {
    
    private let screenHeight = NSScreen.main?.frame.height ?? 1080
    
    func moveMouse(to point: CGPoint) {
        // CoreGraphics uses top-left as (0,0), same as our mapped coordinates usually.
        // But we must ensure the point is within screen bounds.
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        event?.post(tap: .cghidEventTap)
    }
    
    func click(at point: CGPoint) {
        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }
    
    // For Zoom, we can use Scroll Wheel with modifiers or just Scroll.
    // Pinch to Zoom usually sends Magnification events, but those are harder to simulate globally.
    // CMD + Scroll is equivalent to Zoom on macOS accessibility or App Zoom.
    func zoom(direction: CGFloat) { // + for in, - for out
        // Simulate Scroll Wheel with Control Key (Screen Zoom)
        // Or just Key Press CMD + / -
        
        // Let's try Scroll with .maskCommand (Standard App Zoom often) or .maskControl (System Zoom)
        // Using System Zoom (Control + Scroll) requires Accessibility feature enabled in OS Settings > Accessibility > Zoom.
        // Safer default: CMD + or CMD -
        
        let keyCode: CGKeyCode = direction > 0 ? 24 : 27 // 24: =, 27: -
        simulateKeyCombo(keyCode: keyCode, modifiers: .maskCommand)
    }
    
    func scroll(dx: Int32, dy: Int32) {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0)
        event?.post(tap: .cghidEventTap)
    }
    
    func navigateBack() {
        // CMD + [ (33)
        simulateKeyCombo(keyCode: 33, modifiers: .maskCommand)
    }
    
    func navigateForward() {
        // CMD + ] (30)
        simulateKeyCombo(keyCode: 30, modifiers: .maskCommand)
    }
    
    func switchApplication() {
        // CMD + TAB (48)
        // This is tricky because you need to hold CMD and tap TAB.
        // A single trigger might just open the switcher.
        // Let's try Mission Control: Control + Up Arrow (126)
        
        simulateKeyCombo(keyCode: 126, modifiers: .maskControl)
    }
    
    private func simulateKeyCombo(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        
        keyDown.flags = modifiers
        keyUp.flags = modifiers
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
