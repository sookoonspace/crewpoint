# CrewPoint — Post-Implementation Setup Guide

Step-by-step instructions to get the app running on device after code implementation.

---

## 1. Firebase Project Setup

### 1.1 Create Firebase Projects

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create **3 projects** (or one project with 3 apps):
   - `crewpoint-dev`
   - `crewpoint-stg`
   - `crewpoint-prod`
3. In each project, enable:
   - **Authentication** → Sign-in methods: Email/Password, Google, Apple
   - **Cloud Firestore** → Start in test mode (secure later)
   - **Storage** (for receipt uploads)

### 1.2 Register Android Apps

For each project, register an Android app:

| Flavor | Package Name |
|--------|-------------|
| dev | `space.sookoon.crewpoint.dev` |
| stg | `space.sookoon.crewpoint.stg` |
| prod | `space.sookoon.crewpoint.app` |

1. Download `google-services.json` for each
2. Place them in flavor-specific directories:

```
android/app/src/dev/google-services.json
android/app/src/stg/google-services.json
android/app/src/prod/google-services.json
```

3. Add the Google Services plugin to Android build:

**`android/build.gradle.kts`** — add to plugins block:
```kotlin
id("com.google.gms.google-services") version "4.4.2" apply false
```

**`android/app/build.gradle.kts`** — add to plugins block:
```kotlin
id("com.google.gms.google-services")
```

### 1.3 Register iOS Apps

For each project, register an iOS app:

| Flavor | Bundle ID |
|--------|-----------|
| dev | `space.sookoon.crewpoint.dev` |
| stg | `space.sookoon.crewpoint.stg` |
| prod | `space.sookoon.crewpoint.app` |

1. Download `GoogleService-Info.plist` for each
2. Place them (we'll reference in Xcode build phases):

```
ios/config/dev/GoogleService-Info.plist
ios/config/stg/GoogleService-Info.plist
ios/config/prod/GoogleService-Info.plist
```

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

Add a **Run Script** build phase to copy the correct plist per flavor:

1. Select **Runner** target → **Build Phases**
2. Click **+** → **New Run Script Phase**
3. Name it "Copy GoogleService-Info.plist"
4. Move it **above** "Copy Bundle Resources"
5. Paste this script:

```bash
# Determine flavor from bundle identifier
PLIST_SOURCE=""
if [[ "${PRODUCT_BUNDLE_IDENTIFIER}" == *".dev" ]]; then
  PLIST_SOURCE="${PROJECT_DIR}/config/dev/GoogleService-Info.plist"
elif [[ "${PRODUCT_BUNDLE_IDENTIFIER}" == *".stg" ]]; then
  PLIST_SOURCE="${PROJECT_DIR}/config/stg/GoogleService-Info.plist"
else
  PLIST_SOURCE="${PROJECT_DIR}/config/prod/GoogleService-Info.plist"
fi

cp "${PLIST_SOURCE}" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
```

### 2.5 Configure Apple Sign-In

1. In the Apple Developer Portal, create App IDs for all 3 bundle identifiers
2. Enable **Sign in with Apple** capability for each
3. In Xcode: **Runner** target → **Signing & Capabilities** → **+ Capability** → **Sign in with Apple**

---

## 3. Environment Variables & Envied Setup

### 3.1 Populate .env Files

Get the values from Firebase Console → Project Settings → General:

**`.env.dev`**:
```
FIREBASE_API_KEY=AIza...your-dev-key
FIREBASE_APP_ID=1:123456789:ios:abc123
FIREBASE_MESSAGING_SENDER_ID=123456789
FIREBASE_PROJECT_ID=crewpoint-dev
```

Repeat for `.env.stg` and `.env.prod` with their respective values.

### 3.2 Activate Envied

1. Copy the appropriate `.env.{flavor}` to `.env`:
   ```bash
   cp .env.dev .env
   ```

2. Uncomment the envied code in `lib/app/core/env/env.dart`:
   - Remove the placeholder `Env` class
   - Uncomment the `@Envied` annotated class

3. Generate the obfuscated Dart file:
   ```bash
   dart run build_runner build -d
   ```

4. Verify `lib/app/core/env/env.g.dart` was created

### 3.3 Per-Flavor Env Switching

For CI or local development, create a script:

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

Deploy these rules to each Firebase project:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Events collection
    match /events/{eventId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
      
      // Messages subcollection
      match /messages/{messageId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null 
          && request.resource.data.senderId == request.auth.uid;
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

Deploy via Firebase CLI:
```bash
firebase deploy --only firestore:rules --project crewpoint-dev
```

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
- [ ] App displays cached data with airplane mode enabled (offline-first)
- [ ] `flutter build apk --flavor prod` produces signed APK
- [ ] `flutter build ios --flavor prod` produces archive

---

## 10. Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| `google-services.json` not found | Ensure file is in `android/app/src/{flavor}/` directory |
| iOS build fails with bundle ID mismatch | Verify xcconfig `PRODUCT_BUNDLE_IDENTIFIER` matches scheme |
| Envied `_Env` not found | Run `dart run build_runner build -d` after `.env` changes |
| Google Sign-In cancelled immediately | Add SHA-1 to Firebase Console (Android) |
| Apple Sign-In capability missing | Add in Xcode + Apple Developer Portal |
| Drift migration error | Increment `schemaVersion` in `app_database.dart` |
| Flavor not recognized by Flutter | Use exact names: `dev`, `stg`, `prod` (lowercase) |
