//
//  gesture_controlApp.swift
//  gesture-control
//
//  Created by Marvin on 2025-12-06.
//

import SwiftUI

@main
struct GestureControlApp: App {
  @StateObject private var cameraManager = CameraManager()
  @StateObject private var gestureProcessor = GestureProcessor()

  var body: some Scene {
    WindowGroup {
      DashboardView(gestureProcessor: gestureProcessor, cameraManager: cameraManager)
        .onAppear {
          cameraManager.delegate = gestureProcessor
        }
    }
  }
}
