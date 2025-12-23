# Bitwarden Secrets Manager Setup for Parable Bloom

## ✅ Completed Setup

### Bitwarden Project Created

- **Project Name**: `parable-bloom`
- **Project ID**: `7864e88f-517c-4da9-a114-b3bc0032bca0`
- **Secrets Created**:
  - `FIREBASE_WEB_API_KEY`: Web API key for Firebase
  - `FIREBASE_PROJECT_ID`: Firebase project identifier

### CI/CD Integration

- Updated `.github/workflows/ci.yml` to retrieve secrets automatically
- Uses official `bitwarden/sm-action@v2` GitHub Action
- **Uses secret UUIDs** (not names) for secure retrieval
- Secrets injected as environment variables during builds

## 🔧 Manual Setup Required

### 1. Create Service Account Access Token

Since Bitwarden Secrets Manager requires a service account for CI/CD access, you need to create this through the Bitwarden web interface:

1. Go to [https://vault.bitwarden.com](https://vault.bitwarden.com)
2. Navigate to **Organization Settings** → **Secrets Manager**
3. Click **Service Accounts** → **New Service Account**
4. Name it `parable-bloom-ci`
5. Grant access to the `parable-bloom` project
6. Copy the generated **Access Token**

### 2. Add Access Token to GitHub Secrets

1. Go to your GitHub repository: **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Name: `BWS_ACCESS_TOKEN`
4. Value: Paste the service account access token from step 1
5. Click **Add secret**

### 3. Verify Setup

Once you've completed steps 1-2, the CI workflow will automatically:

- Retrieve Firebase secrets from Bitwarden
- Make them available as environment variables
- Use them in Flutter builds

## 📋 Next Steps

### Phase 3: Repository Implementation

1. Create Firebase repository classes
2. Implement cloud sync logic
3. Add offline-first data management
4. Test end-to-end sync functionality

### Phase 4: Enhanced CI/CD

1. Add Firebase deployment workflows
2. Configure app store build secrets
3. Set up automated releases
4. Add Firebase hosting deployment

## 🔍 Troubleshooting

### CI Fails with Authentication Error

- Verify the `BWS_ACCESS_TOKEN` secret is correctly set in GitHub
- Ensure the service account has access to the `parable-bloom` project
- Check that the project ID in the workflow matches: `7864e88f-517c-4da9-a114-b3bc0032bca0`

### Secrets Not Available in Build

- Confirm the `bitwarden/sm-action@v2` syntax in the workflow
- **Verify you're using secret UUIDs** (not names) in the `secrets` parameter
- Check that secrets are properly mapped in the `secrets` parameter
- Ensure the service account has access to the specified project
- Get secret UUIDs from Bitwarden web interface or `bws secret list`

## 🔐 Security Notes

- **Access Token Security**: Never commit access tokens to version control
- **Service Account Scope**: Limit service account access to only required projects
- **Secret Rotation**: Regularly rotate access tokens and API keys
- **Environment Separation**: Consider separate projects/secrets for staging vs production

## 📚 Resources

- [Bitwarden Secrets Manager Documentation](https://bitwarden.com/help/secrets-manager/)
- [GitHub Actions Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Firebase Flutter Documentation](https://firebase.google.com/docs/flutter/setup)

## 🚀 Local Development Setup

### FlutterFire CLI Configuration

Firebase configuration is now managed by **FlutterFire CLI** for maximum reliability and simplicity. No manual secret handling required!

#### **Prerequisites:**

1. **FlutterFire CLI** installed globally: `dart pub global activate flutterfire_cli`
2. **Firebase project access** (automatically configured via FlutterFire)

#### **One-Command Setup:**

```bash
# Configure Firebase for all platforms
flutterfire configure --project=parableweave --platforms=android,ios,web --yes

# Or using Task
task firebase:configure
```

**What FlutterFire CLI does:**

1. ✅ Connects to your Firebase project
2. ✅ Downloads official Firebase configuration files
3. ✅ Generates `lib/firebase_options.dart` with proper FirebaseOptions
4. ✅ Updates platform-specific config files automatically

#### **Generated Files:**

- **`lib/firebase_options.dart`** - **NEW** FlutterFire-generated options class
- **`android/app/google-services.json`** - Official Android Firebase config
- **`ios/Runner/GoogleService-Info.plist`** - Official iOS Firebase config
- **`web/firebase-config.js`** - Web Firebase config (if needed)

#### **Usage in Code:**

```dart
// main.dart - now uses FlutterFire-generated options
import 'firebase_options.dart';

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform, // ← Automatically handles platform detection
);
```

#### **Security & Reliability:**

- 🔐 **Official Firebase configuration** - No manual API key handling
- 🔐 **Platform-specific options** - Correct config for each platform
- 🔐 **Version controlled** - `firebase_options.dart` is safe to commit
- ⚠️ Platform config files are still excluded from version control

#### **CI/CD Integration:**

GitHub Actions uses Bitwarden secrets to generate Firebase config files (since FlutterFire CLI requires Firebase CLI authentication which isn't available in CI):

```yaml
- name: Retrieve secrets with Bitwarden
  # Gets FIREBASE_WEB_API_KEY and FIREBASE_PROJECT_ID

- name: Generate Firebase config files
  run: |
    # Generates android/app/google-services.json
    # Generates ios/Runner/GoogleService-Info.plist
    # Generates web/firebase-config.js
```

**Result**: Secure, automated Firebase configuration in CI/CD using Bitwarden secrets!

#### **Legacy Manual Setup (Not Recommended):**

The old Bitwarden-based script (`./scripts/setup-firebase.sh`) is still available but **FlutterFire CLI is now the recommended approach** for its official support and reliability.

---

**Status**: 🔄 **Awaiting Service Account Setup** - Complete steps 1-2 above, then CI will work automatically.
