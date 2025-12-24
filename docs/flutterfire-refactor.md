### Refined Implementation Plan: Analytics (Option 2), Hosting (Option 2), and Web Support

Excellent choices!

- **Analytics Option 2 (Custom Events)**: This gives you actionable, puzzle-specific insights (e.g., average taps per level, wrong-tap frequency, drop-off points) that will directly inform balance tweaks and post-MVP expansions like procedural levels. Auto-events are nice, but custom ones turn Analytics into a design tool.
- **Hosting Option 2 (GitHub Actions Automation)**: Automated deploys on main (and optional PR previews) save time, ensure consistency, and let you share live web builds instantly for feedback—perfect for your solo dev flow and beta testing.
- **Web Support**: Since it's already enabled and the web app is registered in Firebase Console, we skip redundant steps and focus on integration/testing.

We'll integrate these seamlessly with the existing Riverpod/Hive architecture and Bitwarden Secrets Manager (BSM) approach. No keys exposed, full reproducibility.

#### Key Benefits Recap & Alternatives Considered

- **Custom Analytics**: Benefits include precise metrics (e.g., identify if Level 8 has high wrong_taps → add hint). Alternative (auto-only) would miss this depth.
- **Automated Hosting**: Benefits: One-push deploys, versioned URLs, fast CDN. Manual alternative is fine for occasional tests but slower for iteration.
- **Overall**: These additions (~6-8 hours) position you for data-driven decisions early, without delaying MVP core.

---

### Updated Gameplan

#### Phase 1: Local Analytics Implementation (Custom Events – 2-3 Hours)

1. **Add Package** (if not already):

   ```bash
   flutter pub add firebase_analytics
   ```

2. **Create Analytics Service** (Recommended: Wrapper for testability and future extensions):
   - File: `lib/services/analytics_service.dart`

     ```dart
     import 'package:firebase_analytics/firebase_analytics.dart';

     class AnalyticsService {
       static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

       // Enable debug view locally if needed
       Future<void> init() async {
         await _analytics.setAnalyticsCollectionEnabled(true);
         // Optional: Debug mode for local testing
         // await _analytics.setCurrentScreen(screenName: 'Home');
       }

       Future<void> logLevelStart(int levelId) async {
         await _analytics.logEvent(
           name: 'level_start',
           parameters: {'level_id': levelId},
         );
       }

       Future<void> logLevelComplete(int levelId, int taps, int wrongTaps) async {
         await _analytics.logEvent(
           name: 'level_complete',
           parameters: {
             'level_id': levelId,
             'taps_total': taps,
             'wrong_taps': wrongTaps,
             'perfect': wrongTaps == 0,
           },
         );
       }

       Future<void> logWrongTap(int levelId, int remainingLives) async {
         await _analytics.logEvent(
           name: 'wrong_tap',
           parameters: {
             'level_id': levelId,
             'remaining_lives': remainingLives,
           },
         );
       }

       Future<void> logGameOver(int levelId) async {
         await _analytics.logEvent(name: 'game_over', parameters: {'level_id': levelId});
       }

       // Add more as needed: hint_used, mercy_purchase, parable_viewed
     }
     ```

3. **Inject into App**:
   - In `main.dart` (after Firebase init):

     ```dart
     final analyticsService = AnalyticsService();
     await analyticsService.init();
     ```

   - Make available via Riverpod (recommended for decoupling):

     ```dart
     final analyticsServiceProvider = Provider<AnalyticsService>((ref) => AnalyticsService());
     ```

   - In game logic (e.g., GameProgressNotifier or Level Complete handler):

     ```dart
     ref.read(analyticsServiceProvider).logLevelComplete(levelId, totalTaps, wrongTaps);
     ```

4. **Test Locally**:
   - Enable DebugView in Firebase Console > Analytics > DebugView.
   - Run on device/emulator with `--enable-analytics-debug-mode` flag or use adb command.
   - Trigger events → verify in real-time DebugView.

#### Phase 2: Local Web Hosting Setup & Automation Prep (2-3 Hours)

1. **Build Web Locally**:

   ```bash
   flutter build web --release
   ```

