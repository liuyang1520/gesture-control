//
//  AppController.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import Combine
import Foundation

@MainActor
final class AppController: ObservableObject {
  let cameraManager = CameraManager()
  let gestureProcessor = GestureProcessor()

  private var cancellables = Set<AnyCancellable>()
  #if os(macOS)
    private var floatingPreviewController: FloatingPreviewWindowController?
    private var eyeCalibrationController: EyeCalibrationWindowController?
  #endif

  init() {
    cameraManager.delegate = gestureProcessor

    cameraManager.$selectedDeviceId
      .removeDuplicates()
      .sink { [weak self] selectedDeviceId in
        self?.gestureProcessor.updateCurrentCameraDevice(id: selectedDeviceId)
      }
      .store(in: &cancellables)

    gestureProcessor.$isEnabled
      .removeDuplicates()
      .sink { [weak self] isEnabled in
        guard let self else { return }
        if isEnabled {
          self.cameraManager.start()
        } else {
          self.cameraManager.stop()
          self.gestureProcessor.resetState()
        }
      }
      .store(in: &cancellables)

    #if os(macOS)
      gestureProcessor.$isEnabled
        .combineLatest(gestureProcessor.$isFloatingPreviewEnabled)
        .map { $0 && $1 }
        .receive(on: DispatchQueue.main)
        .removeDuplicates()
        .sink { [weak self] shouldShow in
          guard let self else { return }
          if shouldShow {
            self.showFloatingPreview()
          } else {
            self.hideFloatingPreview()
          }
        }
        .store(in: &cancellables)

      gestureProcessor.$isEyeCalibrationActive
        .receive(on: DispatchQueue.main)
        .removeDuplicates()
        .sink { [weak self] isActive in
          guard let self else { return }
          if isActive {
            self.showEyeCalibrationOverlay()
          } else {
            self.hideEyeCalibrationOverlay()
          }
        }
        .store(in: &cancellables)
    #endif
  }

  #if os(macOS)
    private func showFloatingPreview() {
      if floatingPreviewController == nil {
        floatingPreviewController = FloatingPreviewWindowController(
          cameraManager: cameraManager,
          gestureProcessor: gestureProcessor
        )
      }
      floatingPreviewController?.show()
    }

    private func hideFloatingPreview() {
      floatingPreviewController?.hide()
    }

    private func showEyeCalibrationOverlay() {
      if eyeCalibrationController == nil {
        eyeCalibrationController = EyeCalibrationWindowController(
          gestureProcessor: gestureProcessor
        )
      }
      eyeCalibrationController?.show()
    }

    private func hideEyeCalibrationOverlay() {
      eyeCalibrationController?.hide()
    }
  #endif
}
