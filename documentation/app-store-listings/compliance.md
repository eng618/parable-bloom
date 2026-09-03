# Compliance and Submission Guidelines

Meeting the legal and platform-specific review guidelines is essential to prevent app rejections.

## Privacy Policy

- **URL**: [https://parable-bloom.pages.dev/privacy](https://parable-bloom.pages.dev/privacy)
- **Requirements**: Both Apple and Google require a valid Privacy Policy link in the store listing metadata. This page must explicitly state what data is collected, how it is used, and who it is shared with.

## Support URL

- **Current Strategy**: While no dedicated support URL exists, a contact form or basic troubleshooting page should be added to the Parable Bloom site if users need help. Apple requires a Support URL for app submission. Using the main site or a dedicated `/support` page is acceptable.

## Data Safety & Privacy Disclosures

### Apple App Privacy (Nutrition Labels)

Apple requires you to fill out a questionnaire in App Store Connect declaring exactly what data types (e.g., Contact Info, Identifiers, Usage Data) your app collects and whether that data is linked to the user's identity or used for tracking.

### Google Play Data Safety

Google requires a similar form in the Play Console. You must accurately declare what data your app collects, if it's encrypted in transit, and if users have a way to request data deletion.

## Permissions and Plist Justifications

**Current Status**: Source code analysis indicates that Parable Bloom currently does not request specific restricted device permissions (like Camera, Location, or Contacts) via `AndroidManifest.xml` or `Info.plist`.

> [!WARNING]
> If future updates add features requiring device permissions (e.g., photo library access, camera access), you **must** include a usage description string in the iOS `Info.plist` (e.g., `NSCameraUsageDescription`) explaining *why* the app needs it. Failing to do so will result in an automatic rejection from Apple.

## App Tracking Transparency (ATT)

If the app ever incorporates third-party advertising SDKs or analytics that track users across other companies' apps and websites, you must prompt the user for permission using the ATT framework on iOS.

## Content Ratings

During submission on both platforms, you will fill out a content rating questionnaire (IARC) regarding violence, language, substance use, etc. Answer truthfully. Given the nature of Parable Bloom, it is expected to receive an "Everyone" (4+) rating.
