# Google Play Store Submission Checklist

## Pre-submission (Development/Android Studio)

- [ ] Ensure `pubspec.yaml` (if Flutter) or `build.gradle` has `versionName` and `versionCode` incremented.
- [ ] Build the App Bundle (`.aab` file). E.g., `flutter build appbundle`.

## Google Play Console (Store Listing)

- [ ] Navigate to **Main store listing**.
- [ ] Update **Release Notes** (`<en-US>` tags).
- [ ] Ensure **Screenshots** and **Feature Graphic** are up to date.
- [ ] Check **Data safety** to ensure it aligns with any new data collection.

## Release Management

- [ ] Go to **Production** (or Open/Closed Testing).
- [ ] Click **Create new release**.
- [ ] Upload the App Bundle (`.aab`).
- [ ] Give the release a name (internal identifier).
- [ ] Add the Release Notes.
- [ ] Review release details.

## Rollout

- [ ] Decide on rollout percentage (Staged rollout e.g., 20% first to catch crashes, or 100% immediately).
- [ ] Click **Save**, then **Review release**.
- [ ] Check for any warnings or errors.
- [ ] Click **Start rollout to Production**.
