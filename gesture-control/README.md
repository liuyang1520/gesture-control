# Gesture Control for macOS

Control your Mac with simple hand gestures using the built-in camera.

## Features

- **Pointer Control**: Move your index finger to control the mouse cursor.
- **Navigation**:
    - **Swipe Left/Right** with an open palm to go Back/Forward (e.g., in Safari).
- **App Switching**:
    - **Swipe Up** with 3 fingers to open Mission Control or Switch Apps.
- **Zoom**:
    - **Pinch (Thumb + Index)** and move your hand Up/Down to Zoom In/Out.

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
    - **Move**: Point with your index finger.
    - **Click/Drag**: Pinch your index and thumb together. (Note: Basic click is implemented as Pinch, but for better experience, use the tracked cursor and click manually or use the "Pinch" gesture if enabled).
    - **Zoom**: Pinch and hold, then move your hand up or down.

## Troubleshooting

-   **Camera is Black**: Ensure you granted Camera permissions in System Settings > Privacy & Security > Camera.
-   **Mouse not moving**: Ensure `gesture-control` has Accessibility permissions. If the mouse moves but clicks don't work, check if another app is blocking it.
-   **Jittery Cursor**: Increase the "Smoothing" value in the Dashboard.
