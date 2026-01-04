//
//  CameraPreview.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import AVFoundation
import SwiftUI

struct CameraPreview: NSViewRepresentable {
  class VideoPreviewView: NSView {
    override func makeBackingLayer() -> CALayer {
      return AVCaptureVideoPreviewLayer()
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
      return layer as! AVCaptureVideoPreviewLayer
    }

    override func layout() {
      super.layout()
      videoPreviewLayer.frame = bounds
    }
  }

  let session: AVCaptureSession
  let isMirrored: Bool

  func makeNSView(context: Context) -> VideoPreviewView {
    let view = VideoPreviewView()
    view.wantsLayer = true
    view.videoPreviewLayer.session = session
    view.videoPreviewLayer.videoGravity = .resizeAspectFill
    if let connection = view.videoPreviewLayer.connection {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = isMirrored
    }
    return view
  }

  func updateNSView(_ nsView: VideoPreviewView, context: Context) {
    if let connection = nsView.videoPreviewLayer.connection {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = isMirrored
    }
  }
}
