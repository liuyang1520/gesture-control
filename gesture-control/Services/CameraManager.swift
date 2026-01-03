//
//  CameraManager.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import AVFoundation
import CoreImage
import CoreVideo
import AppKit

class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession() // Public for PreviewLayer
    
    @Published var availableDevices: [AVCaptureDevice] = []
    @Published var selectedDeviceId: String?
    
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "camera.frame.processing", qos: .userInitiated)
    
    // Delegate to pass the buffer to the detector
    weak var delegate: CameraManagerDelegate?
    
    override init() {
        super.init()
        refreshDevices()
        checkPermissions()
    }
    
    private func refreshDevices() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        self.availableDevices = discoverySession.devices
        
        // Default to first device if none selected
        if selectedDeviceId == nil, let first = availableDevices.first {
            self.selectedDeviceId = first.uniqueID
        }
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.setupSession()
                }
            }
        default:
            break
        }
    }
    
    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .medium
        
        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        
        // Find device
        let device: AVCaptureDevice?
        if let id = selectedDeviceId, let found = availableDevices.first(where: { $0.uniqueID == id }) {
            device = found
        } else {
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ?? availableDevices.first
        }
        
        if let videoDevice = device, let videoInput = try? AVCaptureDeviceInput(device: videoDevice) {
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }
        }
        
        // Output
        // Only add if not already added
        if !session.outputs.contains(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
        }
        
        session.commitConfiguration()
    }
    
    func selectDevice(id: String) {
        guard selectedDeviceId != id else { return }
        selectedDeviceId = id
        setupSession()
    }
    
    func start() {
        if !session.isRunning {
            Task {
                session.startRunning()
            }
        }
    }
    
    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 1. Pass to delegate for processing (Vision)
        delegate?.didOutput(sampleBuffer: sampleBuffer)
        // No UI updates here.
    }
}

protocol CameraManagerDelegate: AnyObject {
    func didOutput(sampleBuffer: CMSampleBuffer)
}
