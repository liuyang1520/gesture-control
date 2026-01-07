//
//  FloatingPreviewView.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

#if os(macOS)
import SwiftUI

struct FloatingPreviewView: View {
  @ObservedObject var cameraManager: CameraManager
  @ObservedObject var gestureProcessor: GestureProcessor

  var body: some View {
    ZStack {
      CameraPreview(
        session: cameraManager.session,
        isMirrored: cameraManager.shouldMirrorPreview
      )
      .clipped()

      if gestureProcessor.isEnabled {
        GestureOverlayView(
          action: gestureProcessor.overlayAction,
          handBounds: gestureProcessor.overlayHandBounds,
          handPoint: gestureProcessor.overlayHandPoint,
          videoAspectRatio: cameraManager.videoAspectRatio,
          isMirrored: cameraManager.shouldMirrorPreview
        )
        .allowsHitTesting(false)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.black.opacity(0.2))
    )
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.white.opacity(0.25), lineWidth: 1)
    )
  }
}
#endif
