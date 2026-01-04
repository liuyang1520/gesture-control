//
//  gesture_controlApp.swift
//  gesture-control
//
//  Created by Marvin on 2025-12-06.
//

import SwiftUI

@main
struct GestureControlApp: App {
  @StateObject private var appController = AppController()
#if os(macOS)
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
#endif

  var body: some Scene {
    #if os(macOS)
    WindowGroup("Gesture Control", id: "main") {
      DashboardView(
        gestureProcessor: appController.gestureProcessor,
        cameraManager: appController.cameraManager
      )
    }
    #else
    WindowGroup {
      DashboardView(
        gestureProcessor: appController.gestureProcessor,
        cameraManager: appController.cameraManager
      )
    }
    #endif

#if os(macOS)
    MenuBarExtra("Gesture Control", systemImage: "hand.wave") {
      MenuBarContent(gestureProcessor: appController.gestureProcessor)
    }
#endif
  }
}
