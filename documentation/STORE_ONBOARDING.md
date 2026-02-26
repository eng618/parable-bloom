# App Store & Google Play Onboarding Checklist

This document tracks the required setup steps for releasing Parable Bloom on the App Store and Google Play Console, answering the standard onboarding questions.

## Google Play Console: "Set up your app"

Status: **8 of 11 complete** (as of initial setup)

### Let us know about the content of your app

- [x] **Set privacy policy**
  - **URL**: `https://parable-bloom.web.app/privacy`
- [x] **App access**
  - **Status**: All functionality is available without special access.
- [x] **Ads**
  - **Status**: No, my app does not contain ads. _(Update this if you integrate AdMob later)_
- [x] **Content rating**
  - **Status**: Completed questionnaire.
  - **Guidance**: Answer accurately based on the faith-based narrative and puzzle gameplay (likely resulting in an Everyone / PEGI 3 rating).
- [x] **Target audience**
  - **Status**: Targeted age groups selected.
  - **Guidance**: Ensure adherence to the Google Play Families Policy if selecting age groups that include children.
- [ ] **Data safety**
  - **Status**: Pending
  - **Details**:
    - **Data Collection**: The app collects usage data (Firebase Analytics) and crash logs (Firebase Crashlytics). If user accounts are added later, note that.
    - **Data Sharing**: Data is shared with Google (via Firebase) for analytics and crash reporting purposes.
    - **Data Handling**: Data is encrypted in transit. Note whether users can request data deletion (via Firebase Auth/Functions if applicable).
- [x] **Government apps**
  - **Status**: No, Parable Bloom is not a government or state-affiliated app.
- [ ] **Financial features**
  - **Status**: Pending
  - **Details**: The app does not provide any financial features (no loans, crypto, etc.).
  - **Action**: Select "My app doesn't provide any financial features".
- [x] **Health**
  - **Status**: No, my app is not a health app.

### Manage how your app is organized and presented

- [x] **Select an app category and provide contact details**
  - **Category**: Game -> Puzzle
  - **Tags**: Casual, Offline, Single player (add other relevant tags)
  - **Contact**: Provide developer support email and website.
- [ ] **Set up your store listing**
  - **Status**: Pending
  - **Assets Needed**:
    - **App Name**: Parable Bloom
    - **Short Description**: A zen hyper-casual arrow puzzle game with faith-based themes. (Max 80 chars)
    - **Full Description**: Create a compelling description of the game, features, mechanics, and story. Focus on the relaxing nature of the puzzles.
    - **App Icon**: 512x512 PNG/JPEG.
    - **Feature Graphic**: 1024x500 PNG/JPEG. (Required for featuring).
    - **Phone Screenshots**: 2-8 images showing gameplay and menus.
    - **Tablet Screenshots**: 7-inch and 10-inch screenshots (highly recommended even if not fully tablet-optimized).
    - **Video**: Optional YouTube link (recommended for games).

## App Store Connect (iOS)

_(To be completed once Apple Developer account is active)_

- [ ] **App Information**
  - Name, Subtitle, Category (Games > Puzzle).
- [ ] **Pricing and Availability**
  - Set to Free (or paid if applicable).
- [ ] **App Privacy**
  - Document data collection similarly to Google Play Data Safety (Crash Data, Performance Data, Product Interaction, etc.).
- [ ] **Store Release Version**
  - Screenshots (Required: 6.5" and 5.5" displays minimum).
  - Promotional Text (Max 170 chars).
  - Description.
  - Keywords (e.g., puzzle, zen, relaxing, faith, snake, slide).
  - Support URL.
