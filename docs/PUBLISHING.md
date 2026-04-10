# Publishing Guide

This project is ready to polish and ship as a directly distributed macOS app.

## Supported Distribution Channel

Use Developer ID signing plus notarization for release builds.

Typical flow:

```sh
scripts/lint.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project gesture-control.xcodeproj \
  -scheme gesture-control \
  -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  test -only-testing:gesture-controlTests
scripts/release.sh 0.1.1 --build 3 --build-app --sign-id "Developer ID Application: Your Name (TEAMID)" --notarize --notary-profile "gesture-control-notary"
```

## Mac App Store Status

The current app architecture is not compatible with Mac App Store submission.

Why:

- Mac App Store macOS apps must use App Sandbox.
- Apple’s App Sandbox documentation lists "use of accessibility APIs in assistive apps" as an incompatible sandbox use case.
- This app depends on Accessibility trust plus global `CGEvent` posting to move the cursor, click, scroll, and send navigation shortcuts outside the app.

Apple references:

- App Sandbox incompatible operations:
  https://developer.apple.com/documentation/security/app_sandbox
- Diagnosing and fixing sandbox violations:
  https://developer.apple.com/documentation/security/discovering-and-diagnosing-app-sandbox-violations
- App information and required App Store Connect metadata:
  https://developer.apple.com/help/app-store-connect/create-an-app-record/view-and-edit-app-information/

## Release Checklist

- Confirm the app icon, version, and build number are correct.
- Run lint and the macOS unit test target.
- Verify camera permission messaging is user-facing and accurate.
- Host a privacy policy page based on `docs/PRIVACY_POLICY.md`.
- Host a support page based on `docs/SUPPORT.md`.
- Capture screenshots that show the dashboard, calibration flow, and permissions guidance.
- Prepare concise release notes and a support email address.
- Sign and notarize the final `.app`.

## If You Still Want Mac App Store Distribution

You will need to redesign the product around App Sandbox constraints.

Minimum scope change:

- Remove global cursor control and global synthetic input outside the app.
- Remove the requirement for Accessibility trust as a core feature.
- Re-scope interaction to an in-app experience or another sandbox-compatible feature set.
- Re-test the app with App Sandbox enabled before creating a Mac App Store-specific target or branch.
