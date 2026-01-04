# Gesture Control for macOS

Control your Mac with simple hand gestures using the built-in camera.

## Features

- **Pointer Control**: Open your palm and move your hand to control the cursor.
- **Click**: Transition from an open palm to a fist to click.
- **Scroll**: Make a fist (or a two-finger V) and move your hand up/down to scroll.
- **Navigation**: Point your index finger left/right (other fingers closed) to go Back/Forward.
- **Tuning**: Adjust sensitivity, smoothing, and scroll speed.

## Getting Started

1.  **Build and Run** the application in Xcode.
2.  **Grant Permissions**:
    - **Camera**: The app needs to see your hands. Click "OK" when prompted.
    - **Accessibility**: To move the mouse and simulate key presses, you must grant "Accessibility" permissions.
        - Go to **System Settings > Privacy & Security > Accessibility**.
        - Find "gesture-control" in the list (or add it manually from the Build folder if needed) and toggle it **ON**.
        - You might need to restart the app after granting permissions.

## Usage Guide

1.  Launch the app. You will see the **Dashboard**.
2.  Toggle **Enable Control** to start the camera.
3.  **Calibration**:
    - Click "Calibrate / Tutorial" to understand the gestures.
    - The app maps your hand position within the camera frame to the screen.
    - Active Area: The central 80% of the camera view.
4.  **Gestures**:
    - Keep your hand visible.
    - **Move**: Open palm (palm center).
    - **Click**: Open palm → fist.
    - **Scroll**: Fist (or two-finger V) + move up/down.
    - **Back/Forward**: Index left/right (other fingers closed).

## Troubleshooting

-   **Camera is Black**: Ensure you granted Camera permissions in System Settings > Privacy & Security > Camera.
-   **Mouse not moving**: Ensure `gesture-control` has Accessibility permissions. If the mouse moves but clicks don't work, check if another app is blocking it.
-   **Jittery Cursor**: Increase the "Smoothing" value in the Dashboard.
