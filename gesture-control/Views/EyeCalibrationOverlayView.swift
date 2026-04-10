//
//  EyeCalibrationOverlayView.swift
//  gesture-control
//
//  Created by Codex on 2026-04-04.
//

import SwiftUI

struct EyeCalibrationOverlayView: View {
  @ObservedObject var gestureProcessor: GestureProcessor

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        Color.black.opacity(0.18)
          .ignoresSafeArea()

        if let target = gestureProcessor.eyeCalibrationTarget {
          calibrationTarget
            .position(
              x: target.x * proxy.size.width,
              y: target.y * proxy.size.height
            )
            .animation(.easeInOut(duration: 0.18), value: target)
        }

        VStack(spacing: 10) {
          Text(statusTitle)
            .font(.title2.weight(.semibold))
            .foregroundColor(.white)

          Text(gestureProcessor.eyeCalibrationMessage)
            .font(.body)
            .foregroundColor(.white.opacity(0.86))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(.black.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 40)
      }
      .allowsHitTesting(false)
    }
  }

  private var statusTitle: String {
    switch gestureProcessor.eyeCalibrationState {
    case .calibrating(let step, let total):
      return "Eye Calibration \(step)/\(total)"
    case .calibrated:
      return "Eye Calibration Complete"
    case .failed:
      return "Eye Calibration Failed"
    case .needsCalibration:
      return "Eye Calibration"
    }
  }

  private var calibrationTarget: some View {
    ZStack {
      Circle()
        .fill(Color.white.opacity(0.18))
        .frame(width: 92, height: 92)

      Circle()
        .stroke(Color.white.opacity(0.4), lineWidth: 2)
        .frame(width: 54, height: 54)

      Circle()
        .fill(Color.orange)
        .frame(width: 16, height: 16)
        .shadow(color: Color.orange.opacity(0.55), radius: 12)

      Rectangle()
        .fill(Color.white.opacity(0.85))
        .frame(width: 2, height: 34)

      Rectangle()
        .fill(Color.white.opacity(0.85))
        .frame(width: 34, height: 2)
    }
  }
}
