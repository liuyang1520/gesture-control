//
//  DashboardView.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import AVFoundation
import AppKit
import ApplicationServices
import SwiftUI

struct DashboardView: View {
  @ObservedObject var gestureProcessor: GestureProcessor
  @ObservedObject var cameraManager: CameraManager
  @State private var showOnboarding = false
  @State private var accessibilityGranted = PermissionStatus.accessibilityGranted()

  var body: some View {
    GeometryReader { proxy in
      let isCompact = proxy.size.width < 760
      let previewHeight = max(240, proxy.size.height * 0.45)

      Group {
        if isCompact {
          VStack(spacing: 0) {
            preview
              .frame(height: previewHeight)
            settingsPanel
              .frame(maxWidth: .infinity)
          }
        } else {
          HStack(spacing: 0) {
            settingsPanel
              .frame(minWidth: 320, maxWidth: 360)
            preview
          }
        }
      }
      .background(Color(nsColor: .windowBackgroundColor))
    }
    .sheet(isPresented: $showOnboarding) {
      OnboardingView(isPresented: $showOnboarding)
    }
    .onAppear(perform: refreshEnvironmentState)
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    {
      _ in
      refreshEnvironmentState()
    }
  }

  private var settingsPanel: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Gesture Control")
            .font(.largeTitle)
            .fontWeight(.semibold)
          Text("Tune tracking, preview, and permissions from one place.")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }

        if let cameraIssue {
          SetupCallout(notice: cameraIssue)
        }

        if let accessibilityIssue {
          SetupCallout(notice: accessibilityIssue)
        }

        HStack(spacing: 8) {
          Toggle("Enable Control", isOn: $gestureProcessor.isEnabled)
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity, alignment: .leading)
          InfoTip(text: "Starts the camera and begins interpreting gestures.")
        }

        HStack(spacing: 8) {
          Toggle("Floating Preview", isOn: $gestureProcessor.isFloatingPreviewEnabled)
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity, alignment: .leading)
          InfoTip(text: "Shows a small always-on-top camera preview for smoother tracking.")
        }

        Divider()

        VStack(alignment: .leading, spacing: 6) {
          SettingsHeader(
            title: "Camera Source",
            help: "Choose which camera feeds the gesture detector."
          )

          if cameraManager.availableDevices.isEmpty {
            Text("No cameras detected")
              .foregroundColor(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 12)
              .padding(.vertical, 10)
              .background(Color.secondary.opacity(0.08))
              .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          } else {
            Picker(
              "Select Camera",
              selection: Binding(
                get: {
                  cameraManager.selectedDeviceId
                    ?? cameraManager.availableDevices.first?.uniqueID
                    ?? ""
                },
                set: { selectedId in
                  guard !selectedId.isEmpty else { return }
                  cameraManager.selectDevice(id: selectedId)
                }
              )
            ) {
              ForEach(cameraManager.availableDevices, id: \.uniqueID) { device in
                Text(device.localizedName).tag(device.uniqueID)
              }
            }
            .labelsHidden()
            .disabled(cameraManager.cameraAuthorizationStatus != .authorized)
          }
        }

        VStack(alignment: .leading, spacing: 6) {
          SettingsHeader(
            title: "Sensitivity",
            help: "Higher values make the cursor move farther for the same hand motion."
          )
          Slider(value: $gestureProcessor.sensitivity, in: 0.5...3.0) {
            Text("Speed")
          }
          Text("Value: \(gestureProcessor.sensitivity, specifier: "%.1f")")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        VStack(alignment: .leading, spacing: 6) {
          SettingsHeader(
            title: "Scroll Speed",
            help: "Controls how fast scroll gestures move content."
          )
          Slider(value: $gestureProcessor.scrollSpeed, in: 1...50) {
            Text("Scroll Speed")
          }
          Text("Value: \(gestureProcessor.scrollSpeed, specifier: "%.0f")")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        VStack(alignment: .leading, spacing: 6) {
          SettingsHeader(
            title: "Smoothing",
            help: "Higher values smooth jitter but add a bit of lag."
          )
          Stepper(
            "Stability: \(gestureProcessor.pointerSmoothing)",
            value: $gestureProcessor.pointerSmoothing,
            in: 1...20
          )
        }

        Button(action: { showOnboarding = true }) {
          Label("Calibrate / Tutorial", systemImage: "hand.raised.fill")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .help("Walk through gesture examples and permissions.")
      }
      .padding()
    }
    .frame(maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var preview: some View {
    ZStack {
      CameraPreview(
        session: cameraManager.session,
        isMirrored: cameraManager.shouldMirrorPreview
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()

      if gestureProcessor.isEnabled, previewNotice == nil {
        GestureOverlayView(
          action: gestureProcessor.overlayAction,
          handBounds: gestureProcessor.overlayHandBounds,
          handPoint: gestureProcessor.overlayHandPoint,
          videoAspectRatio: cameraManager.videoAspectRatio,
          isMirrored: cameraManager.shouldMirrorPreview
        )
        .allowsHitTesting(false)

        VStack {
          Spacer()
          Text("Active")
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding()
        }
      }

      if let previewNotice {
        PreviewPlaceholder(notice: previewNotice)
      }
    }
  }

  private var cameraIssue: DashboardNotice? {
    switch cameraManager.cameraAuthorizationStatus {
    case .denied, .restricted:
      return DashboardNotice(
        title: "Camera access is turned off",
        message:
          "Grant camera permission in System Settings so the preview and gesture detection can start.",
        symbol: "camera.fill",
        tint: .orange,
        buttonTitle: "Open Camera Settings",
        action: SystemSettingsNavigator.openCameraPrivacy
      )
    case .notDetermined where gestureProcessor.isEnabled:
      return DashboardNotice(
        title: "Waiting for camera permission",
        message: "Approve the macOS camera prompt to start the preview.",
        symbol: "camera.aperture",
        tint: .orange
      )
    default:
      guard cameraManager.availableDevices.isEmpty else { return nil }
      return DashboardNotice(
        title: "No camera detected",
        message: "Connect or enable a camera before turning on gesture control.",
        symbol: "video.slash",
        tint: .orange
      )
    }
  }

  private var accessibilityIssue: DashboardNotice? {
    guard !accessibilityGranted else { return nil }
    return DashboardNotice(
      title: "Accessibility access is required",
      message:
        "Pointer movement, clicks, scrolling, and browser navigation stay disabled until the app is allowed in System Settings.",
      symbol: "hand.point.up.left.fill",
      tint: .orange,
      buttonTitle: "Open Accessibility Settings",
      action: SystemSettingsNavigator.openAccessibilityPrivacy
    )
  }

  private var previewNotice: DashboardNotice? {
    if !gestureProcessor.isEnabled {
      return DashboardNotice(
        title: "Camera Off",
        message: "Enable control to start the camera and gesture tracking.",
        symbol: "video.slash.fill",
        tint: .white
      )
    }

    switch cameraManager.cameraAuthorizationStatus {
    case .denied, .restricted:
      return DashboardNotice(
        title: "Camera access required",
        message: "Open System Settings and allow camera access for Gesture Control.",
        symbol: "camera.fill",
        tint: .white,
        buttonTitle: "Open Camera Settings",
        action: SystemSettingsNavigator.openCameraPrivacy
      )
    case .notDetermined:
      return DashboardNotice(
        title: "Waiting for camera access",
        message: "Approve the permission prompt to start the live preview.",
        symbol: "camera.aperture",
        tint: .white
      )
    case .authorized:
      guard cameraManager.availableDevices.isEmpty else { return nil }
      return DashboardNotice(
        title: "No camera available",
        message: "Connect or enable a camera to continue.",
        symbol: "video.slash.fill",
        tint: .white
      )
    @unknown default:
      return DashboardNotice(
        title: "Camera unavailable",
        message: "The camera could not be initialized.",
        symbol: "video.slash.fill",
        tint: .white
      )
    }
  }

  private func refreshEnvironmentState() {
    accessibilityGranted = PermissionStatus.accessibilityGranted()
    cameraManager.refreshStatus()
  }
}

private struct DashboardNotice {
  let title: String
  let message: String
  let symbol: String
  let tint: Color
  var buttonTitle: String?
  var action: (() -> Void)?
}

private struct SetupCallout: View {
  let notice: DashboardNotice

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(notice.title, systemImage: notice.symbol)
        .font(.headline)
        .foregroundColor(notice.tint)

      Text(notice.message)
        .font(.subheadline)
        .foregroundColor(.secondary)

      if let buttonTitle = notice.buttonTitle, let action = notice.action {
        Button(buttonTitle, action: action)
          .buttonStyle(.link)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(notice.tint.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(notice.tint.opacity(0.18), lineWidth: 1)
    )
  }
}

private struct PreviewPlaceholder: View {
  let notice: DashboardNotice

  var body: some View {
    ZStack {
      Color.black.opacity(0.62)

      VStack(spacing: 12) {
        Image(systemName: notice.symbol)
          .font(.system(size: 34))
          .foregroundColor(notice.tint)

        Text(notice.title)
          .font(.title3.weight(.semibold))
          .foregroundColor(.white)

        Text(notice.message)
          .font(.subheadline)
          .foregroundColor(.white.opacity(0.85))
          .multilineTextAlignment(.center)
          .frame(maxWidth: 320)

        if let buttonTitle = notice.buttonTitle, let action = notice.action {
          Button(buttonTitle, action: action)
            .buttonStyle(.borderedProminent)
        }
      }
      .padding(24)
    }
  }
}

private struct SettingsHeader: View {
  let title: String
  let help: String

  var body: some View {
    HStack(spacing: 6) {
      Text(title)
        .font(.headline)
      InfoTip(text: help)
    }
  }
}

private struct InfoTip: View {
  let text: String
  @State private var isPresented = false

  var body: some View {
    Button {
      isPresented.toggle()
    } label: {
      Image(systemName: "info.circle")
        .foregroundColor(.secondary)
    }
    .buttonStyle(.plain)
    .help(text)
    .accessibilityLabel("More information")
    .accessibilityHint(text)
    .popover(isPresented: $isPresented, arrowEdge: .bottom) {
      Text(text)
        .font(.caption)
        .padding(12)
        .frame(width: 240, alignment: .leading)
    }
  }
}

enum PermissionStatus {
  static func accessibilityGranted() -> Bool {
    AXIsProcessTrusted()
  }
}

enum SystemSettingsNavigator {
  private static let cameraPrivacyURL = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")
  private static let accessibilityPrivacyURL = URL(
    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

  static func openCameraPrivacy() {
    open(url: cameraPrivacyURL)
  }

  static func openAccessibilityPrivacy() {
    open(url: accessibilityPrivacyURL)
  }

  private static func open(url: URL?) {
    if let url, NSWorkspace.shared.open(url) {
      return
    }

    _ = NSWorkspace.shared.open(
      URL(fileURLWithPath: "/System/Applications/System Settings.app")
    )
  }
}
