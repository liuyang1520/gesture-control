//
//  CameraPreview.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import SwiftUI
import AVFoundation

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
    
    func makeNSView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.wantsLayer = true
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateNSView(_ nsView: VideoPreviewView, context: Context) {
    }
}
