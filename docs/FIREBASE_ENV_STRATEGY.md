---
title: "Firebase Environment Strategy - Single Project with Collection-Based Isolation"
version: "1.0"
status: "Planning"
type: "Implementation Guide"
---

# Firebase Environment Strategy: Option A

## Overview

This document outlines a **low-complexity environment strategy** using a single Firebase project (`parable-bloom`) with **Firestore collection-based data isolation** for development, preview, and production environments.

### Approach

- **Single Firebase Project**: `parable-bloom` (no secondary project needed)
- **Environment Separation**: Achieved via Firestore collection naming (`game_progress_dev/`, `game_progress_preview/`, `game_progress_prod/`)
- **No Build Flavors Required**: Same app binary runs across all environments
- **Environment Switching**: Controlled via environment variables in CI/CD and build configuration

### Benefits

✅ Minimal complexity — no build flavors or dual Firebase projects  
✅ Maintains current Firebase token structure  
✅ Isolates test data from production data  
✅ Aligns with current preview hosting per-PR channels  
✅ Easy rollback/migration path  

### Trade-offs

⚠️ All environments share same Firestore rules (no per-environment rule testing)  
⚠️ Slightly more logic in repository layer to handle collection switching  
⚠️ Manual data cleanup required if test data leaks  

---

## Implementation Roadmap

### Phase 1: Backend Configuration (Firestore)

#### Step 1.1: Update Firestore Rules

**File**: `firestore.rules`

Modify rules to secure both collection patterns:

```firestore
match /game_progress_dev/{userId}/modules/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
match /game_progress_preview/{userId}/modules/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
match /game_progress_prod/{userId}/modules/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

**Why**: Ensures each environment collection is properly secured with the same authentication rules.

---

### Phase 2: Application Code

#### Step 2.1: Create Environment Configuration

**New File**: `lib/core/config/environment_config.dart`

```dart
enum AppEnvironment { dev, preview, prod }

class EnvironmentConfig {
  static const String _envVarName = 'APP_ENV';
  
  static AppEnvironment current = _parseEnvironment();
  
  static AppEnvironment _parseEnvironment() {
    final env = String.fromEnvironment(_envVarName, defaultValue: 'dev');
    return AppEnvironment.values.firstWhere(
      (e) => e.name == env,
      orElse: () => AppEnvironment.dev,
    );
  }
  
  static String getFirestoreCollection() {
    switch (current) {
      case AppEnvironment.dev:
        return 'game_progress_dev';
      case AppEnvironment.preview:
        return 'game_progress_preview';
      case AppEnvironment.prod:
        return 'game_progress_prod';
    }
  }
  
  static String environmentName() {
    switch (current) {
      case AppEnvironment.dev:
        return 'Development';
      case AppEnvironment.preview:
        return 'Preview';
      case AppEnvironment.prod:
        return 'Production';
    }
  }
}
```

**Why**: Centralized configuration makes it easy to switch environments at compile time.

---

#### Step 2.2: Update FirebaseGameProgressRepository

**File**: `lib/features/game/data/repositories/firebase_game_progress_repository.dart`

Modify all Firestore collection references to use the environment-aware collection name:

```dart
import 'package:parable_bloom/core/config/environment_config.dart';

class FirebaseGameProgressRepository extends GameProgressRepository {
  static String get _collectionName => EnvironmentConfig.getFirestoreCollection();
  
  @override
  Future<void> saveModuleProgress(String userId, ModuleProgress progress) async {
    await FirebaseFirestore.instance
        .collection(_collectionName)
        .doc(userId)
        .collection('modules')
        .doc(progress.moduleId)
        .set(progress.toJson());
  }
  
  @override
  Future<ModuleProgress?> getModuleProgress(String userId, String moduleId) async {
    final doc = await FirebaseFirestore.instance
        .collection(_collectionName)
        .doc(userId)
        .collection('modules')
        .doc(moduleId)
        .get();
    
    if (!doc.exists) return null;
    return ModuleProgress.fromJson(doc.data()!);
  }
  
