## Overview

Generate per-flavor app icons with DEV/STG ribbon badges overlaid on the base icon. Use a Dart script + `image` package to composite the badges, then `flutter_launcher_icons` to generate all platform sizes.

## Context

- **Base icon**: `assets/icons/launcher_icon.png` (1024x1024 RGBA)
- **Prod**: uses base icon as-is
- **Dev/Stg**: base icon + diagonal ribbon badge in bottom-left corner
- **flutter_launcher_icons**: not yet in pubspec; needs adding
- **Badge approach**: Dart CLI script using `image` package draws colored ribbon + white text overlay on base PNG, outputs `launcher_icon_dev.png` and `launcher_icon_stg.png`

## Plan

### Phase 1: Generate Badged Icons + Configure Launcher Icons

- **Goal**: Create DEV/STG badged icons and generate all platform sizes
- [x] Add `flutter_launcher_icons` to dev_dependencies in `pubspec.yaml`
- [x] Create `scripts/generate_flavor_icons.dart` — Dart script that:
  - Loads `assets/icons/launcher_icon.png`
  - Draws a colored diagonal ribbon badge in bottom-left:
    - DEV: orange ribbon with "DEV" text
    - STG: blue ribbon with "STG" text
  - Saves to `assets/icons/launcher_icon_dev.png` and `assets/icons/launcher_icon_stg.png`
- [x] Run the script: `dart run scripts/generate_flavor_icons.dart`
- [x] Create `flutter_launcher_icons.yaml` with per-flavor config:
  - default (prod): `assets/icons/launcher_icon.png`
  - dev: `assets/icons/launcher_icon_dev.png`
  - stg: `assets/icons/launcher_icon_stg.png`
- [x] Run `dart run flutter_launcher_icons`
- [x] Verify: icons generated in `android/app/src/*/res/` and `ios/Runner/Assets.xcassets/`
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `image` package text rendering is basic — ribbon approach (colored rectangle + text) gives clean results vs trying to render fancy fonts
- **Out of scope**: Adaptive icons for Android 13+ (can be added later)
