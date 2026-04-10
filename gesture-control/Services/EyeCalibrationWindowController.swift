//
//  EyeCalibrationWindowController.swift
//  gesture-control
//
//  Created by Codex on 2026-04-04.
//

#if os(macOS)
  import AppKit
  import SwiftUI

  final class EyeCalibrationWindowController {
    private let gestureProcessor: GestureProcessor
    private var window: NSWindow?

    init(gestureProcessor: GestureProcessor) {
      self.gestureProcessor = gestureProcessor
    }

    func show() {
      if window == nil {
        window = makeWindow()
      }

      updateFrame()
      window?.orderFrontRegardless()
    }

    func hide() {
      window?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
      let frame = currentScreenFrame()
      let panel = NSPanel(
        contentRect: frame,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
      )

      panel.level = .statusBar
      panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
      panel.isOpaque = false
      panel.backgroundColor = .clear
      panel.hasShadow = false
      panel.hidesOnDeactivate = false
      panel.ignoresMouseEvents = true
      panel.isReleasedWhenClosed = false

      let rootView = EyeCalibrationOverlayView(gestureProcessor: gestureProcessor)
      let hostingView = NSHostingView(rootView: rootView)
      hostingView.frame = CGRect(origin: .zero, size: frame.size)
      hostingView.autoresizingMask = [.width, .height]
      panel.contentView = hostingView
      return panel
    }

    private func updateFrame() {
      let frame = currentScreenFrame()
      window?.setFrame(frame, display: true)
    }

    private func currentScreenFrame() -> CGRect {
      NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }
  }
#endif
