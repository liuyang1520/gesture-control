//
//  FloatingPreviewWindowController.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

#if os(macOS)
import AppKit
import SwiftUI

final class FloatingPreviewWindowController {
  private let cameraManager: CameraManager
  private let gestureProcessor: GestureProcessor
  private var window: NSWindow?

  init(cameraManager: CameraManager, gestureProcessor: GestureProcessor) {
    self.cameraManager = cameraManager
    self.gestureProcessor = gestureProcessor
  }

  func show() {
    if window == nil {
      window = makeWindow()
    }
    window?.orderFrontRegardless()
  }

  func hide() {
    window?.orderOut(nil)
  }

  private func makeWindow() -> NSWindow {
    let size = CGSize(width: 240, height: 180)
    let frame = defaultFrame(for: size)

    let panel = NSPanel(
      contentRect: frame,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.isMovableByWindowBackground = true
    panel.hidesOnDeactivate = false
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isReleasedWhenClosed = false

    let rootView = FloatingPreviewView(
      cameraManager: cameraManager,
      gestureProcessor: gestureProcessor
    )
    let hostingView = DraggableHostingView(rootView: rootView)
    hostingView.frame = CGRect(origin: .zero, size: size)
    hostingView.autoresizingMask = [.width, .height]
    panel.contentView = hostingView

    return panel
  }

  private func defaultFrame(for size: CGSize) -> CGRect {
    let inset: CGFloat = 16
    let screenFrame = NSScreen.main?.visibleFrame
      ?? CGRect(x: 0, y: 0, width: 800, height: 600)
    let origin = CGPoint(
      x: screenFrame.minX + inset,
      y: screenFrame.maxY - size.height - inset
    )
    return CGRect(origin: origin, size: size)
  }
}

private final class DraggableHostingView<Content: View>: NSHostingView<Content> {
  override var mouseDownCanMoveWindow: Bool { true }
}
#endif
