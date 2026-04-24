## Overview

Create a living Cloud Functions deployment guide + redesign Profile screen with Sookoon's premium visual language, edit flow, clean sign-out/delete UX, and placeholder Lottie animations throughout the app.

## Context

- **Functions**: `functions/src/account/deleteUserAccount.ts` + `utils/batch.ts`; needs comprehensive deployment guide for all 3 flavors with IAM setup
- **Profile**: Currently shows name/email + 3 list tiles. Needs: photo, edit mode, premium Sookoon styling, polished UX
- **Lottie**: `lottie` package in pubspec but no assets. Need animated placeholder JSON files
- **Existing**: `LoadingAnimation` widget uses `CircularProgressIndicator` fallback — will switch to Lottie
- **Design system**: Charcoal (#2D3436), sage (#6B9080), sageLight (#A4C3B2), terracotta (#CC704B), cream (#EADDCE), offWhite (#F8F9FA). Onboarding established alternating charcoal/cream full-bleed backgrounds as the brand language.

### Sookoon Visual Design Spec (Profile)

- **Scaffold background**: `AppColors.cream` — warm, premium feel (not cold offWhite)
- **Hero card**: Charcoal background with rounded bottom corners (`AppRadius.borderXxl`), contains centered avatar (sage ring, 56px radius), display name (white, headlineSmall), email (sageLight, bodyMedium), "Edit Profile" pill button (sage bg, white text)
- **Avatar**: Sage-bordered circle. When no photo: Lottie profile animation on charcoal. When photo: circular `ClipRRect` with image
- **Section cards**: White `Card` with `AppRadius.borderLg`, slight elevation (1), on cream background. Grouped tiles inside with `ListTile` + leading icons in charcoal
- **Section headers**: bodySmall, `AppColors.darkGrey`, uppercase, `AppSpacing.lg` padding above
- **Danger zone**: "Delete Account" tile isolated in its own card with a subtle terracotta-tinted border, terracotta text + icon. Separated from other sections by `AppSpacing.xxl`
- **Sign-out tile**: Normal styling in Account section (not destructive colors)
- **App version**: Small centered text at bottom, `AppColors.mediumGrey`, `bodySmall`

### Firestore User Document Schema

```
users/{uid}:
  displayName: string
  email: string
  photoUrl: string | null       // Firebase Storage path: users/{uid}/profile.jpg
  createdAt: timestamp
  updatedAt: timestamp
  preferences:
    dataOptIn: boolean           // From onboarding opt-in toggle
```

## Plan

### Phase 1: Lottie Placeholder Assets

- **Goal**: Create minimal animated Lottie JSON files (1s looping) that can be swapped with real animations later
- [x] `assets/animations/loading.json` — Rotating circle, 1s loop, sage color
- [x] `assets/animations/success.json` — Scale-pulsing checkmark, 1s loop, sage color
- [x] `assets/animations/error.json` — Fading X mark, 1s loop, terracotta color
- [x] `assets/animations/empty_state.json` — Gentle bobbing empty box, 1s loop, mediumGrey
- [x] `assets/animations/profile.json` — Subtle breathing person icon, 1s loop, sageLight
- [x] `assets/animations/sign_out.json` — Wave/goodbye gesture, 1s loop, charcoal
- [x] `pubspec.yaml` — Register `assets/animations/` in flutter assets
- [x] `lib/app/core/widgets/loading_animation.dart` — Switch to `Lottie.asset()` with fallback
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Profile Screen Redesign

- **Goal**: Premium Sookoon-branded profile with edit flow, photo, polished sign-out/delete UX
- [x] `pubspec.yaml` — Added `package_info_plus`
- [x] `lib/app/features/profile/presentation/profile_screen.dart` — Full Sookoon redesign: charcoal hero card, sage avatar ring, cream bg, white section cards, terracotta danger zone, app version
- [x] `lib/app/features/profile/presentation/edit_profile_screen.dart` — Edit with photo upload, Lottie success, error snackbar
- [x] `lib/app/features/profile/presentation/widgets/sign_out_sheet.dart` — Confirmation with Lottie wave
- [x] `lib/app/features/profile/presentation/widgets/delete_account_dialog.dart` — Added Lottie success step (2s) before navigate
- [x] Wire edit profile route in `app_router.dart` (`/profile/edit`)
- [x] Tests updated for new profile structure
- [x] Verify: `flutter analyze` && `flutter test` — 47 tests, 0 warnings

### Phase 3: Cloud Functions Deployment Guide

- **Goal**: Comprehensive, living guide for deploying and managing Cloud Functions across all 3 flavors
- [ ] `docs/cloud-functions-guide.md` — Create with sections:
  - **Prerequisites**: Node 22, Firebase CLI, gcloud CLI, project access
  - **First-Time Setup (per project)**: Enable Cloud Build API, grant IAM roles:
    - `{PROJECT_NUMBER}@cloudbuild.gserviceaccount.com` → `roles/cloudbuild.builds.builder`
    - `{PROJECT_NUMBER}-compute@developer.gserviceaccount.com` → `roles/cloudfunctions.developer`
    - Exact `gcloud` commands for each role
  - **Deploying**: Per-flavor commands: `firebase deploy --only functions --project crewpoint-dev` (repeat for stg, prod)
  - **Verifying**: Check in Firebase Console → Functions tab; test with `firebase functions:shell`
  - **Function Registry**: Table of all functions — start with:

    | Function | Trigger | Module | Description | Added |
    |----------|---------|--------|-------------|-------|
    | `deleteUserAccount` | HTTPS Callable | `account/` | Server-side account deletion with anonymization | 2026-04-21 |

  - **Adding a New Function**: 1) Create `functions/src/{feature}/{name}.ts`, 2) Export from `index.ts`, 3) `npm run build`, 4) Deploy per-flavor
  - **Updating Existing Functions**: Edit code → `npm run build` → deploy — zero downtime (2nd gen)
  - **Rollback**: View versions in Cloud Console; redeploy previous commit
  - **Local Testing**: `firebase emulators:start --project crewpoint-dev`; configure Flutter app to use emulators
  - **Monitoring**: `firebase functions:log --project crewpoint-dev`; Cloud Console → Logs Explorer
  - **Troubleshooting**: IAM permission errors, Node version issues, timeout tuning (default 120s), 500-doc batch limits, memory allocation
- [ ] Verify: guide is complete, self-contained, and consistent with `firebase.json`

## Risks / Out of scope

- **Risks**: Lottie placeholders are simple shapes with basic animations — they'll feel placeholder-quality until real After Effects exports replace them. The file replacement is a drop-in swap (same filenames).
- **Out of scope**: Push notification functions, biometric re-auth, profile photo cropping/compression