2. **Firebase Hosting Init** (one-time):

   ```bash
   firebase login  # Your personal account
   firebase init hosting
   ```

   - Select your project.
   - Public directory: `build/web`
   - Single-page app: Yes (rewrites all to index.html).
   - Overwrite index.html: No.

3. **Manual Test Deploy**:

   ```bash
   firebase deploy --only hosting
   ```

   - Get live URL (e.g., parableweave.web.app) → test in browser.

4. **Update Taskfile.yml** (Shortcuts):

   ```yaml
   tasks:
     web:build:
       desc: Build web release
       cmds:
         - flutter build web --release

     hosting:deploy:
       desc: Deploy to Firebase Hosting (manual token)
       cmds:
         - firebase deploy --only hosting
       env:
         FIREBASE_TOKEN: '{{bitwarden "item" "parableweave" "field" "firebase_token"}}'  # Generate once via firebase login:ci

     hosting:preview:
       desc: Deploy preview channel
       cmds:
         - firebase hosting:channel:deploy pr-${{PR_NUMBER}}  # Manual for now
   ```

#### Phase 3: CI/CD Automation for Hosting (Option 2 – 1-2 Hours)

1. **Generate CI Token** (one-time):

   ```bash
   firebase login:ci
   ```

   - Copy token → add to BSM as `FIREBASE_CI_TOKEN`.
   - In GitHub Secrets: Add `FIREBASE_CI_TOKEN`.

2. **Create/Update Workflow** (`.github/workflows/deploy-web.yml`):

   ```yaml
   name: Deploy Web to Firebase Hosting

   on:
     push:
       branches: [main]
     pull_request:
       branches: [main]

   jobs:
     deploy:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4

         - uses: subosito/flutter-action@v2
           with:
             channel: stable

         - name: Pull Secrets from Bitwarden
           uses: bitwarden/sm-action@v1
           with:
             access_token: ${{ secrets.BITWARDEN_ACCESS_TOKEN }}
             secrets: |
               <SECRET_ID_PROJECT_ID> > FIREBASE_PROJECT_ID
               <SECRET_ID_SERVICE_ACCOUNT> > FIREBASE_SERVICE_ACCOUNT_JSON
               <SECRET_ID_CI_TOKEN> > FIREBASE_CI_TOKEN

         - name: Setup Firebase Config
           run: |
             echo "$FIREBASE_SERVICE_ACCOUNT_JSON" > firebase_service_account.json
             flutterfire configure --project=$FIREBASE_PROJECT_ID --platforms=web --account=firebase_service_account.json

         - name: Build Web
           run: flutter build web --release

         - name: Deploy to Hosting
           run: |
             npm install -g firebase-tools
             firebase deploy --only hosting --token $FIREBASE_CI_TOKEN
           if: github.ref == 'refs/heads/main'

         - name: Deploy Preview (PR only)
           if: github.event_name == 'pull_request'
           run: |
             firebase hosting:channel:deploy pr-${{ github.event.pull_request.number }} --token $FIREBASE_CI_TOKEN
   ```

   - Benefits: Main → production URL; PRs → temporary preview URLs (commented automatically).

#### Phase 4: Verification & Next Steps

1. **Analytics**: View custom events in Firebase Console > Analytics > Events.
2. **Hosting**: Share live web URL for playtesting (touch controls work via Flame).
3. **Performance Note**: Web build may need optimization (e.g., `--web-renderer canvaskit` for better graphics).

---

### Updated Checklist (Analytics + Hosting Focus)

- [ ] Add `firebase_analytics` package.
- [ ] Implement `AnalyticsService` with custom events.
- [ ] Wire events in game logic (level start/complete/wrong tap).
- [ ] Test in DebugView.
- [ ] `firebase init hosting` + manual deploy.
- [ ] Add `FIREBASE_CI_TOKEN` to BSM/GitHub.
- [ ] Create deploy-web.yml workflow.
- [ ] Push to main → verify auto-deploy.
- [ ] (Optional) Add PR preview comments.

This gets you rich insights and a live web demo fast. Start with the AnalyticsService—it's the highest ROI. Once events flow, we can add more (e.g., parable_viewed). Ready for code snippets in specific files, or Taskfile refinements? Let's keep momentum! 🌿
