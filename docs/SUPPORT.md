# Support

## Contact

- Support email: liuyang1520@gmail.com
- Website: https://github.com/liuyang1520/gesture-control

## Requirements

- macOS 14.0 or later
- A built-in or external camera
- Pointer-control permission for global pointer control features

## Permissions

Gesture Control uses:

- Camera permission for hand and eye tracking
- Pointer-control permission for global pointer movement, click, scroll, and shortcut actions

## Troubleshooting

### The camera preview is blank

- Check System Settings > Privacy & Security > Camera.
- Confirm another app is not blocking camera access.
- Reopen the app after changing permission settings.

### Cursor control does not work

- Check System Settings > Privacy & Security > Accessibility.
- Make sure Gesture Control is enabled in the list.
- Reopen the app if the permission was granted while it was running.
- If needed, reset the TCC record with `tccutil reset PostEvent com.madeliciousoft.gesture-control`.

### Eye tracking feels inaccurate

- Re-run the 5-point calibration.
- Use steady lighting and avoid strong backlight.
- Keep your head position consistent while using Eye Pointer mode.

### Pointer movement feels jittery

- Increase smoothing in Hand Pointer mode.
- Use even lighting.
- Keep your hand centered and visible in the camera frame.

## Known Limitations

- Cursor mapping currently targets the main display.
- Eye pointer quality depends on webcam quality, lighting, and seating position.
- Final App Review acceptance for global pointer control still needs to be validated in App Store submission.
