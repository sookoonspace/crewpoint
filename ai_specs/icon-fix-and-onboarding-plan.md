## Overview

Fix iOS flavor icons (pbxproj override) + redesign onboarding to 5 modern, concise screens using CrewPoint's charcoal/sage/terracotta palette with bold icons and minimal text.

## Context

- **Icon bug**: `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` hardcoded in `project.pbxproj` for every build config — overrides xcconfig values (`AppIcon-dev`, `AppIcon-stg`). Same pattern as prior bundle ID fix.
- **Current onboarding**: 3 pages with placeholder circle + generic icon. Needs: 5 pages, modern feel, all-ages appeal, straight-to-the-point.
- **Color palette**: charcoal (#2D3436), sage (#6B9080), sageLight (#A4C3B2), terracotta (#CC704B), offWhite (#F8F9FA)
- **Existing widgets**: `PrimaryButton`, `AppSpacing`, `AppColors`, `AppRadius`
- **Reference**: `lib/app/features/onboarding/presentation/onboarding_screen.dart`

## Plan

### Phase 1: Fix iOS Flavor Icon Override

- **Goal**: Remove hardcoded `ASSETCATALOG_COMPILER_APPICON_NAME` from pbxproj so xcconfig takes effect
- [ ] `ios/Runner.xcodeproj/project.pbxproj` — Remove all `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;` lines from build configuration sections (xcconfig will provide per-flavor value)
- [ ] Verify: clean build in Xcode uses correct flavor icon

### Phase 2: Redesign Onboarding Screens

- **Goal**: 5 modern, concise onboarding pages with CrewPoint branding + data opt-in on final page
- [ ] `lib/app/features/onboarding/presentation/onboarding_screen.dart` — Rewrite with 5 pages:
  - Page 1: **Welcome** — App logo/name, tagline "Your crew, organized." Dark charcoal background, sage accent
  - Page 2: **Events** — Calendar icon, "Plan events together. Assign roles, set dates, track progress." 
  - Page 3: **Chat** — Chat icon, "Stay in sync. Real-time messaging with critical alerts when it matters."
  - Page 4: **Budget** — Wallet icon, "Split costs fairly. Track expenses, receipts, and who owes what."
  - Page 5: **Privacy** — Shield icon, "Your data, your rules." + Data collection opt-in toggle (default OFF) + Get Started button
- [ ] Design: Full-bleed colored backgrounds alternating charcoal/offWhite; large Material icon (120px) centered; headline + 1-line description; minimal text; smooth page transitions
- [ ] Keep: `_PageIndicator` (sage dots), `_DataOptInToggle` (last page only), `onComplete` callback
- [ ] Skip button on pages 1-4 (top-right) to jump to last page
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: Icon fix may need Xcode derived data clean (`Cmd+Shift+K`) after pbxproj change
- **Out of scope**: Lottie animations (can replace icons later when assets arrive), localization