  // ... repeat for all other Firestore collection references
}
```

**Why**: Routes all Firestore operations to the correct environment collection.

---

#### Step 2.3: Add Environment Indicator (Optional but Recommended)

**File**: `lib/app.dart` or relevant home screen widget

Add a debug banner or UI indicator in development/preview environments:

```dart
Widget build(BuildContext context) {
  return MaterialApp(
    // ... existing config
    debugShowCheckedModeBanner: EnvironmentConfig.current != AppEnvironment.prod,
    home: Stack(
      children: [
        // Your main app
        const HomeScreen(),
        
        // Environment indicator
        if (EnvironmentConfig.current != AppEnvironment.prod)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: _getEnvironmentColor(),
              child: Text(
                EnvironmentConfig.environmentName(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Color _getEnvironmentColor() {
  switch (EnvironmentConfig.current) {
    case AppEnvironment.dev:
      return Colors.orange;
    case AppEnvironment.preview:
      return Colors.blue;
    case AppEnvironment.prod:
      return Colors.green;
  }
}
```

**Why**: Makes it immediately clear which environment is running during testing.

---

### Phase 3: CI/CD Configuration

#### Step 3.1: Update GitHub Workflows for Environment Variables

**File**: `.github/workflows/test.yml`

Add environment variable that gets passed to Flutter builds:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
      
      - name: Run tests
        run: flutter test
        env:
          APP_ENV: dev
```

**File**: `.github/workflows/deploy-web.yml`

Update deploy step to pass environment based on branch:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
      
      - name: Determine environment
        id: env
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "APP_ENV=prod" >> $GITHUB_ENV
          elif [[ "${{ github.ref }}" == "refs/heads/develop" ]]; then
            echo "APP_ENV=preview" >> $GITHUB_ENV
          else
            echo "APP_ENV=preview" >> $GITHUB_ENV
          fi
      
      - name: Build Flutter web
        run: |
          flutter pub get
          flutter build web --dart-define=APP_ENV=${{ env.APP_ENV }}
        env:
          APP_ENV: ${{ env.APP_ENV }}
      
      - name: Deploy to Firebase
        run: firebase deploy --only hosting:${{ env.FIREBASE_CHANNEL }}
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_CI_TOKEN }}
          FIREBASE_CHANNEL: ${{ github.ref == 'refs/heads/main' && 'live' || format('pr-{0}', github.event.pull_request.number) }}
```

**Why**: Ensures each deployment targets the correct Firestore collection based on the branch being deployed.

---

#### Step 3.2: Local Development Setup

**File**: `lib/main.dart` (or document in README)

Add instructions for local development environment switching:

```dart
void main() {
  // Environment can be overridden at compile time:
  // flutter run --dart-define=APP_ENV=dev
  // flutter run --dart-define=APP_ENV=preview
  // flutter run --dart-define=APP_ENV=prod
  
  runApp(const MyApp());
}
```

**Local Testing Commands**:

```bash
# Run in development environment (default)
flutter run

# Run in preview environment
flutter run --dart-define=APP_ENV=preview

# Run in production environment
flutter run --dart-define=APP_ENV=prod

# Run tests in specific environment
flutter test --dart-define=APP_ENV=dev

# Build web for specific environment
flutter build web --dart-define=APP_ENV=prod
flutter build web --dart-define=APP_ENV=dev
```

**Why**: Allows developers to test all environments locally without building separate flavors.

---

### Phase 4: Testing & Verification

#### Step 4.1: Validate Collection Switching

**Test**: `test/repositories/firebase_repository_test.dart`

Add test to verify environment-specific collections are used:

```dart
test('uses correct Firestore collection based on environment', () async {
  // This test should verify that different environment configs
  // result in queries against the correct collection name
  expect(EnvironmentConfig.getFirestoreCollection(), 'game_progress_dev');
  
  // If testing preview:
  // expect(EnvironmentConfig.getFirestoreCollection(), 'game_progress_preview');
});
```

**Why**: Ensures the collection switching logic works as expected.

---

#### Step 4.2: Manual Testing Checklist

- [ ] Run app locally in dev environment → verify dev data is written to `game_progress_dev/` collection
- [ ] Run app locally in preview environment → verify preview data is written to `game_progress_preview/` collection
- [ ] Run app locally in prod environment → verify production data is written to `game_progress_prod/` collection
- [ ] Check Firestore console — confirm three separate collections exist with isolated user data
- [ ] Test CI/CD deploy to preview branch → verify data goes to `game_progress_preview/`
- [ ] Test CI/CD deploy to main branch → verify data goes to `game_progress_prod/`
- [ ] Verify environment indicator displays correctly on UI (if implemented)

---

### Phase 5: Documentation & Cleanup

#### Step 5.1: Update Developer Documentation

**File**: `CONTRIBUTING.md` or new `docs/ENVIRONMENT_SETUP.md`

Document the environment strategy for future developers:

- How to run in each environment
- Firestore collection structure
- When to use each environment
- Data retention/cleanup policies

---

#### Step 5.2: Firestore Cleanup Policy

Establish a policy for cleaning up development/preview data:

- [ ] Define retention period for dev data (e.g., 7 days)
- [ ] Document manual cleanup process
- [ ] (Optional) Create Firebase Cloud Function to auto-delete old dev records

---

## Configuration Summary

### Environment → Firestore Collection Mapping

| Environment | Collection Name | Use Case | Data Retention |
|-------------|-----------------|----------|-----------------|
| **Development** | `game_progress_dev` | Local testing, experimentation | Until manually cleaned |
| **Preview** | `game_progress_preview` | PR preview deployments | 7 days (recommended) |
| **Production** | `game_progress_prod` | Released app in user hands | Indefinite |

### Build Commands by Environment

```bash
# Development
flutter run --dart-define=APP_ENV=dev

# Preview
flutter run --dart-define=APP_ENV=preview

# Production
flutter run --dart-define=APP_ENV=prod

# Web builds
flutter build web --dart-define=APP_ENV=dev
flutter build web --dart-define=APP_ENV=preview
flutter build web --dart-define=APP_ENV=prod
```

### Firestore Rules Template

```firestore
// Development collection
match /game_progress_dev/{userId}/modules/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}

// Preview collection
match /game_progress_preview/{userId}/modules/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}

// Production collection
match /game_progress_prod/{userId}/modules/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

---

## Implementation Timeline

| Phase | Duration | Effort |
|-------|----------|--------|
| Phase 1: Firestore Rules | 15 min | Low |
| Phase 2: App Code Changes | 1–2 hours | Medium |
| Phase 3: CI/CD Updates | 1 hour | Medium |
| Phase 4: Testing | 1–2 hours | Medium |
| Phase 5: Documentation | 30 min | Low |
| **Total** | **4–6 hours** | **Medium** |

---

## Risk Mitigation

### Potential Issues & Solutions

| Risk | Impact | Mitigation |
|------|--------|-----------|
| **Test data leaks to prod** | High | Code review before prod deploys; clear naming conventions |
| **Firestore quota overages** | Medium | Monitor usage per collection; set up billing alerts |
| **Developers forget to switch environments** | Medium | Environment indicator on UI; clear documentation |
| **Accidental prod data deletion** | High | Firestore backups enabled; read-only rules for production |

---

## Next Steps

1. **Review & Approve**: Get team sign-off on this approach
2. **Create feature branch**: `feature/firebase-env-strategy`
3. **Implement Phase 1**: Update Firestore rules
4. **Implement Phase 2**: Add environment configuration and update repository
5. **Implement Phase 3**: Update CI/CD workflows
6. **Test thoroughly**: Manual and automated testing
7. **Merge & deploy**: Verify in staging before main
8. **Document**: Update CONTRIBUTING.md with new workflow

---

## References

- [ARCHITECTURE.md](ARCHITECTURE.md) — Current repository pattern & Hive/Firebase setup
- [TECHNICAL_IMPLEMENTATION.md](TECHNICAL_IMPLEMENTATION.md) — Firestore sync implementation details
- [firestore.rules](../firestore.rules) — Current Firestore security rules
- Firebase Environment Configuration: <https://firebase.flutter.dev/docs/overview/>

---

## Questions?

If you encounter any issues or need clarification on any phase, refer to [TECHNICAL_IMPLEMENTATION.md](TECHNICAL_IMPLEMENTATION.md) or the inline code comments in this guide.
