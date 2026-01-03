# Release Process — Parable Bloom

Comprehensive guide for automating Android/iOS releases with Bitwarden Secrets Manager, automated versioning, changelog generation, and Fastlane store uploads.

## Overview

Parable Bloom uses a fully automated release pipeline that:

- ✅ Manages secrets via Bitwarden Secrets Manager (BWS)
- ✅ Auto-increments versions in `pubspec.yaml`
- ✅ Generates changelog from git commits
- ✅ Builds signed Android `.aab` and iOS `.ipa` files
- ✅ Creates GitHub releases with artifacts
- ✅ Auto-uploads to Google Play Console and TestFlight via Fastlane

**Trigger**: Push git tag matching `v*` pattern (e.g., `v1.0.0`, `v1.2.3-beta`)

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Bitwarden Secrets Manager Setup](#bitwarden-secrets-manager-setup)
3. [Android Signing Setup](#android-signing-setup)
4. [iOS Signing Setup](#ios-signing-setup)
5. [Fastlane Configuration](#fastlane-configuration)
6. [Version Management](#version-management)
7. [Changelog Automation](#changelog-automation)
8. [Release Workflow](#release-workflow)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

- [ ] **Flutter SDK** 3.24+ with Dart 3.0+
- [ ] **Task** (go-task) — `brew install go-task/tap/go-task`
- [ ] **BWS CLI** — Bitwarden Secrets Manager CLI
- [ ] **Firebase CLI** — `npm install -g firebase-tools`
- [ ] **FlutterFire CLI** — `dart pub global activate flutterfire_cli`
- [ ] **Fastlane** — `brew install fastlane` or `gem install fastlane`

### Installation: BWS CLI

```bash
# macOS (Homebrew)
brew install bitwarden/tap/bws

# or download from GitHub
curl -LO https://github.com/bitwarden/sdk/releases/latest/download/bws-x86_64-apple-darwin.zip
unzip bws-x86_64-apple-darwin.zip
sudo mv bws /usr/local/bin/
chmod +x /usr/local/bin/bws
```

Verify installation:

```bash
bws --version
```

### BWS Authentication

1. **Log into Bitwarden Web Vault**: <https://vault.bitwarden.com>
2. **Navigate to**: Organizations → Parable Bloom → Secrets Manager
3. **Create Machine Account**: Settings → Machine Accounts → New Machine Account
4. **Generate Access Token**: Copy the `BWS_ACCESS_TOKEN`
5. **Set environment variable**:

   ```bash
   export BWS_ACCESS_TOKEN="<your-token>"
   echo 'export BWS_ACCESS_TOKEN="<your-token>"' >> ~/.zshrc
   ```

Test access:

```bash
bws secret list
```

---

## Bitwarden Secrets Manager Setup

### Required Secrets

#### Firebase

- [x] `FIREBASE_CI_TOKEN` — Already configured

#### Android Signing (4 secrets)

- [ ] `PARABLE_BLOOM_ANDROID_KEYSTORE` — Base64-encoded `.jks` keystore file
- [ ] `PARABLE_BLOOM_ANDROID_KEY_ALIAS` — Keystore alias (e.g., `upload`)
- [ ] `PARABLE_BLOOM_ANDROID_KEY_PASSWORD` — Private key password
- [ ] `PARABLE_BLOOM_ANDROID_STORE_PASSWORD` — Keystore password

#### iOS Signing (5 secrets)

- [ ] `PARABLE_BLOOM_IOS_CERTIFICATE_P12` — Base64-encoded distribution certificate
- [ ] `PARABLE_BLOOM_IOS_CERTIFICATE_PASSWORD` — Certificate import password
- [ ] `PARABLE_BLOOM_IOS_PROVISIONING_PROFILE` — Base64-encoded provisioning profile
- [ ] `PARABLE_BLOOM_IOS_PROVISIONING_PROFILE_UUID` — Profile UUID
- [ ] `PARABLE_BLOOM_IOS_TEAM_ID` — Apple Developer Team ID

#### App Store Connect API (3 secrets)

- [ ] `PARABLE_BLOOM_APP_STORE_CONNECT_KEY_ID` — API Key ID (e.g., `ABC123DEFG`)
- [ ] `PARABLE_BLOOM_APP_STORE_CONNECT_ISSUER_ID` — Issuer ID (UUID)
- [ ] `PARABLE_BLOOM_APP_STORE_CONNECT_KEY` — Base64-encoded `.p8` API key file

#### Google Play Console API (1 secret)

- [ ] `PARABLE_BLOOM_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` — Base64-encoded service account JSON

### Creating Secrets in BWS

```bash
# Create secret
bws secret create "PARABLE_BLOOM_ANDROID_KEYSTORE" --value "<base64-string>" --project-id "<project-id>"

# Update secret
bws secret edit "PARABLE_BLOOM_ANDROID_KEYSTORE" --value "<new-value>"

# List all secrets
bws secret list

# Get secret value
bws secret get PARABLE_BLOOM_ANDROID_KEYSTORE
```

### GitHub Actions Integration

Add `BWS_ACCESS_TOKEN` as GitHub repository secret:

1. Go to: <https://github.com/eng618/parable-bloom/settings/secrets/actions>
2. **New repository secret** → Name: `BWS_ACCESS_TOKEN`, Value: `<your-token>`
3. Workflows will use `bitwarden/sm-action` to fetch secrets during builds

---

## Android Signing Setup

### Step 1: Generate Release Keystore

```bash
# Generate keystore (run once, store securely)
keytool -genkey -v \
  -keystore ~/parable-bloom-upload.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storetype JKS

# Prompts (example values):
# - Store password: <secure-password>
# - Key password: <secure-password>
# - Name: Parable Bloom
# - Organization: garciaericn.com
# - City: <your-city>
# - State: <your-state>
# - Country Code: US
```

**CRITICAL**:

- ⚠️ Back up keystore to secure location (1Password, Bitwarden file attachment)
- ⚠️ Never commit keystore to git
- ⚠️ Store passwords in Bitwarden Secrets Manager

### Step 2: Encode Keystore to Base64

```bash
base64 -i ~/parable-bloom-upload.jks | pbcopy
# Now paste into Bitwarden as PARABLE_BLOOM_ANDROID_KEYSTORE
```

### Step 3: Store Secrets in BWS

```bash
bws secret create "PARABLE_BLOOM_ANDROID_KEYSTORE" --value "$(base64 -i ~/parable-bloom-upload.jks)"
bws secret create "PARABLE_BLOOM_ANDROID_KEY_ALIAS" --value "upload"
bws secret create "PARABLE_BLOOM_ANDROID_KEY_PASSWORD" --value "<your-key-password>"
bws secret create "PARABLE_BLOOM_ANDROID_STORE_PASSWORD" --value "<your-store-password>"
```

### Step 4: Update `android/app/build.gradle.kts`

**TODO**: Add release signing configuration that reads from environment variables:

```kotlin
android {
    // ... existing config

    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("ANDROID_KEYSTORE_PATH") ?: "keystore.jks")
            storePassword = System.getenv("ANDROID_STORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Remove: signingConfig = signingConfigs.getByName("debug")
        }
    }
}
```

### Step 5: Test Local Build

```bash
# Decode keystore from BWS
bws secret get PARABLE_BLOOM_ANDROID_KEYSTORE | base64 -d > /tmp/parable-bloom.jks

# Set environment variables
export ANDROID_KEYSTORE_PATH=/tmp/parable-bloom.jks
export ANDROID_STORE_PASSWORD="$(bws secret get PARABLE_BLOOM_ANDROID_STORE_PASSWORD)"
export ANDROID_KEY_ALIAS="$(bws secret get PARABLE_BLOOM_ANDROID_KEY_ALIAS)"
export ANDROID_KEY_PASSWORD="$(bws secret get PARABLE_BLOOM_ANDROID_KEY_PASSWORD)"

# Build release bundle
flutter build appbundle --release

# Verify signing
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab

# Clean up
rm /tmp/parable-bloom.jks
```

---

## iOS Signing Setup

### Step 1: Export Distribution Certificate

**Prerequisites**: Apple Developer Program membership ($99/year)

1. **Open Xcode** → Preferences → Accounts
2. **Select Apple ID** → Manage Certificates
3. **Create**: Apple Distribution certificate (if doesn't exist)
4. **Export**: Right-click → Export → Save as `.p12` with password
5. **Store certificate** in secure location

### Step 2: Create App Store Provisioning Profile

1. **Go to**: <https://developer.apple.com/account/resources/profiles/list>
2. **Click**: + (New Profile)
3. **Select**: App Store → Continue
4. **App ID**: `com.garciaericn.parablebloom` → Continue
5. **Certificate**: Select your distribution certificate → Continue
6. **Profile Name**: `Parable Bloom App Store` → Generate
7. **Download** the `.mobileprovision` file

### Step 3: Get Provisioning Profile UUID

```bash
# Extract UUID from provisioning profile
security cms -D -i ~/Downloads/ParableBloomAppStore.mobileprovision | grep -A1 UUID | grep string | sed 's/<string>//;s/<\/string>//' | xargs
```

### Step 4: Encode and Store in BWS

```bash
# Certificate
base64 -i ~/path/to/distribution-cert.p12 | pbcopy
bws secret create "PARABLE_BLOOM_IOS_CERTIFICATE_P12" --value "$(base64 -i ~/path/to/cert.p12)"
bws secret create "PARABLE_BLOOM_IOS_CERTIFICATE_PASSWORD" --value "<your-p12-password>"

# Provisioning Profile
base64 -i ~/Downloads/ParableBloomAppStore.mobileprovision | pbcopy
bws secret create "PARABLE_BLOOM_IOS_PROVISIONING_PROFILE" --value "$(base64 -i ~/Downloads/ParableBloomAppStore.mobileprovision)"
bws secret create "PARABLE_BLOOM_IOS_PROVISIONING_PROFILE_UUID" --value "<uuid-from-step-3>"

# Team ID (find in Apple Developer portal)
bws secret create "PARABLE_BLOOM_IOS_TEAM_ID" --value "<your-team-id>"
```

### Step 5: Create App Store Connect API Key

1. **Go to**: <https://appstoreconnect.apple.com/access/api>
2. **Click**: + (Generate API Key)
3. **Name**: `Parable Bloom CI/CD`
4. **Access**: App Manager
5. **Download** the `.p8` file (only chance to download!)
6. **Note**: Key ID and Issuer ID from the page

```bash
# Store API key
base64 -i ~/Downloads/AuthKey_ABC123DEFG.p8 | pbcopy
bws secret create "PARABLE_BLOOM_APP_STORE_CONNECT_KEY" --value "$(base64 -i ~/Downloads/AuthKey_*.p8)"
bws secret create "PARABLE_BLOOM_APP_STORE_CONNECT_KEY_ID" --value "ABC123DEFG"
bws secret create "PARABLE_BLOOM_APP_STORE_CONNECT_ISSUER_ID" --value "<issuer-uuid>"
```

### Step 6: Create ExportOptions.plist

**TODO**: Create `ios/ExportOptions.plist` (will be created by automation script)

### Step 7: Update Xcode Project for Manual Signing

**TODO**: Modify `ios/Runner.xcodeproj/project.pbxproj`:

- Change `CODE_SIGN_STYLE = Automatic` → `CODE_SIGN_STYLE = Manual`
- Set `PROVISIONING_PROFILE_SPECIFIER` to profile name
- Set `DEVELOPMENT_TEAM` to Team ID

### Step 8: Test Local Build

```bash
# Install pods
cd ios && pod install && cd ..

# Build archive
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

# Check output
ls -lh build/ios/ipa/
```

---

## Fastlane Configuration

Fastlane automates store uploads, beta distributions, and metadata management.

### Android Fastlane Setup

#### Step 1: Create Google Play Service Account

1. **Go to**: <https://play.google.com/console> → Setup → API access
2. **Create service account** in Google Cloud Console
3. **Grant permissions**: Release Manager role in Play Console
4. **Create JSON key** → Download
5. **Store in BWS**:

   ```bash
   base64 -i ~/Downloads/service-account.json | pbcopy
   bws secret create "PARABLE_BLOOM_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" --value "$(base64 -i ~/Downloads/service-account.json)"
   ```

#### Step 2: Initialize Fastlane

**TODO**: Run setup and create configuration files:

```bash
cd android
fastlane init

# Select: 4. Manual setup
# Follow prompts to configure package name
```

#### Step 3: Create Fastfile

**TODO**: Create `android/fastlane/Fastfile` (will be created by automation script)

### iOS Fastlane Setup

#### Step 1: Initialize Fastlane

**TODO**: Run setup:

```bash
cd ios
fastlane init

# Select: 2. Automate beta distribution to TestFlight
# Enter Apple ID, app identifier, etc.
```

#### Step 2: Create Fastfile

**TODO**: Create `ios/fastlane/Fastfile` (will be created by automation script)

### Fastlane Plugins

**TODO**: Install required plugins:

```bash
# Android
cd android
fastlane add_plugin increment_version_code
fastlane add_plugin changelog

# iOS
cd ios
fastlane add_plugin increment_build_number
fastlane add_plugin changelog
```

---

## Version Management

Version format in `pubspec.yaml`: `MAJOR.MINOR.PATCH+BUILD_NUMBER`

- Example: `1.0.0+1` → Version 1.0.0, Build 1
- Semantic versioning: MAJOR.MINOR.PATCH
- Build number: Auto-incremented integer

### Automated Version Bumping

**TODO**: Create `scripts/bump_version.dart` that:

1. Reads current version from `pubspec.yaml`
2. Increments based on flag: `--major`, `--minor`, `--patch`, `--build`
3. Updates `pubspec.yaml` with new version
4. Updates `CHANGELOG.md` with new version section
5. Creates git commit: `chore: bump version to X.Y.Z+N`
6. Creates git tag: `vX.Y.Z`

Usage:

```bash
# Bump patch version (1.0.0+1 → 1.0.1+2)
dart run scripts/bump_version.dart --patch

# Bump minor version (1.0.1+2 → 1.1.0+3)
dart run scripts/bump_version.dart --minor

# Bump major version (1.1.0+3 → 2.0.0+4)
dart run scripts/bump_version.dart --major

# Bump build number only (1.0.0+1 → 1.0.0+2)
dart run scripts/bump_version.dart --build
```

### Manual Version Update

If you prefer manual control:

1. Edit `pubspec.yaml`:

   ```yaml
   version: 1.0.1+2
   ```

2. Update changelog:

   ```bash
   dart run scripts/update_changelog.dart
   ```

3. Commit and tag:

   ```bash
   git add pubspec.yaml CHANGELOG.md
   git commit -m "chore: bump version to 1.0.1"
   git tag v1.0.1
   git push origin develop --tags
   ```

---

## Changelog Automation

### Conventional Commits

Follow [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:

- `feat`: New feature → Minor version bump
- `fix`: Bug fix → Patch version bump
- `docs`: Documentation only
- `style`: Code style changes (formatting)
- `refactor`: Code restructuring
- `perf`: Performance improvements
- `test`: Test additions/changes
- `chore`: Build process, dependencies
- `BREAKING CHANGE`: Major version bump

**Examples**:

```bash
git commit -m "feat(game): add level unlock animation"
git commit -m "fix(vine): correct blocking state calculation"
git commit -m "docs: update release process"
git commit -m "chore: bump version to 1.2.0"
```

### Changelog Generation

**TODO**: Create `scripts/update_changelog.dart` that:

1. Reads git commits since last tag
2. Groups commits by type (Features, Fixes, etc.)
3. Generates markdown sections
4. Updates `CHANGELOG.md` with new version section
5. Preserves existing changelog history

Usage:

```bash
# Generate changelog entries for unreleased commits
dart run scripts/update_changelog.dart

# Preview without writing
dart run scripts/update_changelog.dart --dry-run
```

### CHANGELOG.md Format

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-01-15

### Added
- New level unlock animations
- Grace system for failed attempts

### Fixed
- Vine blocking state calculation
- Level progress persistence

### Changed
- Improved UI responsiveness
- Updated level difficulty curve

## [1.1.0] - 2026-01-10
...
```

---

## Release Workflow

### Local Release Process (Manual)

1. **Ensure clean working tree**:

   ```bash
   git status
   git checkout develop
   git pull origin develop
   ```

2. **Run tests and validation**:

   ```bash
   task validate
   flutter test
   ```

3. **Bump version**:

   ```bash
   dart run scripts/bump_version.dart --patch
   # This auto-generates changelog, commits, and creates tag
   ```

4. **Push to GitHub**:

   ```bash
   git push origin develop --tags
   ```

5. **Create Pull Request**: `develop` → `main`
   - Title: `Release v1.0.1`
   - Review and merge

6. **Trigger release**: Merge to `main` triggers GitHub Actions workflow

### Automated Release Process (CI/CD)

**Trigger**: Git tag pushed matching `v*` pattern

**Workflow** (`.github/workflows/release.yml`):

1. **Setup** (parallel across runners):
   - `ubuntu-latest`: Android + Linux + Web
   - `windows-latest`: Windows
   - `macos-latest`: iOS + macOS

2. **Fetch secrets from BWS**:

   ```yaml
   - name: Fetch secrets from Bitwarden
     uses: bitwarden/sm-action@v2
     with:
       access_token: ${{ secrets.BWS_ACCESS_TOKEN }}
       secrets: |
         PARABLE_BLOOM_ANDROID_KEYSTORE
         PARABLE_BLOOM_ANDROID_KEY_ALIAS
         ...
   ```

3. **Android build**:
   - Decode keystore from base64
   - Set signing environment variables
   - `flutter build appbundle --release`
   - Upload to Google Play (internal track) via Fastlane
   - Upload `.aab` to GitHub release

4. **iOS build**:
   - Import certificate to keychain
   - Install provisioning profile
   - `flutter build ipa --release`
   - Upload to TestFlight via Fastlane
   - Upload `.ipa` to GitHub release

5. **Other platforms**: Web, Linux, Windows, macOS (existing workflow)

6. **Create GitHub Release**:
   - Auto-generate release notes from commits
   - Attach all platform artifacts
   - Mark as pre-release if tag contains `-beta`, `-alpha`, etc.

### Post-Release Tasks

- [ ] **Test release builds**: Download artifacts from GitHub release, install on devices
- [ ] **Monitor crash reports**: Firebase Crashlytics, Sentry
- [ ] **Check analytics**: Firebase Analytics, user engagement
- [ ] **Update documentation**: If new features require docs updates
- [ ] **Communicate release**: Social media, Discord, email newsletter

---

## Troubleshooting

### BWS CLI Issues

**Problem**: `bws: command not found`

```bash
# Verify installation
which bws
brew reinstall bitwarden/tap/bws
```

**Problem**: `Error: Unauthorized`

```bash
# Re-authenticate
export BWS_ACCESS_TOKEN="<your-token>"
bws secret list
```

### Android Signing Issues

**Problem**: `keystore.jks not found`

- Check `ANDROID_KEYSTORE_PATH` environment variable
- Verify keystore file decoded correctly: `file /tmp/keystore.jks`

**Problem**: `Failed to sign APK`

- Verify all signing environment variables set
- Check keystore password: `keytool -list -v -keystore keystore.jks`

### iOS Signing Issues

**Problem**: `Provisioning profile doesn't match`

- Verify bundle ID: `com.garciaericn.parablebloom`
- Check provisioning profile UUID matches
- Ensure certificate is valid: `security find-identity -v -p codesigning`

**Problem**: `Code signing failed`

- Clean build: `flutter clean && cd ios && pod install`
- Check Xcode signing settings: Open `ios/Runner.xcworkspace` in Xcode

### Fastlane Issues

**Problem**: `Could not find service account JSON`

- Verify secret decoded correctly
- Check file permissions: `chmod 600 service-account.json`

**Problem**: `TestFlight upload failed`

- Verify App Store Connect API key is valid
- Check app exists in App Store Connect
- Ensure bundle version incremented

### Version Bump Issues

**Problem**: `Version already exists`

- Check git tags: `git tag -l`
- Delete tag if needed: `git tag -d v1.0.0 && git push origin :refs/tags/v1.0.0`

**Problem**: `pubspec.yaml parse error`

- Validate YAML syntax: `flutter pub get`
- Check version format: `1.0.0+1` (not `1.0.0-beta+1`)

---

## Checklist: First-Time Setup

Complete this checklist to set up the automated release pipeline:

### Prerequisites

- [ ] Install BWS CLI
- [ ] Authenticate with Bitwarden (`BWS_ACCESS_TOKEN`)
- [ ] Install Fastlane
- [ ] Have Apple Developer account (iOS)
- [ ] Have Google Play Console account (Android)

### Bitwarden Secrets

- [ ] Migrate `FIREBASE_CI_TOKEN` to BWS (already exists as GitHub secret)
- [ ] Create Android signing secrets (4)
- [ ] Create iOS signing secrets (5)
- [ ] Create App Store Connect API secrets (3)
- [ ] Create Google Play service account secret (1)
- [ ] Add `BWS_ACCESS_TOKEN` to GitHub repository secrets

### Android Setup

- [ ] Generate release keystore
- [ ] Update `android/app/build.gradle.kts` with signing config
- [ ] Test local release build
- [ ] Create Google Play service account
- [ ] Initialize Fastlane in `android/`
- [ ] Create `android/fastlane/Fastfile`

### iOS Setup

- [ ] Export distribution certificate
- [ ] Create App Store provisioning profile
- [ ] Create App Store Connect API key
- [ ] Create `ios/ExportOptions.plist`
- [ ] Update Xcode project for manual signing
- [ ] Test local release build
- [ ] Initialize Fastlane in `ios/`
- [ ] Create `ios/fastlane/Fastfile`

### Automation Scripts

- [ ] Create `scripts/bump_version.dart`
- [ ] Create `scripts/update_changelog.dart`
- [ ] Add version bump tasks to `Taskfile.yaml`
- [ ] Test version bumping locally

### GitHub Actions

- [ ] Update `.github/workflows/release.yml` with Android job
- [ ] Update `.github/workflows/release.yml` with iOS job
- [ ] Add BWS secret fetching to workflow
- [ ] Test workflow with beta release (`v1.0.0-beta.1`)

### Verification

- [ ] Create test release: `v0.0.1-test`
- [ ] Verify Android build succeeds
- [ ] Verify iOS build succeeds
- [ ] Verify Fastlane uploads work
- [ ] Verify GitHub release created with artifacts
- [ ] Test installing builds on physical devices

### Documentation

- [ ] Update `README.md` with release process link
- [ ] Document version bumping in `CONTRIBUTING.md`
- [ ] Add troubleshooting section for common issues

---

## Quick Reference

### Commands

```bash
# Version management
dart run scripts/bump_version.dart --patch
dart run scripts/bump_version.dart --minor
dart run scripts/bump_version.dart --major
dart run scripts/update_changelog.dart

# Local builds
task release:android
task release:ios

# Fastlane
cd android && fastlane deploy
cd ios && fastlane beta

# BWS secrets
bws secret list
bws secret get PARABLE_BLOOM_ANDROID_KEYSTORE
bws secret create "SECRET_NAME" --value "secret-value"
```

### File Structure

```
parable-bloom/
├── .github/
│   └── workflows/
│       └── release.yml              # Updated with Android/iOS jobs
├── android/
│   ├── app/
│   │   └── build.gradle.kts         # Updated with release signing
│   └── fastlane/
│       ├── Fastfile                 # Android Fastlane configuration
│       └── Appfile
├── ios/
│   ├── ExportOptions.plist          # iOS export configuration
│   ├── Runner.xcodeproj/            # Updated for manual signing
│   └── fastlane/
│       ├── Fastfile                 # iOS Fastlane configuration
│       └── Appfile
├── scripts/
│   ├── bump_version.dart            # Version automation
│   └── update_changelog.dart        # Changelog generation
├── docs/
│   └── RELEASE_PROCESS.md           # This file
├── CHANGELOG.md                     # Auto-generated changelog
└── Taskfile.yaml                    # Updated with release tasks
```

---

## Support

For issues with the release process:

1. Check [Troubleshooting](#troubleshooting) section
2. Review workflow logs: <https://github.com/eng618/parable-bloom/actions>
3. Contact maintainers: [CONTRIBUTING.md](../CONTRIBUTING.md)

For platform-specific issues:

- **Android**: <https://developer.android.com/studio/publish>
- **iOS**: <https://developer.apple.com/testflight/>
- **Fastlane**: <https://docs.fastlane.tools/>
- **BWS**: <https://bitwarden.com/help/secrets-manager-cli/>
