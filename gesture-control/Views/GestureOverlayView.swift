//
//  GestureOverlayView.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import SwiftUI

struct GestureOverlayView: View {
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
