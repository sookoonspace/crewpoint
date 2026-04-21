## Overview

Wire up per-flavor native Firebase config files (`google-services.json` / `GoogleService-Info.plist`) and activate the generated Dart options in `firebase_service.dart`. Currently only one native file exists (prod); each flavor needs its own.

## Context

- **Generated Dart files**: `lib/firebase_options_dev.dart`, `_stg.dart`, `_prod.dart` — contain all per-platform keys, work correctly
- **Problem**: `flutterfire configure` overwrites the single `google-services.json` and `GoogleService-Info.plist` each time — only prod's files survive
- **Android flavors**: Gradle automatically picks `android/app/src/{flavor}/google-services.json` if present
- **iOS flavors**: Requires a build-phase script to copy the right plist based on build config (Xcode has no native flavor→file mapping)
- **firebase_service.dart**: Still uses placeholder `FirebaseOptions`; needs to import generated Dart files
- **firebase.json**: Already updated by flutterfire CLI with all flavor mappings

## Plan

### Phase 1: Android Per-Flavor google-services.json

- **Goal**: Each Android flavor gets its own `google-services.json`
- [ ] Run `flutterfire configure` three times with `--platforms=android` to capture each file:
  - `flutterfire configure --project=crewpoint-dev --out=lib/firebase_options_dev.dart --platforms=android --android-package-name=space.sookoon.crewpoint.dev --yes`
  - Move `android/app/google-services.json` → `android/app/src/dev/google-services.json`
  - Repeat for stg (`--project=crewpoint-stg`, `--android-package-name=space.sookoon.crewpoint.stg`) → `android/app/src/stg/google-services.json`
  - Repeat for prod (`--project=crewpoint-prod`, `--android-package-name=space.sookoon.crewpoint.app`) → `android/app/src/prod/google-services.json`
- [ ] Remove `android/app/google-services.json` from root (it should only exist in flavor dirs)
- [ ] Verify: `flutter build apk --flavor dev` and `flutter build apk --flavor prod` both resolve correct google-services

### Phase 2: iOS Per-Flavor GoogleService-Info.plist

- **Goal**: Each iOS flavor gets the correct plist at build time
- [ ] Capture each flavor's plist:
  - `flutterfire configure --project=crewpoint-dev --out=lib/firebase_options_dev.dart --platforms=ios --ios-bundle-id=space.sookoon.crewpoint.dev --yes`
  - Copy `ios/Runner/GoogleService-Info.plist` → `ios/Runner/Firebase/dev/GoogleService-Info.plist`
  - Repeat for stg → `ios/Runner/Firebase/stg/GoogleService-Info.plist`
  - Repeat for prod → `ios/Runner/Firebase/prod/GoogleService-Info.plist`
- [ ] Add Xcode Run Script build phase to copy correct plist:
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
- [ ] Update `ai_specs/setup-guide.md` Section 2 to re-add the plist copy phase with the new paths
- [ ] Verify: `flutter build ios --flavor dev` picks up dev plist

### Phase 3: Activate Dart Firebase Options

- **Goal**: Replace placeholder in `firebase_service.dart` with real generated imports
- [ ] `lib/app/core/services/firebase_service.dart` — import all three generated files; select by `AppFlavor`:
  ```dart
  import 'package:crewpoint_app/firebase_options_dev.dart' as dev;
  import 'package:crewpoint_app/firebase_options_stg.dart' as stg;
  import 'package:crewpoint_app/firebase_options_prod.dart' as prod;

  final options = switch (flavor) {
    AppFlavor.dev => dev.DefaultFirebaseOptions.currentPlatform,
    AppFlavor.stg => stg.DefaultFirebaseOptions.currentPlatform,
    AppFlavor.prod => prod.DefaultFirebaseOptions.currentPlatform,
  };
  await Firebase.initializeApp(options: options);
  ```
- [ ] Remove placeholder `FirebaseOptions` block and TODO comment
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 4: Update Setup Guide

- **Goal**: Guide reflects actual working approach
- [ ] `ai_specs/setup-guide.md` — Update Section 1.3 to document the capture-and-move workflow for native files
- [ ] `ai_specs/setup-guide.md` — Re-add Section 2.4 (plist copy phase) with `ios/Runner/Firebase/{flavor}/` paths
- [ ] `ai_specs/setup-guide.md` — Note that Android uses `android/app/src/{flavor}/google-services.json` (Gradle handles it automatically)
- [ ] `ai_specs/setup-guide.md` — Update Section 10 (Common Issues) for new file paths

## Risks / Out of scope

- **Risks**:
  - Re-running `flutterfire configure` will overwrite the Dart options files and the root-level native files — document this caveat in the guide
  - iOS plist copy script must run before "Copy Bundle Resources" phase
- **Out of scope**:
  - Web flavor config (single project works for web)
  - Automated flutterfire capture script (could be a follow-up)
