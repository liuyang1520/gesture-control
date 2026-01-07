//
//  DashboardView.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import SwiftUI

struct DashboardView: View {
  @ObservedObject var gestureProcessor: GestureProcessor
  @ObservedObject var cameraManager: CameraManager
  @State private var showOnboarding = false

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
              .frame(minWidth: 300, maxWidth: 340)
            preview
          }
        }
      }
      .background(Color(nsColor: .windowBackgroundColor))
    }
    .sheet(isPresented: $showOnboarding) {
      OnboardingView(isPresented: $showOnboarding)
    }
  }

  private var settingsPanel: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Gesture Control")
          .font(.title)
          .fontWeight(.bold)

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

          Picker(
            "Select Camera",
            selection: Binding(
              get: { cameraManager.selectedDeviceId ?? "" },
              set: { cameraManager.selectDevice(id: $0) }
            )
          ) {
            ForEach(cameraManager.availableDevices, id: \.uniqueID) { device in
              Text(device.localizedName).tag(device.uniqueID)
            }
          }
          .labelsHidden()
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
            value: $gestureProcessor.pointerSmoothing, in: 1...20)
        }

        Button(action: { showOnboarding = true }) {
          HStack {
            Image(systemName: "hand.raised.fill")
            Text("Calibrate / Tutorial")
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(8)
        }
        .buttonStyle(.plain)
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

      if gestureProcessor.isEnabled {
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
            .padding(8)
            .background(.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding()
        }
      } else {
        Color.black.opacity(0.6)
        Text("Camera Off")
          .foregroundColor(.white)
          .font(.headline)
      }
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
    .popover(isPresented: $isPresented, arrowEdge: .bottom) {
      Text(text)
        .font(.caption)
        .padding(12)
        .frame(width: 220, alignment: .leading)
    }
  }
}
