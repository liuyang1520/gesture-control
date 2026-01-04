//
//  MenuBarContent.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

#if os(macOS)
import AppKit
import SwiftUI

struct MenuBarContent: View {
  @ObservedObject var gestureProcessor: GestureProcessor
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button("Open App") {
      NSApp.setActivationPolicy(.regular)
      if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
        window.makeKeyAndOrderFront(nil)
      } else {
        openWindow(id: "main")
      }
      NSApp.activate(ignoringOtherApps: true)
    }

    Divider()

    Toggle(
      gestureProcessor.isEnabled ? "Disable Control" : "Enable Control",
      isOn: $gestureProcessor.isEnabled
    )
    .toggleStyle(.checkbox)

    Divider()

    Button("Quit") {
      NSApp.terminate(nil)
    }
  }
}
#endif
