# CrewPoint — Post-Implementation Setup Guide

Step-by-step instructions to get the app running on device after code implementation.

---

## 1. Firebase Project Setup (FlutterFire CLI)

### 1.1 Create Firebase Projects

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create **3 projects** (or one project with 3 apps):
   - `crewpoint-dev`
   - `crewpoint-stg`
   - `crewpoint-prod`
3. In each project, enable:
   - **Authentication** → Sign-in methods: Email/Password, Google, Apple
   - **Cloud Firestore** → Start in test mode (secure with rules in Section 6)
   - **Storage** (for receipt uploads)

### 1.2 Install FlutterFire CLI

```bash
# Install Firebase CLI (if not already installed)
# See: https://firebase.google.com/docs/cli#install_the_firebase_cli

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Login to Firebase
firebase login
```

### 1.3 Configure Each Flavor

`flutterfire configure` generates a Dart options file **and** overwrites the single native config file (`google-services.json` / `GoogleService-Info.plist`). Since each flavor needs its own native file, run configure per-platform and **move the native file** before the next run.

#### Android (google-services.json)

Run once per flavor, moving the file into the Gradle flavor source set each time:

```bash
# Dev
flutterfire configure --project=crewpoint-dev --out=lib/firebase_options_dev.dart \
  --platforms=android --android-package-name=space.sookoon.crewpoint.dev --yes
mv android/app/google-services.json android/app/src/dev/google-services.json

# Stg
flutterfire configure --project=crewpoint-stg --out=lib/firebase_options_stg.dart \
  --platforms=android --android-package-name=space.sookoon.crewpoint.stg --yes
mv android/app/google-services.json android/app/src/stg/google-services.json

# Prod
flutterfire configure --project=crewpoint-prod --out=lib/firebase_options_prod.dart \
  --platforms=android --android-package-name=space.sookoon.crewpoint.app --yes
mv android/app/google-services.json android/app/src/prod/google-services.json
```

Gradle's Google Services plugin automatically picks `android/app/src/{flavor}/google-services.json` — no extra config needed.

#### iOS (GoogleService-Info.plist)

Run once per flavor, copying the plist into a per-flavor directory:

```bash
# Dev
flutterfire configure --project=crewpoint-dev --out=lib/firebase_options_dev.dart \
  --platforms=ios --ios-bundle-id=space.sookoon.crewpoint.dev --yes
cp ios/Runner/GoogleService-Info.plist ios/Runner/Firebase/dev/GoogleService-Info.plist

# Stg
flutterfire configure --project=crewpoint-stg --out=lib/firebase_options_stg.dart \
  --platforms=ios --ios-bundle-id=space.sookoon.crewpoint.stg --yes
cp ios/Runner/GoogleService-Info.plist ios/Runner/Firebase/stg/GoogleService-Info.plist

# Prod
flutterfire configure --project=crewpoint-prod --out=lib/firebase_options_prod.dart \
  --platforms=ios --ios-bundle-id=space.sookoon.crewpoint.app --yes
cp ios/Runner/GoogleService-Info.plist ios/Runner/Firebase/prod/GoogleService-Info.plist
```

The iOS plist copy phase (Section 2.4) handles selecting the right file at build time.

#### Web (optional)

Run once with any flavor — web doesn't have flavor-specific config files:

```bash
flutterfire configure --project=crewpoint-dev --out=lib/firebase_options_dev.dart \
  --platforms=web --yes
```

### 1.4 Commit or Gitignore Generated Files

**Option A — Commit** (recommended for small teams):
```bash
git add lib/firebase_options_*.dart android/app/src/*/google-services.json ios/Runner/Firebase/
git commit -m "chore: add firebase config for all flavors"
```

**Option B — Gitignore and regenerate in CI** (recommended for open-source/sensitive projects):
```
# .gitignore
lib/firebase_options_*.dart
```

> **Caveat**: Re-running `flutterfire configure` will overwrite the Dart options files and the root-level native files. You'll need to re-do the move/copy steps above.

---

## 2. iOS Xcode Scheme Configuration

