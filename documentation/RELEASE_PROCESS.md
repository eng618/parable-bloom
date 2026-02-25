# Release Process — Parable Bloom

Comprehensive guide for automating Android/iOS releases with Bitwarden Secrets Manager, automated versioning, changelog generation, and Fastlane store uploads.

## Overview

Parable Bloom uses a fully automated release pipeline that:

- ✅ Manages secrets via Bitwarden Secrets Manager (BWS)
- ✅ Auto-increments versions in `pubspec.yaml` (managed by Nx Release + custom hooks)
- ✅ Generates changelog from git commits (automated via Nx Release)
- ✅ Builds signed Android `.aab` for Google Play Console (orchestrated via Task/Nx)
- ✅ Builds Web (Firebase Hosting), Linux & Windows (orchestrated via Task/Nx)
- ✅ Auto-uploads Android to Google Play Console via Fastlane
- ✅ Creates automated GitHub releases via Nx Release
- ⏳ iOS support temporarily disabled (awaiting Apple Developer account setup)
- ⏳ macOS support temporarily disabled (build issues to resolve later)

**Trigger**: Git tag matching `v*` pattern (e.g., `v1.0.0+1`, `v1.2.3-beta+5`). Tags include build number for reproducibility.

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
- [ ] **Firebase CLI** — `bun add -g firebase-tools`
- [ ] **FlutterFire CLI** — `dart pub global activate flutterfire_cli`
- [ ] **Fastlane** — `brew install fastlane` or `gem install fastlane`
- [ ] **Node.js** 24+ — `brew install node`
- [ ] **Nx CLI** — `bun add -g nx` (Optional, can use `bunx nx`)

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
# First, get your project ID
bws project list
# Copy the "id" field from your project

# Create secret (syntax: KEY VALUE PROJECT_ID)
bws secret create "PARABLE_BLOOM_ANDROID_KEYSTORE" "<base64-string>" "<project-id>"

# List all secrets (shows UUIDs and keys)
bws secret list

# Get secret value by UUID (copy UUID from list output)
bws secret get "<secret-uuid>"

