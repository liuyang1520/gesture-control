//
//  OnboardingView.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import AVFoundation
import AppKit
import SwiftUI

struct OnboardingView: View {
  @Binding var isPresented: Bool
  @State private var step = 0
  @State private var hasCameraAccess = false
  @State private var hasAccessibilityAccess = false

  var body: some View {
    VStack(spacing: 0) {
      header

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          stepContent
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(32)
      }

      Divider()

      footer
    }
    .frame(minWidth: 560, idealWidth: 640, minHeight: 460, idealHeight: 520)
    .onAppear(perform: refreshPermissionState)
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
    {
      _ in
      refreshPermissionState()
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(headerTitle)
        .font(.title.weight(.semibold))
      Text(headerDescription)
        .font(.subheadline)
        .foregroundColor(.secondary)

      ProgressView(value: Double(step + 1), total: 3)
        .controlSize(.small)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(24)
  }

  @ViewBuilder
  private var stepContent: some View {
    switch step {
    case 0:
      introStep
    case 1:
      permissionsStep
    default:
      gesturesStep
    }
  }

  private var introStep: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .center, spacing: 18) {
        Image(systemName: "hand.wave.fill")
          .font(.system(size: 46))
          .foregroundColor(.accentColor)

        VStack(alignment: .leading, spacing: 6) {
          Text("Welcome to Gesture Control")
            .font(.largeTitle.weight(.semibold))
          Text(
            "Use your camera to move the pointer, click, scroll, and navigate with a few hand gestures."
          )
          .font(.body)
          .foregroundColor(.secondary)
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        IntroBullet(
          symbol: "camera.viewfinder",
          title: "Live camera tracking",
          message: "The app reads a single camera feed and detects your hand entirely on-device."
        )
        IntroBullet(
          symbol: "cursorarrow.motionlines",
          title: "Pointer and click control",
          message: "Open palm moves the cursor, and a thumb-index pinch triggers a click."
        )
        IntroBullet(
          symbol: "arrow.up.and.down",
          title: "Scroll and navigation",
          message: "Fist motion scrolls content, and index left or right triggers back or forward."
        )
      }
    }
  }

  private var permissionsStep: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(
        "Enable the two macOS permissions below, then return to the app. Status updates automatically when the app becomes active again."
      )
      .foregroundColor(.secondary)

      PermissionCard(
        title: "Camera",
        message: "Required to detect your hand and show the live preview.",
        symbol: "camera.fill",
        isGranted: hasCameraAccess,
        buttonTitle: "Open Camera Settings",
        action: SystemSettingsNavigator.openCameraPrivacy
      )

      PermissionCard(
        title: "Accessibility",
        message: "Required to move the cursor, click, scroll, and send navigation shortcuts.",
        symbol: "hand.point.up.left.fill",
        isGranted: hasAccessibilityAccess,
        buttonTitle: "Open Accessibility Settings",
        action: SystemSettingsNavigator.openAccessibilityPrivacy
      )
    }
  }

  private var gesturesStep: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text(
        "These are the gestures the detector expects. Keep your hand centered and well lit for the most stable tracking."
      )
      .foregroundColor(.secondary)

      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 170), spacing: 16)],
        spacing: 16
      ) {
        GestureCard(
          symbol: "arrow.up.and.down.and.arrow.left.and.right",
          title: "Move",
          gesture: "Open Palm",
          tint: .blue
        )
        GestureCard(
          symbol: "hand.tap",
          title: "Click",
          gesture: "Pinch Thumb + Index",
          tint: .yellow
        )
        GestureCard(
          symbol: "arrow.up.and.down",
          title: "Scroll",
          gesture: "Fist + Up/Down",
          tint: .orange
        )
        GestureCard(
          symbol: "arrow.left.and.right",
          title: "Back / Forward",
          gesture: "Index Left / Right",
          tint: .cyan
        )
      }
    }
  }

  private var footer: some View {
    HStack {
      Button("Back") {
        withAnimation(.easeInOut(duration: 0.2)) {
          step = max(step - 1, 0)
        }
      }
      .disabled(step == 0)

      Spacer()

      Button(primaryButtonTitle) {
        advance()
      }
      .buttonStyle(.borderedProminent)
      .keyboardShortcut(.defaultAction)
    }
    .padding(24)
  }

  private var headerTitle: String {
    switch step {
    case 0:
      return "Get Set Up"
    case 1:
      return "Permissions"
    default:
      return "Gesture Guide"
    }
  }

  private var headerDescription: String {
    switch step {
    case 0:
      return "A quick walkthrough before you turn on gesture tracking."
    case 1:
      return "Gesture Control needs Camera and Accessibility access to work correctly."
    default:
      return "Review the default gestures before you start calibrating."
    }
  }

  private var primaryButtonTitle: String {
    step == 2 ? "Finish" : "Continue"
  }

  private func advance() {
    if step >= 2 {
      isPresented = false
      return
    }

    withAnimation(.easeInOut(duration: 0.2)) {
      step += 1
    }
  }

  private func refreshPermissionState() {
    hasCameraAccess = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    hasAccessibilityAccess = PermissionStatus.accessibilityGranted()
  }
}

private struct IntroBullet: View {
  let symbol: String
  let title: String
  let message: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: symbol)
        .font(.title3)
        .foregroundColor(.accentColor)
        .frame(width: 26)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        Text(message)
          .foregroundColor(.secondary)
      }
    }
  }
}

private struct PermissionCard: View {
  let title: String
  let message: String
  let symbol: String
  let isGranted: Bool
  let buttonTitle: String
  let action: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        Image(systemName: symbol)
          .font(.title2)
          .foregroundColor(.accentColor)
          .frame(width: 30)

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
          Text(message)
            .foregroundColor(.secondary)
        }

        Spacer()

        Label(
          isGranted ? "Enabled" : "Needed",
          systemImage: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        )
        .labelStyle(.titleAndIcon)
        .foregroundColor(isGranted ? .green : .orange)
      }

      Button(buttonTitle, action: action)
        .buttonStyle(.bordered)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.secondary.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

private struct GestureCard: View {
  let symbol: String
  let title: String
  let gesture: String
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Image(systemName: symbol)
        .font(.title)
        .foregroundColor(tint)

      Text(title)
        .font(.headline)

      Text(gesture)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
    .padding(16)
    .background(Color.secondary.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}