### 2.1 Create Build Configurations

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** project (not target) in the navigator
3. Go to **Info** tab → **Configurations**
4. Duplicate existing configurations:
   - `Debug` → `Debug-dev`, `Debug-stg`, `Debug-prod`
   - `Release` → `Release-dev`, `Release-stg`, `Release-prod`
   - `Profile` → `Profile-dev`, `Profile-stg`, `Profile-prod`

### 2.2 Link Flavor xcconfig Files

For each configuration, set the xcconfig:

1. Still in **Info** → **Configurations**
2. Under each configuration, expand **Runner** target
3. Set the appropriate xcconfig:

| Configuration | xcconfig |
|--------------|----------|
| Debug-dev | `ios/Flutter/flavors/dev.xcconfig` |
| Debug-stg | `ios/Flutter/flavors/stg.xcconfig` |
| Debug-prod | `ios/Flutter/flavors/prod.xcconfig` |
| Release-dev | `ios/Flutter/flavors/dev.xcconfig` |
| Release-stg | `ios/Flutter/flavors/stg.xcconfig` |
| Release-prod | `ios/Flutter/flavors/prod.xcconfig` |
| Profile-dev | `ios/Flutter/flavors/dev.xcconfig` |
| Profile-stg | `ios/Flutter/flavors/stg.xcconfig` |
| Profile-prod | `ios/Flutter/flavors/prod.xcconfig` |

**Important**: Ensure the xcconfig files `#include` the Flutter configs:
- Debug configs include `Flutter/Debug.xcconfig`
- Release configs include `Flutter/Release.xcconfig`

Update the xcconfig files:

**`ios/Flutter/flavors/dev.xcconfig`**:
```
#include "../Debug.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER=space.sookoon.crewpoint.dev
PRODUCT_NAME=CrewPoint Dev
ASSET_PREFIX=dev
```

(Same pattern for stg/prod, switching `Debug.xcconfig` to `Release.xcconfig` for release builds — or use separate files like `dev-debug.xcconfig` and `dev-release.xcconfig`.)

### 2.3 Create Xcode Schemes

1. In Xcode: **Product** → **Scheme** → **Manage Schemes**
2. Delete the existing "Runner" scheme
3. Create 3 new schemes:

| Scheme Name | Build Configuration (Run) | Build Configuration (Archive) |
|-------------|--------------------------|-------------------------------|
| `dev` | Debug-dev | Release-dev |
| `stg` | Debug-stg | Release-stg |
| `prod` | Debug-prod | Release-prod |

For each scheme:
1. Click **+** → Name it (`dev`, `stg`, or `prod`)
2. Target: **Runner**
3. Edit the scheme:
   - **Run** → Info → Build Configuration → `Debug-{flavor}`
   - **Test** → Info → Build Configuration → `Debug-{flavor}`
   - **Profile** → Info → Build Configuration → `Profile-{flavor}`
   - **Analyze** → Info → Build Configuration → `Debug-{flavor}`
   - **Archive** → Info → Build Configuration → `Release-{flavor}`
4. Mark all schemes as **Shared** (check the "Shared" checkbox)

### 2.4 Add GoogleService-Info.plist Copy Phase

Since `flutterfire configure` overwrites the single plist, we store per-flavor plists in `ios/Runner/Firebase/{flavor}/` and copy the correct one at build time.

1. Select **Runner** target → **Build Phases**
2. Click **+** → **New Run Script Phase**
3. Name it "Copy GoogleService-Info.plist"
4. Move it **above** "Copy Bundle Resources"
5. Paste this script:

```bash
PLIST_DIR="${PROJECT_DIR}/Runner/Firebase"
if [[ "${PRODUCT_BUNDLE_IDENTIFIER}" == *".dev" ]]; then
  cp "${PLIST_DIR}/dev/GoogleService-Info.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
elif [[ "${PRODUCT_BUNDLE_IDENTIFIER}" == *".stg" ]]; then
  cp "${PLIST_DIR}/stg/GoogleService-Info.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
else
  cp "${PLIST_DIR}/prod/GoogleService-Info.plist" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
fi
```

