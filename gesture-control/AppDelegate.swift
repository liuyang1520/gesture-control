//
//  AppDelegate.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

#if os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var windowObservers: [NSObjectProtocol] = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    let center = NotificationCenter.default
    windowObservers.append(
      center.addObserver(
        forName: NSWindow.didBecomeKeyNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.updateActivationPolicy()
      }
    )
    windowObservers.append(
      center.addObserver(
        forName: NSWindow.willCloseNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        DispatchQueue.main.async {
          self?.updateActivationPolicy()
        }
      }
    )

    updateActivationPolicy()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      sender.windows.first?.makeKeyAndOrderFront(nil)
    }
    sender.activate(ignoringOtherApps: true)
    updateActivationPolicy()
    return true
  }

  private func updateActivationPolicy() {
    let hasVisibleWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeKey }
    let targetPolicy: NSApplication.ActivationPolicy = hasVisibleWindow ? .regular : .accessory
    if NSApp.activationPolicy() != targetPolicy {
      NSApp.setActivationPolicy(targetPolicy)
    }
  }
}
#endif