# Update secret by UUID
bws secret edit "<secret-uuid>" "<new-value>"
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
# First, get your project ID
PROJECT_ID=$(bws project list | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

# Or manually: bws project list
# Copy the "id" value, then use it below

# Create secrets (replace <PROJECT_ID> with your actual project ID)
bws secret create "PARABLE_BLOOM_ANDROID_KEYSTORE" "$(base64 -i ~/parable-bloom-upload.jks)" "$PROJECT_ID"
bws secret create "PARABLE_BLOOM_ANDROID_KEY_ALIAS" "upload" "$PROJECT_ID"
bws secret create "PARABLE_BLOOM_ANDROID_KEY_PASSWORD" "<your-key-password>" "$PROJECT_ID"
bws secret create "PARABLE_BLOOM_ANDROID_STORE_PASSWORD" "<your-store-password>" "$PROJECT_ID"

# Verify creation
bws secret list
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
# Get secret values from BWS (filter by key name)
KEYSTORE_ID=$(bws secret list | grep PARABLE_BLOOM_ANDROID_KEYSTORE | grep -o '"id":"[^"]*' | cut -d'"' -f4)
ALIAS_ID=$(bws secret list | grep PARABLE_BLOOM_ANDROID_KEY_ALIAS | grep -o '"id":"[^"]*' | cut -d'"' -f4)
KEY_PASS_ID=$(bws secret list | grep PARABLE_BLOOM_ANDROID_KEY_PASSWORD | grep -o '"id":"[^"]*' | cut -d'"' -f4)
STORE_PASS_ID=$(bws secret list | grep PARABLE_BLOOM_ANDROID_STORE_PASSWORD | grep -o '"id":"[^"]*' | cut -d'"' -f4)

# Decode keystore from BWS
bws secret get "$KEYSTORE_ID" | grep -o '"value":"[^"]*' | cut -d'"' -f4 | base64 -d > /tmp/parable-bloom.jks

# Set environment variables
export ANDROID_KEYSTORE_PATH=/tmp/parable-bloom.jks
export ANDROID_STORE_PASSWORD="$(bws secret get "$STORE_PASS_ID" | grep -o '"value":"[^"]*' | cut -d'"' -f4)"
export ANDROID_KEY_ALIAS="$(bws secret get "$ALIAS_ID" | grep -o '"value":"[^"]*' | cut -d'"' -f4)"
export ANDROID_KEY_PASSWORD="$(bws secret get "$KEY_PASS_ID" | grep -o '"value":"[^"]*' | cut -d'"' -f4)"

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
# Get your project ID
PROJECT_ID=$(bws project list | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

# Certificate
bws secret create "PARABLE_BLOOM_IOS_CERTIFICATE_P12" "$(base64 -i ~/path/to/cert.p12)" "$PROJECT_ID"
bws secret create "PARABLE_BLOOM_IOS_CERTIFICATE_PASSWORD" "<your-p12-password>" "$PROJECT_ID"

# Provisioning Profile
bws secret create "PARABLE_BLOOM_IOS_PROVISIONING_PROFILE" "$(base64 -i ~/Downloads/ParableBloomAppStore.mobileprovision)" "$PROJECT_ID"
bws secret create "PARABLE_BLOOM_IOS_PROVISIONING_PROFILE_UUID" "<uuid-from-step-3>" "$PROJECT_ID"

# Team ID (find in Apple Developer portal)
bws secret create "PARABLE_BLOOM_IOS_TEAM_ID" "<your-team-id>" "$PROJECT_ID"
```

### Step 5: Create App Store Connect API Key

1. **Go to**: <https://appstoreconnect.apple.com/access/api>
2. **Click**: + (Generate API Key)
3. **Name**: `Parable Bloom CI/CD`
4. **Access**: App Manager
5. **Download** the `.p8` file (only chance to download!)
6. **Note**: Key ID and Issuer ID from the page

```bash
# Get your project ID
PROJECT_ID=$(bws project list | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

# Store API key
bws secret create "PARABLE_BLOOM_APP_STORE_CONNECT_KEY" "$(base64 -i ~/Downloads/AuthKey_*.p8)" "$PROJECT_ID"
bws secret create "PARABLE_BLOOM_APP_STORE_CONNECT_KEY_ID" "ABC123DEFG" "$PROJECT_ID"
bws secret create "PARABLE_BLOOM_APP_STORE_CONNECT_ISSUER_ID" "<issuer-uuid>" "$PROJECT_ID"
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
   # Get your project ID
   PROJECT_ID=$(bws project list | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

   # Create secret
   bws secret create "PARABLE_BLOOM_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" "$(base64 -i ~/Downloads/service-account.json)" "$PROJECT_ID"
   ```

### Fastlane Lanes

**Android Fastlane** (`android/fastlane/Fastfile`):

- `fastlane deploy` — Upload internal testing track to Google Play (draft status)
- `fastlane beta` — Upload beta track to Google Play
- `fastlane production` — Upload production track to Google Play
- `fastlane promote_to_beta` — Promote internal → beta
- `fastlane build_release` — Build only (no upload)

All lanes assume the `.aab` is pre-built (e.g., via `flutter build appbundle --release`). They handle upload only.

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
- Build number: Dynamically fetched and incremented based on the latest version code in the Google Play Console (internal track). This ensures monotonically increasing version codes without relying on manual state or large formulas.

### Automated Version Bumping

The project uses **Nx Release** organized into three project-specific groups:

1. **`parable-bloom`**: Game app. Tags: `v*`. The release workflow automatically runs `scripts/bump_version.dart` after versioning to sync the version to `pubspec.yaml`.
2. **`hugo-site`**: Documentation site. Tags: `hugo-site-v*`.
3. **`level-builder`**: Go CLI tool. Tags: `level-builder-v*`.

Usage:

```bash
# Bump patch version for all projects
bunx nx release --specifier patch --yes

# Bump minor version for just the game
bunx nx release --specifier minor --projects parable-bloom --yes
```

The automated process (managed by the `release.yml` workflow):

1. Calculates new versions based on Conventional Commits or provided specifier.
2. Updates `package.json` files.
3. Identifies the new version and runs `scripts/bump_version.dart` for the game app to sync with `pubspec.yaml`.
4. Generates the `CHANGELOG.md`.
5. Creates git commits and project-specific tags.

### Manual Version Update (Not Recommended)

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

```markdown
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

- [x] Create `scripts/update_changelog.dart` that:
  - [x] Reads git commits since last tag
  - [x] Groups commits by type (Features, Fixes, etc.)
  - [x] Generates markdown sections
  - [x] Updates `CHANGELOG.md` with new version section
  - [x] Preserves existing changelog history

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

3. **Bump version** (via Nx):

   ```bash
   # Dry-run to see what will happen
   bunx nx release --dry-run

   # Bump version (independent for each project)
   bunx nx release --yes
   ```

   The automated process:
   1. Calculates new versions based on Conventional Commits.
   2. Updates `package.json` files and syncs to `pubspec.yaml` via hooks (game only).
   3. Generates the `CHANGELOG.md` for each project.
   4. Creates a single git commit and project-specific tags (e.g., `v1.3.1`, `hugo-site-v1.0.1`).

4. **Push to GitHub**:

   ```bash
   git push origin develop --tags
   ```

5. **GitHub Actions release triggers automatically** when tag is pushed matching `v*` pattern. No PR merge needed.

### Automated Release Process (CI/CD)

**Trigger**: Git tag pushed matching `v*` pattern (e.g., `v1.0.0+1`, `v1.2.3-beta+5`)

**Workflow** (`.github/workflows/release.yml`):

#### Job: firebase-config (ubuntu-latest)

- Checks out code, sets up Flutter + Node 24 + Bun
- Installs Firebase CLI and FlutterFire CLI
- Runs `task firebase:configure:ci` to generate `firebase_options.dart` for all supported platforms.
- Uploads `lib/firebase_options.dart` as shared artifact for build jobs

#### Job: build-android (ubuntu-latest)

- Fetches secrets from Bitwarden (Android signing credentials, google-services.json, Play service account)
- Downloads firebase_options.dart from firebase-config job
- Sets up Flutter (with cache), Java, Gradle cache
- Decodes and configures Android keystore + google-services.json
- Calculates unique build version: Dynamically fetches the highest `versionCode` currently on the internal track using Fastlane and increments it by 1.
- Runs `task release:android BUILD_NAME=... BUILD_NUMBER=...`
- Uploads signed `.aab` to Google Play Console internal testing track via Fastlane (draft release)
- Uploads `.aab` artifact to Actions for reference

#### Job: build-web (ubuntu-latest)

- Downloads firebase_options.dart
- Sets up Flutter with caching
- Runs `task release:web`
- Packages and uploads web build artifact

#### Job: build-linux (ubuntu-latest)

- Installs GTK development libraries
- Downloads firebase_options.dart
- Sets up Flutter with caching
- Runs `task release:linux`
- Packages and uploads Linux build artifact

#### Job: build-windows (windows-latest)

- Downloads firebase_options.dart
- Sets up Flutter with caching
- Runs `task release:windows`
- Packages and uploads Windows build artifact

#### Job: build-ios (macos-latest)

- **Currently disabled** (`if: false`) — awaiting Apple Developer account setup

#### Job: build-macos (macos-latest)

- **Currently disabled** (`if: false`) — known build issues to resolve later

#### Job: release (ubuntu-latest)

- Depends on all build jobs completing
- Creates lightweight GitHub release:
  - Uses tag name as release title
  - Auto-generates release notes from commit history
  - **Does not attach artifacts** (focuses on app store releases)
- Requires `contents: write` permission to create releases

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

**Problem**: `pubspec.yaml` parse error

- Validate YAML syntax: `flutter pub get`
- Check version format: `1.0.0+1` (not `1.0.0-beta+1`)

**Problem**: `Unable to determine the previous git tag`

- This usually happens during the first release after moving to Nx groups.
- Ensure `release.groups.<group>.changelog.automaticFromRef` is set to `true` in `nx.json`.
- Nx will then fallback to the first commit of the repo to generate the initial changelog.

**Problem**: `Missing authentication (bunx npm login)`

- Nx Release defaults to attempting an NPM publish for JS projects.
- In recent versions of Nx (v20+), `"publish": false` is NOT a valid property in `nx.json`.
- Instead, ensure you use the `--skip-publish` flag when running `nx release` in CI, or configure the `release` block in each project's `project.json` if you need persistent project-level control.

---

## Checklist: First-Time Setup

Complete this checklist to set up the automated release pipeline:

### Deployment Prerequisites

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

- [x] Generate release keystore
- [x] Update `android/app/build.gradle.kts` with signing config
- [ ] Test local release build
- [ ] Create Google Play service account
- [x] Initialize Fastlane in `android/`
- [x] Create `android/fastlane/Fastfile`

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
# Version management (Full automated bump + changelog + tag)
task release:bump
# Or manually via Nx
bunx nx release --specifier patch --yes

# Local builds
task release:android
task release:ios
task release:web

# Fastlane (must be run from project android/ios subfolders)
cd apps/parable-bloom/android && fastlane deploy
cd apps/parable-bloom/ios && fastlane beta

# BWS secrets
bws secret list
bws secret get PARABLE_BLOOM_ANDROID_KEYSTORE
bws secret create "SECRET_NAME" --value "secret-value"
```

### File Structure

```text
parable-bloom/
├── apps/
│   ├── parable-bloom/
│   │   ├── android/
│   │   │   ├── app/
│   │   │   │   └── build.gradle.kts     # Updated with release signing
│   │   │   └── fastlane/
│   │   │       ├── Fastfile             # Android Fastlane configuration
│   │   │       └── Appfile
│   │   ├── ios/
│   │   │   ├── ExportOptions.plist      # iOS export configuration
│   │   │   ├── Runner.xcodeproj/        # Updated for manual signing
│   │   │   └── fastlane/
│   │   │       ├── Fastfile             # iOS Fastlane configuration
│   │   │       └── Appfile
│   │   ├── pubspec.yaml                 # Target for version bumps
│   │   └── ...
├── .github/
│   └── workflows/
│       ├── ci.yml                       # Consolidated CI
│       ├── release.yml                  # Versioning trigger
│       └── publish.yml                  # Build/Publish trigger on tags
├── scripts/
│   ├── bump_version.dart                # Version automation hook
│   └── update_changelog.dart            # Changelog generation backend
├── documentation/
│   └── RELEASE_PROCESS.md               # This file
├── CHANGELOG.md                         # Workspace-wide changelog
└── Taskfile.yml                         # Root orchestration
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