### 2.5 Configure Apple Sign-In

1. In the Apple Developer Portal, create App IDs for all 3 bundle identifiers
2. Enable **Sign in with Apple** capability for each
3. In Xcode: **Runner** target → **Signing & Capabilities** → **+ Capability** → **Sign in with Apple**

---

## 3. Environment Variables & Envied Setup

### 3.1 About Firebase Config

Firebase configuration keys are **no longer stored in `.env` files**. They are auto-generated by `flutterfire configure` into `lib/firebase_options_{flavor}.dart` (see Section 1.3).

The `Env` class and `.env` files are reserved for **non-Firebase secrets** (e.g., third-party API keys added in the future).

### 3.2 Adding Future Non-Firebase Secrets

If you need non-Firebase secrets later:

1. Add keys to `.env`:
   ```
   MAPS_API_KEY=your-key-here
   SENTRY_DSN=https://...
   ```

2. Update `lib/app/core/env/env.dart` with `@Envied` annotations

3. Generate:
   ```bash
   dart run build_runner build -d
   ```

### 3.3 Per-Flavor Env Switching (if needed)

Only required if you add non-Firebase secrets that differ per flavor:

**`scripts/switch_env.sh`**:
```bash
#!/bin/bash
FLAVOR=${1:-dev}
cp ".env.${FLAVOR}" .env
dart run build_runner build -d
echo "Switched to ${FLAVOR} environment"
```

Usage: `./scripts/switch_env.sh stg`

---

## 4. Running the App

### 4.1 Flutter Run Commands

```bash
# Development
flutter run --flavor dev

# Staging
flutter run --flavor stg

# Production
flutter run --flavor prod
```

### 4.2 Build Commands

```bash
# Android APK
flutter build apk --flavor dev
flutter build apk --flavor prod

# Android App Bundle (Play Store)
flutter build appbundle --flavor prod

# iOS (requires Xcode schemes from Step 2)
flutter build ios --flavor dev
flutter build ios --flavor prod
```

---

## 5. Google Sign-In Configuration

### 5.1 Android

1. Get SHA-1 fingerprint:
   ```bash
   cd android && ./gradlew signingReport
   ```
2. Add the SHA-1 to Firebase Console → Project Settings → Android app → SHA certificate fingerprints

### 5.2 iOS

1. Add the `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` to URL schemes:
   - Xcode → Runner target → Info → URL Types
   - Add a URL type with the reversed client ID (e.g., `com.googleusercontent.apps.123456`)

---

## 6. Firestore Security Rules

Deploy these rules to each Firebase project. Rules enforce:
- **Events**: only creator can modify; only members can read
- **Messages**: only event members can read/write; sender identity verified
- **Expenses**: only event members can read; only payer can create
- **Users**: any authenticated user can read; only own document writable

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper: check if user is a member of an event
    function isEventMember(eventId) {
      let event = get(/databases/$(database)/documents/events/$(eventId));
      return request.auth.uid == event.data.creatorId
          || request.auth.uid in event.data.members;
    }

    // Events collection
    match /events/{eventId} {
      // Read: only creator or members
      allow read: if request.auth != null
        && (resource.data.creatorId == request.auth.uid
            || request.auth.uid in resource.data.members);

      // Create: must set yourself as creator
      allow create: if request.auth != null
        && request.resource.data.creatorId == request.auth.uid;

      // Update/Delete: only the creator
      allow update, delete: if request.auth != null
        && resource.data.creatorId == request.auth.uid;

      // Messages subcollection
      match /messages/{messageId} {
        // Read: only event members
        allow read: if request.auth != null && isEventMember(eventId);

        // Create: must be event member and set own senderId
        allow create: if request.auth != null
          && isEventMember(eventId)
          && request.resource.data.senderId == request.auth.uid;

        // Delete: only own messages
        allow delete: if request.auth != null
          && resource.data.senderId == request.auth.uid;

        // No direct updates to messages
        allow update: if false;
      }

      // Expenses subcollection
      match /expenses/{expenseId} {
        // Read: only event members
        allow read: if request.auth != null && isEventMember(eventId);

        // Create: must be event member and set own payerId
        allow create: if request.auth != null
          && isEventMember(eventId)
          && request.resource.data.payerId == request.auth.uid;

        // Delete: only the payer or event creator
        allow delete: if request.auth != null
          && (resource.data.payerId == request.auth.uid
              || get(/databases/$(database)/documents/events/$(eventId)).data.creatorId == request.auth.uid);

        // No direct updates (delete and re-create)
        allow update: if false;
      }
    }

    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
  }
}
```

### Deploy Rules

```bash
firebase deploy --only firestore:rules --project crewpoint-dev
firebase deploy --only firestore:rules --project crewpoint-stg
firebase deploy --only firestore:rules --project crewpoint-prod
```

> **Important**: The `members` array field on event documents must be populated by app code when users are added to an event. Include the creator in this array when creating an event.

---

## 7. App Icons (flutter_launcher_icons)

### 7.1 Add Package

Already in pubspec.yaml. Create config:

**`flutter_launcher_icons.yaml`**:
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icons/launcher_icon.png"
  
  # Flavor-specific overrides
flutter_launcher_icons-dev:
  android: true
  ios: true
  image_path: "assets/icons/launcher_icon_dev.png"
  
flutter_launcher_icons-stg:
  android: true
  ios: true
  image_path: "assets/icons/launcher_icon_stg.png"
```

