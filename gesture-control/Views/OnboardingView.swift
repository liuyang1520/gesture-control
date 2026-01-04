//
//  OnboardingView.swift
//  gesture-control
//
//  Created by Gemini on 2025-12-06.
//

import SwiftUI

struct OnboardingView: View {
  @Binding var isPresented: Bool
  @State private var step = 0

  var body: some View {
    VStack(spacing: 30) {
      if step == 0 {
        // Intro
        Image(systemName: "hand.wave.fill")
          .font(.system(size: 60))
          .foregroundColor(.blue)
        Text("Welcome to Gesture Control")
          .font(.largeTitle)
        Text("Control your Mac with simple hand gestures.")
          .multilineTextAlignment(.center)
          .padding(.horizontal)

        Button("Get Started") {
          withAnimation { step += 1 }
        }
        .keyboardShortcut(.defaultAction)

      } else if step == 1 {
        // Permissions
        Text("Permissions Needed")
          .font(.title)

        VStack(alignment: .leading, spacing: 15) {
          HStack {
            Image(systemName: "camera.fill")
            Text("Camera Access: Required to see your hands.")
          }
          HStack {
            Image(systemName: "hand.point.up.left.fill")
            Text("Accessibility: Required to move the mouse.")
          }
        }
        .padding()

        Button("Grant Permissions") {
          // In a real app, we would deep link to System Settings
          // For now, assume user has handled it or will handle it on prompt
          withAnimation { step += 1 }
        }

      } else if step == 2 {
        // Gestures Guide
        Text("Learn Gestures")
          .font(.title)

        VStack(spacing: 24) {
          HStack(spacing: 40) {
            VStack {
              Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.largeTitle)
              Text("Move")
              Text("Open Palm")
                .font(.caption)
            }

            VStack {
              Image(systemName: "hand.tap")
                .font(.largeTitle)
              Text("Click")
              Text("Palm → Fist")
                .font(.caption)
            }
          }

          HStack(spacing: 40) {
            VStack {
              Image(systemName: "arrow.up.and.down")
                .font(.largeTitle)
              Text("Scroll")
              Text("Fist + Up/Down")
                .font(.caption)
            }

            VStack {
              Image(systemName: "arrow.left.and.right")
                .font(.largeTitle)
              Text("Back/Forward")
              Text("Thumb Left/Right")
                .font(.caption)
            }
          }
        }
        .padding()

        Button("Finish") {
          isPresented = false
        }
      }
    }
    .padding(50)
    .frame(width: 600, height: 400)
  }
}
