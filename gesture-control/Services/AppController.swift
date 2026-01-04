//
//  AppController.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import Combine

@MainActor
final class AppController: ObservableObject {
  let cameraManager = CameraManager()
  let gestureProcessor = GestureProcessor()

  private var cancellables = Set<AnyCancellable>()

  init() {
    cameraManager.delegate = gestureProcessor

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
  }
}
