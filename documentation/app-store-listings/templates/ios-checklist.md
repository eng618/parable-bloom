# Apple App Store Submission Checklist

## Pre-submission (Development/Xcode)

- [ ] Ensure `Info.plist` has `CFBundleShortVersionString` (version) and `CFBundleVersion` (build number) incremented.
- [ ] If new permissions are added, ensure corresponding `NS...UsageDescription` keys are in `Info.plist`.
- [ ] Create an Archive in Xcode.
- [ ] Validate and Distribute the app to App Store Connect.

## App Store Connect (TestFlight)

- [ ] Select the new build in TestFlight.
- [ ] Provide compliance information (Export Compliance: Does the app use encryption?).
- [ ] Verify the build works for internal/external testers.

## App Store Connect (Store Listing)

- [ ] Create a new Version in App Store Connect.
- [ ] Update **What's New in This Version**.
- [ ] Update **Promotional Text** (if applicable).
- [ ] Ensure **Screenshots** are up to date (or carry over from the previous version).
- [ ] Verify **App Privacy** nutrition labels are still accurate.
- [ ] Select the correct Build for this version.

## Review Submission

- [ ] Review App Review Information (Contact info, demo account credentials if required).
- [ ] Choose release method (Manually release, Automatically release, Automatically release after date).
- [ ] Click **Submit for Review**.