### 7.2 Generate Icons

1. Place icon images in `assets/icons/` (1024x1024 PNG recommended)
2. Run:
   ```bash
   dart run flutter_launcher_icons
   ```

---

## 8. Lottie Animations

1. Get/create animation files (.json) for:
   - Onboarding page 1: "Plan Together"
   - Onboarding page 2: "Stay Connected"
   - Onboarding page 3: "Track Expenses"
   - Loading spinner

2. Place in `assets/animations/`:
   ```
   assets/animations/onboarding_1.json
   assets/animations/onboarding_2.json
   assets/animations/onboarding_3.json
   assets/animations/loading.json
   ```

3. Register in `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/animations/
   ```

4. Update `OnboardingScreen` and `LoadingAnimation` to use Lottie:
   ```dart
   Lottie.asset('assets/animations/onboarding_1.json')
   ```

---

## 9. Verification Checklist

- [ ] `flutter run --flavor dev` launches on Android emulator
- [ ] `flutter run --flavor dev` launches on iOS simulator (after Xcode scheme setup)
- [ ] Google Sign-In works on both platforms
- [ ] Apple Sign-In works on iOS
- [ ] Email sign-up creates user in Firebase Auth console
- [ ] Chat messages appear in Firestore console
- [ ] Non-member cannot read another user's event (security rules)
- [ ] App displays cached data with airplane mode enabled (offline-first)
- [ ] `flutter build apk --flavor prod` produces signed APK
- [ ] `flutter build ios --flavor prod` produces archive

---

## 10. Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| `flutterfire configure` fails | Run `firebase login` first; ensure project exists in console |
| iOS build fails with bundle ID mismatch | Verify xcconfig `PRODUCT_BUNDLE_IDENTIFIER` matches scheme |
| `DefaultFirebaseOptions` not found | Run `flutterfire configure` for the current flavor |
| `google-services.json` not found for flavor | Ensure file is in `android/app/src/{flavor}/google-services.json` (not `android/app/`) |
| iOS wrong Firebase project | Verify plist copy script (Section 2.4) runs before "Copy Bundle Resources" |
| Google Sign-In cancelled immediately | Add SHA-1 to Firebase Console (Android) |
| Apple Sign-In capability missing | Add in Xcode + Apple Developer Portal |
| Drift migration error | Increment `schemaVersion` in `app_database.dart` |
| Flavor not recognized by Flutter | Use exact names: `dev`, `stg`, `prod` (lowercase) |
| Firestore permission denied | Check `members` array exists on event document |
| Re-ran `flutterfire configure` and lost native files | Re-do the move/copy steps from Section 1.3 |
