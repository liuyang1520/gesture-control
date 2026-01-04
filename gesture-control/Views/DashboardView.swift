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
    .onAppear {
      if gestureProcessor.isEnabled {
        cameraManager.start()
      }
    }
    .onDisappear {
      cameraManager.stop()
    }
  }

  private var settingsPanel: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Gesture Control")
          .font(.title)
          .fontWeight(.bold)

        Toggle("Enable Control", isOn: $gestureProcessor.isEnabled)
          .toggleStyle(.switch)
          .onChange(of: gestureProcessor.isEnabled) { isEnabled in
            if isEnabled {
              cameraManager.start()
            } else {
              cameraManager.stop()
              gestureProcessor.resetState()
            }
          }

        Divider()

        Group {
          Text("Camera Source")
            .font(.headline)

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

        Group {
          Text("Sensitivity")
            .font(.headline)
          Slider(value: $gestureProcessor.sensitivity, in: 0.5...3.0) {
            Text("Speed")
          }
          Text("Value: \(gestureProcessor.sensitivity, specifier: "%.1f")")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Group {
          Text("Scroll Speed")
            .font(.headline)
          Slider(value: $gestureProcessor.scrollSpeed, in: 1...50) {
            Text("Scroll Speed")
          }
          Text("Value: \(gestureProcessor.scrollSpeed, specifier: "%.0f")")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Group {
          Text("Smoothing")
            .font(.headline)
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
      }
      .padding()
    }
    .frame(maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var preview: some View {
    ZStack {
      CameraPreview(session: cameraManager.session)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()

      if gestureProcessor.isEnabled {
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
