# Web Profile-Image + Readability + Sign-Out — Plan

## Overview

Three coordinated fixes: bytes-based image upload (web compat), readability sweep via theme cascade, sign-out button redesign. Strict TDD vertical slices.

**Spec**: `ai_specs/web-profile-image-and-readability-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first (`lib/app/features/{auth,profile,budget,...}/{domain,application,data,presentation}`)
- **State management**: Riverpod 3, `currentUserDocProvider` already streams `users/{uid}` (added in earlier branch commit)
- **Reference implementations**:
  - `lib/app/core/services/image_service.dart` — current `IImageService` interface (File-based)
  - `lib/app/core/services/firebase_image_service.dart` — current impl using `putFile`
  - `lib/app/features/profile/presentation/edit_profile_screen.dart:115-140` — profile-photo consumer
  - `lib/app/features/budget/data/expense_repository.dart:120-142` — receipt-upload consumer (also needs migration)
  - `lib/app/features/budget/presentation/event_budget_page.dart:307-329` — receipt picker call site
  - `lib/app/features/budget/presentation/widgets/expense_modal.dart:14-17,38,101,141,236` — `ExpenseSubmit` + `ReceiptPicker` typedefs to update
  - `test/app/features/budget/expense_repository_receipt_test.dart:17-46` — only existing `_FakeImageService`
  - `lib/app/core/theme/app_theme.dart` — already sets `onSurface: charcoal`; needs `onSurfaceVariant: charcoalLight` added
  - `lib/app/core/constants/app_colors.dart:37` — `error = terracotta` already exists; do NOT add new red
  - `lib/app/features/profile/presentation/profile_screen.dart:79-93` — ACCOUNT section to delete; `_DangerCard` at line 97
- **Assumptions/Gaps**:
  - Spec listed `edit_profile_screen_layout_test.dart` / `delete_account_dialog_test.dart` / `profile_test.dart` as fakes-to-update; grep shows ONLY `expense_repository_receipt_test.dart:17` actually implements `IImageService`. Those other tests don't override `imageServiceProvider`.
  - **Receipt upload (budget feature) shares `IImageService`** — Phase 1 MUST migrate it too, else `flutter analyze` breaks. Spec under-scoped this; plan expands Phase 1 accordingly.
  - Receipt picker uses `maxWidth: 1600, maxHeight: 1600, quality: 70` — preserve those at the call site.
  - **CRITICAL RULE (per task input):** zero `dart:io` references must remain in `image_service.dart`, `firebase_image_service.dart`, or `edit_profile_screen.dart`. Current scope contains 3 `dart:io` imports (those three files) and ZERO `Platform.isX` calls — so removal is straightforward; no `kIsWeb` / `defaultTargetPlatform` substitution needed. If `Platform.isX` ever appears, replace with `kIsWeb` from `package:flutter/foundation.dart`.

## Plan

### Phase 1: Bytes-based image-service migration (cross-platform vertical slice)

- **Goal**: Single `IImageService` API consumes/uploads bytes; profile photo AND receipt upload work on web + native; zero `dart:io` in the migrated code.
- [ ] TDD: `mimeTypeFor('photo.jpg') == 'image/jpeg'` (helper RED → GREEN)
- [ ] TDD: `mimeTypeFor('photo.PNG') == 'image/png'` (case-insensitive)
- [ ] TDD: `mimeTypeFor('weird') == 'image/jpeg'` (fallback)
- [ ] TDD: `mimeTypeFor('') == 'image/jpeg'` (empty)
- [ ] `lib/app/core/services/image_service.dart` — drop `dart:io` import; introduce `class PickedImage({bytes, filename, contentType})`; rewrite `IImageService` keeping method names (`pickFromGallery`, `takePhoto`) + parameter `storagePath`; signatures use `Uint8List` + `PickedImage`
- [ ] TDD: `FirebaseImageService.uploadToStorage(bytes:, storagePath:, contentType:)` calls `ref.putData(bytes, SettableMetadata(contentType: ...))` and returns the download URL (use injectable `FirebaseStorage` seam + mock ref)
- [ ] TDD: `pickFromGallery` invokes underlying picker with `maxWidth: 512, maxHeight: 512, imageQuality: 85` (defaults) and returns `PickedImage` whose bytes = seeded XFile bytes; `contentType` resolved from `xfile.mimeType` when present
- [ ] TDD: `pickFromGallery` derives contentType from filename extension when `xfile.mimeType` is null
- [ ] TDD: `takePhoto` mirrors gallery slice (camera source)
- [ ] `lib/app/core/services/firebase_image_service.dart` — drop `dart:io` import; add picker-function seam (`Future<XFile?> Function(ImageSource, {int? maxWidth, int? maxHeight, int? imageQuality})? _pickerOverride`); implement bytes flow; `putData` not `putFile`
- [ ] TDD: Edit profile widget — picking sets `MemoryImage` preview containing the bytes
- [ ] TDD: Edit profile save invokes `IImageService.uploadToStorage` with bytes + `storagePath: 'users/${uid}/profile.jpg'` + `contentType`; does NOT call `repo.getUser` after save (regression guard)
- [ ] `lib/app/features/profile/presentation/edit_profile_screen.dart` — drop `dart:io` import; `File? _pickedImage` → `PickedImage? _picked`; `MemoryImage(_picked!.bytes)` for preview; pass bytes to upload; **delete the `repo.getUser` + `authProvider.notifier.refreshUser` block at lines 168-171** (currentUserDocProvider streams updates)
- [ ] TDD: `ExpenseRepository.uploadReceipt(bytes:, contentType:, eventId:, expenseId:)` calls `IImageService.uploadToStorage` with `storagePath: 'events/{eventId}/receipts/{expenseId}.jpg'`
- [ ] `lib/app/features/budget/data/expense_repository.dart:120-142` — change `uploadReceipt` signature: `File file` → `Uint8List bytes, String contentType`; pass through to `IImageService.uploadToStorage`
- [ ] `lib/app/features/budget/presentation/widgets/expense_modal.dart` — update typedefs `ExpenseSubmit = void Function(ExpenseModel, PickedImage?)` and `ReceiptPicker = Future<PickedImage?> Function()`; `File? _pickedReceipt` → `PickedImage? _pickedReceipt`; `final File? file` field on the receipt-tile child widget → `PickedImage?`
- [ ] `lib/app/features/budget/presentation/event_budget_page.dart:307-329` — `pickFromGallery(maxWidth: 1600, maxHeight: 1600, quality: 70)` keeps these args; `onSubmit` callback adapts to `PickedImage`; `repo.uploadReceipt(eventId, expenseId, bytes: receipt.bytes, contentType: receipt.contentType)`
- [ ] `test/app/features/budget/expense_repository_receipt_test.dart:1,17-46` — drop `import 'dart:io'`; rewrite `_FakeImageService` to implement the new bytes-based interface; update test cases that pass `File` → pass bytes
- [ ] Verify ZERO `dart:io` in scope: `grep -rn "import 'dart:io'" lib/app/core/services lib/app/features/profile lib/app/features/budget` returns nothing
- [ ] Verify ZERO `Platform\.is` in scope (defensive): `grep -rn "Platform\.is" lib/app/core/services lib/app/features/profile lib/app/features/budget` returns nothing
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Theme cascade + readability sweep

- **Goal**: WCAG AA across all light-surface text by deleting `mediumGrey` / `lightGrey` overrides and letting theme cascade; lock with contrast unit test.
- [ ] TDD: new `test/app/core/constants/app_colors_contrast_test.dart` — `Color.computeLuminance` ratio assertions: `cream` ↔ `charcoal` ≥ 4.5; `cream` ↔ `charcoalLight` ≥ 4.5; `offWhite` ↔ `charcoal` ≥ 4.5; `offWhite` ↔ `charcoalLight` ≥ 4.5; **negative**: `cream` ↔ `mediumGrey` < 4.5
- [ ] `lib/app/core/theme/app_theme.dart` — add `onSurfaceVariant: AppColors.charcoalLight` to `ColorScheme.light(...)`; mirror with `AppColors.lightGrey` on `ColorScheme.dark(...)` for parity
- [ ] TDD: `Theme.of(context).colorScheme.onSurfaceVariant == AppColors.charcoalLight` (small widget test)
- [ ] TDD: dashboard empty-state text widgets resolve effective text color to a non-`mediumGrey` AA-safe theme color (regression guard)
- [ ] `lib/app/features/dashboard/presentation/dashboard_screen.dart:80,86` — DELETE the `.copyWith(color: AppColors.mediumGrey)` overrides; theme cascades
- [ ] TDD: edit-profile helper text widgets (lines 332, 371) resolve to AA-safe theme color
- [ ] `lib/app/features/profile/presentation/edit_profile_screen.dart:332,371` — DELETE the `mediumGrey` overrides
- [ ] TDD: profile payment subtitle resolves to `colorScheme.onSurfaceVariant` (intentional secondary tone)
- [ ] `lib/app/features/profile/presentation/profile_screen.dart:353` — switch payment subtitle to `Theme.of(context).colorScheme.onSurfaceVariant`; section-header all-caps labels using `mediumGrey` → switch to `onSurfaceVariant`
- [ ] Sweep remaining hits: `grep -rn "AppColors.mediumGrey\\|AppColors.lightGrey" lib/`; for each TEXT use on cream/offWhite/white, DELETE first (theme cascade) or fall back to `onSurfaceVariant`; LEAVE icons/borders/dividers alone; LEAVE charcoal/dark-surface uses alone
- [ ] Sweep `withValues(alpha:` / `withOpacity(` on text colors; bump to ≥0.85 or drop alpha
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Sign-out button redesign

- **Goal**: Remove ACCOUNT section; standalone terracotta outlined Sign Out button between Payment and Danger Zone.
- [ ] TDD: profile screen no longer contains an `_SectionHeader(label: 'ACCOUNT')` or its `_SectionCard`
- [ ] TDD: profile screen contains exactly one `OutlinedButton.icon` whose label `Text` reads "Sign Out"
- [ ] TDD: tapping the new button surfaces `SignOutSheet` in the widget tree
- [ ] `lib/app/features/profile/presentation/profile_screen.dart:79-93` — DELETE the `_SectionHeader('ACCOUNT')` + the surrounding `SizedBox(height: AppSpacing.sm)` + the `_SectionCard` containing the sign-out tile (and the trailing `SizedBox(height: AppSpacing.xl)` if redundant); insert at that position a `Padding(EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xl), child: OutlinedButton.icon(...))` with foreground + 1.5px border `AppColors.terracotta`, `StadiumBorder`, `Size.fromHeight(48)`, icon `Icons.logout_rounded`, label "Sign Out", onPressed reusing `SignOutSheet.show(context: context, onSignOut: () => ref.read(authProvider.notifier).signOut())`
- [ ] Confirm `app_colors.dart` UNCHANGED (no new red constants)
- [ ] Verify: `flutter analyze` && `flutter test`
- [ ] Manual smoke (deploy + load on Safari/Chrome): pick + save profile photo; visit Dashboard / Profile / Edit Profile / Create Event — all text readable; new Sign Out button visible between Payment and Danger Zone, tap → confirmation sheet → signed out

## Risks / Out of scope

- **Risks**:
  - Receipt-upload migration (added to Phase 1 scope) may break `expense_modal_test.dart` or related widget tests not yet enumerated; address inline if so. Mitigation: keep the typedef rename together with the call-site change in a single TDD slice.
  - `image_picker_for_web` may not honor `maxWidth/maxHeight/quality` exactly the same as native; bytes returned could be larger than expected on desktop browsers. Acceptable for V1; flag if Storage uploads consistently exceed ~2MB.
  - Theme cascade changes might shift contrast on dark-mode screens not currently covered by tests; visually inspect after Phase 2.
- **Out of scope**:
  - Image compression / client-side resize beyond the picker's existing quality/dimensions params
  - Drag-and-drop or paste-image input on web
  - Cream → white surface change (brand stays)
  - Modifying `SignOutSheet` (`widgets/sign_out_sheet.dart`)
  - Dark-mode-specific contrast adjustments beyond mirroring `onSurfaceVariant`
  - Replacing `darkGrey` (alias of `charcoalLight`) on cream — already AA, keep
