# Publishing Guide

This branch is configured as a sandbox-enabled macOS app and can be prepared for either Mac App Store submission or direct distribution.

## Supported Distribution Channel

Use one of these paths:

- Mac App Store: Archive in Xcode Organizer, validate, and submit through App Store Connect.
- Direct distribution: Use Developer ID signing plus notarization for release builds.

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

The project is now configured with App Sandbox enabled and uses the `PostEvent` permission path for global synthetic input.

What changed:

- The app entitlement file now enables `com.apple.security.app-sandbox`.
- Runtime permission checks use `CGPreflightPostEventAccess` / `CGRequestPostEventAccess`.
- The UI and docs now describe pointer-control permission rather than Accessibility trust.

Remaining validation:

- Apple’s public guidance and DTS comments suggest `PostEvent` is narrower than full Accessibility automation, but final App Review acceptance for a camera-driven global pointer-control app still has to be confirmed with a real submission.
- Treat this branch as an App Store compatibility candidate, not a guaranteed approval outcome.

## Release Checklist

- Confirm the app icon, version, and build number are correct.
- Run lint and the macOS unit test target.
- Verify camera permission messaging is user-facing and accurate.
- Verify pointer-control permission prompting and recovery after `tccutil reset PostEvent <bundle-id>`.
- Host a privacy policy page based on `docs/PRIVACY_POLICY.md`.
- Host a support page based on `docs/SUPPORT.md`.
- Capture screenshots that show the dashboard, calibration flow, and permissions guidance.
- Prepare concise release notes and a support email address.
- For direct distribution, sign and notarize the final `.app`.
- For Mac App Store, create an Archive in Xcode and submit through Organizer.

## References

- App Sandbox:
  https://developer.apple.com/documentation/security/app-sandbox
- Protecting user data with App Sandbox:
  https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox
- CGRequestPostEventAccess:
  https://developer.apple.com/documentation/coregraphics/cgrequestposteventaccess%28%29
- App Store Connect app information:
  https://developer.apple.com/help/app-store-connect/create-an-app-record/view-and-edit-app-information/
