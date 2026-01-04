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

private struct GestureOverlayView: View {
  let action: GestureProcessor.OverlayAction
  let handBounds: CGRect?
  let handPoint: CGPoint?
  let videoAspectRatio: CGFloat
  let isMirrored: Bool

  private var shouldShowOverlay: Bool {
    action != .idle
  }

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      let videoRect = videoRect(in: size)
      let style = OverlayStyle(action: action)
      let mappedBounds = handBounds.map { mapRect($0, in: videoRect) }
      let mappedPoint = handPoint.map { mapPoint($0, in: videoRect) }

      ZStack {
        if let mappedBounds, shouldShowOverlay {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(style.color.opacity(0.18))
            .overlay(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(style.color.opacity(0.9), lineWidth: 2)
            )
            .frame(width: mappedBounds.width, height: mappedBounds.height)
            .position(x: mappedBounds.midX, y: mappedBounds.midY)
            .animation(.easeOut(duration: 0.12), value: mappedBounds)
        }

        if let mappedPoint, shouldShowOverlay {
          Circle()
            .fill(style.color)
            .frame(width: 10, height: 10)
            .shadow(color: style.color.opacity(0.5), radius: 6)
            .position(mappedPoint)
            .animation(.easeOut(duration: 0.12), value: mappedPoint)
        }

        if shouldShowOverlay {
          overlayLabel(style: style)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()
      .animation(.easeOut(duration: 0.15), value: action)
    }
  }

  private func overlayLabel(style: OverlayStyle) -> some View {
    HStack {
      Spacer()
      Label(style.title, systemImage: style.symbol)
        .font(.headline)
        .foregroundColor(style.color)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.55))
        .clipShape(Capsule())
      Spacer()
    }
    .padding(.top, 12)
  }

  private func mapPoint(_ point: CGPoint, in videoRect: CGRect) -> CGPoint {
    guard videoRect.width > 0, videoRect.height > 0 else { return .zero }
    let normalizedX = isMirrored ? 1 - point.x : point.x
    let normalizedY = 1 - point.y
    return CGPoint(
      x: videoRect.minX + normalizedX * videoRect.width,
      y: videoRect.minY + normalizedY * videoRect.height
    )
  }

  private func mapRect(_ rect: CGRect, in videoRect: CGRect) -> CGRect {
    guard videoRect.width > 0, videoRect.height > 0 else { return .zero }
    let minX = isMirrored ? 1 - rect.maxX : rect.minX
    let maxX = isMirrored ? 1 - rect.minX : rect.maxX
    let minY = 1 - rect.maxY
    let maxY = 1 - rect.minY

    return CGRect(
      x: videoRect.minX + minX * videoRect.width,
      y: videoRect.minY + minY * videoRect.height,
      width: (maxX - minX) * videoRect.width,
      height: (maxY - minY) * videoRect.height
    )
  }

  private func videoRect(in size: CGSize) -> CGRect {
    guard size.width > 0, size.height > 0 else { return .zero }
    let aspect = max(videoAspectRatio, 0.1)
    let viewAspect = size.width / size.height

    if viewAspect > aspect {
      let height = size.width / aspect
      return CGRect(
        x: 0,
        y: (size.height - height) / 2,
        width: size.width,
        height: height
      )
    }

    let width = aspect * size.height
    return CGRect(
      x: (size.width - width) / 2,
      y: 0,
      width: width,
      height: size.height
    )
  }
}

private struct OverlayStyle {
  let title: String
  let symbol: String
  let color: Color

  init(action: GestureProcessor.OverlayAction) {
    switch action {
    case .idle:
      title = "Idle"
      symbol = "hand.raised"
      color = Color.white.opacity(0.7)
    case .move:
      title = "Move"
      symbol = "arrow.up.and.down.and.arrow.left.and.right"
      color = .blue
    case .scroll:
      title = "Scroll"
      symbol = "arrow.up.and.down"
      color = .orange
    case .scrollUp:
      title = "Scroll Up"
      symbol = "arrow.up"
      color = .green
    case .scrollDown:
      title = "Scroll Down"
      symbol = "arrow.down"
      color = .red
    case .back:
      title = "Back"
      symbol = "chevron.left"
      color = .cyan
    case .forward:
      title = "Forward"
      symbol = "chevron.right"
      color = .teal
    case .click:
      title = "Click"
      symbol = "hand.tap"
      color = .yellow
    }
  }
}
