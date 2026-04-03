//
//  CameraManager.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import AVFoundation
import CoreMedia
import CoreVideo

class CameraManager: NSObject, ObservableObject {
  private static var isRunningTests: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
  }

  let session = AVCaptureSession()  // Public for PreviewLayer

  @Published var availableDevices: [AVCaptureDevice] = []
  @Published var selectedDeviceId: String?
  @Published private(set) var cameraAuthorizationStatus: AVAuthorizationStatus =
    AVCaptureDevice.authorizationStatus(for: .video)
  @Published var videoAspectRatio: CGFloat = 4.0 / 3.0
  @Published var shouldMirrorPreview: Bool = true

  private let videoOutput = AVCaptureVideoDataOutput()
  private let captureQueue = DispatchQueue(label: "camera.frame.capture", qos: .userInteractive)
  private let sessionQueue = DispatchQueue(label: "camera.session")
  private let preferredFrameRate: Double = 30
  private let preferredPresets: [AVCaptureSession.Preset] = [
    .hd1280x720,
    .vga640x480,
    .medium,
  ]
  private var deviceObservers: [NSObjectProtocol] = []

  // Delegate to pass the buffer to the detector
  weak var delegate: CameraManagerDelegate?

  override init() {
    super.init()
    refreshDevices()
    observeDeviceChanges()
    checkPermissions()
  }

  deinit {
    for observer in deviceObservers {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  private func refreshDevices() {
    let discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera, .external],
      mediaType: .video,
      position: .unspecified
    )
    let devices = discoverySession.devices.sorted { lhs, rhs in
      deviceSortKey(lhs) < deviceSortKey(rhs)
    }
    self.availableDevices = devices

    if let selectedDeviceId,
      !devices.contains(where: { $0.uniqueID == selectedDeviceId })
    {
      self.selectedDeviceId = devices.first?.uniqueID
    } else if selectedDeviceId == nil {
      self.selectedDeviceId = devices.first?.uniqueID
    }
  }

  private func checkPermissions() {
    guard !Self.isRunningTests else { return }
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    DispatchQueue.main.async {
      self.cameraAuthorizationStatus = status
    }

    switch status {
    case .authorized:
      setupSession()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          self.cameraAuthorizationStatus = granted ? .authorized : .denied
        }
        if granted {
          self.setupSession()
        }
      }
    default:
      break
    }
  }

  private func setupSession() {
    let selectedId = selectedDeviceId
    let devices = availableDevices

    sessionQueue.async {
      self.session.beginConfiguration()
      self.applySessionPreset()

      // Remove existing inputs
      for input in self.session.inputs {
        self.session.removeInput(input)
      }

      // Find device
      let device: AVCaptureDevice?
      if let id = selectedId, let found = devices.first(where: { $0.uniqueID == id }) {
        device = found
      } else {
        device =
          AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
          ?? devices.first
      }

      if let videoDevice = device, let videoInput = try? AVCaptureDeviceInput(device: videoDevice) {
        if self.session.canAddInput(videoInput) {
          self.session.addInput(videoInput)
        }
        self.configureFrameRate(for: videoDevice)
        self.updateDeviceInfo(videoDevice)
      }

      // Output
      // Only add if not already added
      if !self.session.outputs.contains(self.videoOutput) {
        self.videoOutput.alwaysDiscardsLateVideoFrames = true
        self.videoOutput.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        self.videoOutput.setSampleBufferDelegate(self, queue: self.captureQueue)
        if self.session.canAddOutput(self.videoOutput) {
          self.session.addOutput(self.videoOutput)
        }
      }

      self.session.commitConfiguration()
    }
  }

  private func deviceSortKey(_ device: AVCaptureDevice) -> (Int, Int, String) {
    let positionPriority: Int
    switch device.position {
    case .front:
      positionPriority = 0
    case .unspecified:
      positionPriority = 1
    default:
      positionPriority = 2
    }

    let typePriority = device.deviceType == .builtInWideAngleCamera ? 0 : 1
    return (positionPriority, typePriority, device.localizedName)
  }

  private func observeDeviceChanges() {
    let center = NotificationCenter.default
    let queue = OperationQueue.main
    deviceObservers = [
      center.addObserver(
        forName: AVCaptureDevice.wasConnectedNotification,
        object: nil,
        queue: queue
      ) { [weak self] _ in
        self?.refreshStatus()
      },
      center.addObserver(
        forName: AVCaptureDevice.wasDisconnectedNotification,
        object: nil,
        queue: queue
      ) { [weak self] _ in
        self?.refreshStatus()
      },
    ]
  }

  func refreshStatus() {
    refreshDevices()
    checkPermissions()
  }

  private func applySessionPreset() {
    for preset in preferredPresets where session.canSetSessionPreset(preset) {
      session.sessionPreset = preset
      return
    }
  }

  private func configureFrameRate(for device: AVCaptureDevice) {
    let ranges = device.activeFormat.videoSupportedFrameRateRanges
    guard
      let range = ranges.min(by: {
        abs($0.maxFrameRate - preferredFrameRate) < abs($1.maxFrameRate - preferredFrameRate)
      })
    else { return }
    guard abs(range.minFrameRate - range.maxFrameRate) < 0.01 else { return }
    let duration = range.minFrameDuration

    do {
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }
      if device.activeVideoMinFrameDuration != duration {
        device.activeVideoMinFrameDuration = duration
      }
      if device.activeVideoMaxFrameDuration != duration {
        device.activeVideoMaxFrameDuration = duration
      }
    } catch {
    }
  }

  private func updateDeviceInfo(_ device: AVCaptureDevice) {
    let formatDescription = device.activeFormat.formatDescription
    let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
    let width = CGFloat(dimensions.width)
    let height = CGFloat(dimensions.height)
    let ratio = height > 0 ? width / height : 4.0 / 3.0
    let mirror = device.position == .front

    DispatchQueue.main.async {
      self.videoAspectRatio = ratio
      self.shouldMirrorPreview = mirror
    }
  }

  func selectDevice(id: String) {
    guard selectedDeviceId != id else { return }
    selectedDeviceId = id
    setupSession()
  }

  func start() {
    sessionQueue.async {
      if !self.session.isRunning {
        self.session.startRunning()
      }
    }
  }

  func stop() {
    sessionQueue.async {
      if self.session.isRunning {
        self.session.stopRunning()
      }
    }
  }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    // 1. Pass to delegate for processing (Vision)
    delegate?.didOutput(sampleBuffer: sampleBuffer)
    // No UI updates here.
  }
}

protocol CameraManagerDelegate: AnyObject {
  func didOutput(sampleBuffer: CMSampleBuffer)
}
