# Gesture Control for macOS

Control your Mac with simple hand gestures using the built-in camera. The app runs fully on-device: it reads camera frames, detects a single hand, and translates gestures into cursor movement, scrolling, and navigation shortcuts.

## Features

- **Pointer Control**: Move the cursor by moving your open palm.
- **Click**: Pinch your thumb and index finger to click.
- **Scroll**: Make a fist (or a two-finger V) and move your hand up/down.
- **Back/Forward**: Point your index finger left/right (other fingers closed).
- **Visual Guidance**: Optional overlay highlights the detected hand and shows the current action.
- **Tuning**: Adjust sensitivity, smoothing, and scroll speed.

## Requirements

- macOS with a camera (built-in or external).
- Accessibility permission to generate mouse/keyboard input.
- Xcode to build and run the app.

## Build and Run

1. Open `gesture-control.xcodeproj` in Xcode.
2. Select the `gesture-control` scheme.
3. Build and run.
4. When prompted, grant the required permissions (see below).

## Permissions

The app needs two system permissions:

- **Camera**: Needed to detect your hand.
- **Accessibility**: Needed to move the mouse and simulate key presses.

If input isn't working:

1. Open **System Settings > Privacy & Security > Accessibility**.
2. Enable `gesture-control` (or add the built app manually).
3. Restart the app.

## Usage Guide

1. Launch the app to open the **Dashboard**.
2. Toggle **Enable Control** to start the camera.
3. Choose a camera if you have multiple sources.
4. Use the **Calibrate / Tutorial** button for a guided walkthrough.
5. Hover or click the info icons in the settings panel for parameter tips.

### Gesture Reference

| Gesture | Action | Notes |
| --- | --- | --- |
| Open palm | Move cursor | Tracks palm center for stable clicks. |
| Pinch thumb + index | Click | Clicks at the last cursor position. |
| Fist or V sign + up/down | Scroll | Speed is adjustable. |
| Index finger left/right (others closed) | Back / Forward | Uses Command+[ and Command+]. |

## Settings Explained

- **Enable Control**: Starts/stops the camera and gesture processing.
- **Camera Source**: Selects which camera feed to use.
- **Sensitivity**: Higher values move the cursor farther per hand movement.
- **Scroll Speed**: Scales scroll velocity while using the scroll gesture.
- **Smoothing (Stability)**: Higher values reduce jitter at the cost of latency.

## Visual Guidance Overlay

When control is enabled, the preview can show:

- A highlighted hand region (bounding shape).
- A small marker for the tracked point.
- A label for the detected gesture (Move, Scroll Up/Down, Back, Forward, Click).

This overlay helps you understand what the detector is seeing in real time.

## Tips for Better Tracking

- Keep your hand centered in the frame.
- Use even lighting and avoid strong backlight.
- Keep your wrist and palm visible for stable tracking.
- Increase **Smoothing** if the cursor jitters; lower it if it feels sluggish.

## Troubleshooting

- **Camera is black or "Camera Off"**: Check camera permissions in System Settings.
- **Cursor doesn't move**: Ensure Accessibility permissions are granted.
- **Click happens in the wrong place**: Make sure your palm is steady when pinching.
- **Back/Forward feels reversed**: Use the front camera (mirrored) for intuitive direction; external cameras may feel less natural depending on orientation.
- **Laggy or jittery cursor**: Adjust **Smoothing** and **Sensitivity**.

## Development Notes

Project structure:

- `gesture-control/Services`
  - `CameraManager`: Captures frames and manages camera state.
  - `HandPoseDetector`: Uses Vision to detect hand landmarks.
  - `GestureProcessor`: Interprets gestures and controls smoothing/latency.
  - `InputSimulator`: Sends mouse and keyboard events.
- `gesture-control/Views`: SwiftUI dashboard and preview UI.

Tests:

```sh
xcodebuild -project gesture-control.xcodeproj -scheme gesture-control -destination "platform=macOS" test -only-testing:gesture-controlTests
```

Formatting and linting (if installed):

```sh
xcrun swift-format format --in-place --recursive gesture-control
xcrun swift-format lint --recursive gesture-control
```

## Release Automation

Use the release helper script to bump versions and optionally build/tag:

```sh
scripts/release.sh 0.1.0 --build 1
```

Release builds should be signed with a Developer ID identity; use `--sign-id` (and optionally `--notarize`). For local testing, pass `--unsigned`.

Build and zip a macOS app (unsigned, local only):

```sh
scripts/release.sh 0.1.0 --build 1 --build-app --unsigned
```

If Gatekeeper blocks the unsigned app, remove quarantine from the app bundle only:

```sh
xattr -dr com.apple.quarantine /path/to/gesture-control.app
```

Build, sign, and notarize a macOS app for release:

```sh
scripts/release.sh 0.1.0 --build 1 --build-app --sign-id "Developer ID Application: Your Name (TEAMID)" --notarize --notary-profile "gesture-control-notary"
```

Create the `--notary-profile` with `xcrun notarytool store-credentials`, or set `NOTARY_PROFILE` to a stored profile name.

Create a tag/commit and push:

```sh
scripts/release.sh 0.1.0 --build 1 --push
```

## Privacy

All processing runs locally on your Mac. Camera frames are analyzed in memory and are not sent to any external service.

## Known Limitations

- Single-hand detection only.
- Cursor mapping uses the main display.
- Performance may degrade in low light or with busy backgrounds.
