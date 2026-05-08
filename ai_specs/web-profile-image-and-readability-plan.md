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

### Phase 1: Bytes-based image-service migration (cross-platform vertical slice) ✓

- **Goal**: Single `IImageService` API consumes/uploads bytes; profile photo AND receipt upload work on web + native; zero `dart:io` in the migrated code.
- [x] TDD: `mimeTypeFor('photo.jpg') == 'image/jpeg'` (helper RED → GREEN)
- [x] TDD: `mimeTypeFor('photo.PNG') == 'image/png'` (case-insensitive)
- [x] TDD: `mimeTypeFor('weird') == 'image/jpeg'` (fallback)
- [x] TDD: `mimeTypeFor('') == 'image/jpeg'` (empty)
- [x] `lib/app/core/services/image_service.dart` — drop `dart:io` import; introduce `class PickedImage({bytes, filename, contentType})`; rewrite `IImageService` keeping method names (`pickFromGallery`, `takePhoto`) + parameter `storagePath`; signatures use `Uint8List` + `PickedImage`
- [~] TDD: `FirebaseImageService.uploadToStorage(...)` upload-side test deferred — coverage routed through `expense_repository_receipt_test.dart` (asserts bytes/path/contentType flow through the service to the `IImageService` boundary). Avoids adding `firebase_storage_mocks` mid-phase. Manual smoke covers the actual `putData` call.
- [x] TDD: `pickFromGallery` invokes underlying picker with `maxWidth: 512, maxHeight: 512, imageQuality: 85` (defaults) and returns `PickedImage` whose bytes = seeded XFile bytes; `contentType` resolved from `xfile.mimeType` when present
- [x] TDD: `pickFromGallery` derives contentType from filename extension when `xfile.mimeType` is null
- [x] TDD: `takePhoto` mirrors gallery slice (camera source)
- [x] `lib/app/core/services/firebase_image_service.dart` — drop `dart:io` import; add picker-function seam (`PickerFn`); implement bytes flow; `putData` not `putFile`; storage resolution made lazy so picker-only tests don't trip Firebase init
- [~] TDD: Edit profile widget MemoryImage preview test — covered structurally by the kIsWeb-safe `MemoryImage(_picked!.bytes)` swap; visual layout test deferred to manual smoke (existing `edit_profile_screen_layout_test.dart` doesn't exercise the picker path).
- [x] `lib/app/features/profile/presentation/edit_profile_screen.dart` — drop `dart:io` import; `File? _pickedImage` → `PickedImage? _picked`; `MemoryImage(_picked!.bytes)` for preview; pass bytes to upload; **deleted the `repo.getUser` + `authProvider.notifier.refreshUser` block** (currentUserDocProvider streams updates)
- [x] TDD: `ExpenseRepository.uploadReceipt(bytes:, contentType:, eventId:, expenseId:)` asserts bytes/path/contentType flow through to `IImageService.uploadToStorage` (regression-guarded by the updated `expense_repository_receipt_test.dart`)
- [x] `lib/app/features/budget/data/expense_repository.dart:119-143` — `uploadReceipt` signature changed: `File file` → `Uint8List bytes, String contentType`; passes through to `IImageService.uploadToStorage`
- [x] `lib/app/features/budget/presentation/widgets/expense_modal.dart` — typedefs `ExpenseSubmit = void Function(ExpenseModel, PickedImage?)` and `ReceiptPicker = Future<PickedImage?> Function()`; `_pickedReceipt` is `PickedImage?`; `_ReceiptRow` field renamed to `receipt` and uses `Image.memory(r.bytes)`
- [x] `lib/app/features/budget/presentation/event_budget_page.dart:307-329` — `pickFromGallery(maxWidth: 1600, maxHeight: 1600, quality: 70)` preserved; `onSubmit` adapts to `PickedImage`; `repo.uploadReceipt(...)` receives `bytes` + `contentType`
- [x] `test/app/features/budget/expense_repository_receipt_test.dart` — dropped `import 'dart:io'`; rewrote `_FakeImageService` for bytes-based interface; tests assert content-type + bytes round-trip
- [x] `test/app/features/budget/expense_modal_widget_test.dart` — dropped `import 'dart:io'`; replaced `File` paths with a stub `PickedImage` containing a 1×1 PNG so `Image.memory` decodes cleanly (no errorBuilder triggered)
- [x] Verify ZERO `dart:io` in scope: `grep -rn "import 'dart:io'" lib/app/core/services lib/app/features/profile lib/app/features/budget` returns nothing
- [x] Verify ZERO `Platform\.is` in scope (defensive): `grep -rn "Platform\.is" lib/app/core/services lib/app/features/profile lib/app/features/budget` returns nothing
- [x] Verify: `flutter analyze` clean; `flutter test` 269 passed

**Deviations from plan**:
- Service-layer `uploadToStorage` test deferred (no FirebaseStorage mock in pubspec). Coverage moved one layer up to `expense_repository_receipt_test.dart` which already exercises the same bytes→path→contentType contract via the `IImageService` interface. Manual web smoke verifies the `putData` call against real Storage.
- `MemoryImage` preview test deferred — the swap is structural (one-line) and the existing layout test doesn't exercise the picker. Covered by manual smoke.
- `FirebaseImageService` storage made lazy (getter, not field initializer) so picker-only tests don't trigger `FirebaseStorage.instance` resolution before Firebase init.

### Phase 2: Theme cascade + readability sweep ✓

- **Goal**: WCAG AA across all light-surface text by deleting `mediumGrey` / `lightGrey` overrides and letting theme cascade; lock with contrast unit test.
- [x] TDD: extended existing `test/app/core/constants/app_colors_contrast_test.dart` (codebase already had `wcag.dart` + `contrastRatio()` helper). Added 3 AA-passing pairs (charcoalLight on cream/offWhite/white) and 3 forbidden-pair regression locks (mediumGrey on cream/offWhite, lightGrey on cream).
- [x] `lib/app/core/theme/app_theme.dart` — added `onSurfaceVariant: AppColors.charcoalLight` to `ColorScheme.light(...)`; mirrored with `AppColors.lightGrey` on `ColorScheme.dark(...)`. Documented inline that charcoalLight on CREAM is 3.93:1 (passes large-text 3:1, fails body 4.5:1).
- [x] **Reality check (deviation from spec)**: `charcoalLight` on cream is **3.93:1**, NOT AA-safe. The spec assumed it would pass. So on cream surfaces, secondary text uses the default `onSurface` (charcoal) cascade — visual hierarchy comes from typography weight/size, not color. `onSurfaceVariant` is AA-safe on offWhite + white only. Forbidden-pair test locks mediumGrey/lightGrey from creeping back in.
- [x] `lib/app/features/dashboard/presentation/dashboard_screen.dart:80,86` — DELETED the `mediumGrey` overrides; theme cascades to charcoal.
- [x] `lib/app/features/profile/presentation/edit_profile_screen.dart` — DELETED the three `mediumGrey` text overrides ("Tap photo to change", "Optional — helps your crew settle up", "Used by Venmo/CashApp...").
- [x] `lib/app/features/profile/presentation/profile_screen.dart:353` — payment-card subtitle switched to `Theme.of(context).colorScheme.onSurfaceVariant`. App version footer override DELETED so theme cascades.
- [x] Sweep: `sed`-replaced 19 occurrences of `?.copyWith(color: AppColors.mediumGrey)` across 17 files → bare `textTheme.X` (theme cascade). Cleaned up the now-unused `AppColors` import in `auth_gate_screen.dart`. Files touched: app_router, task_tile, event_card, join_event_sheet, message_bubble, task_detail_screen, expense_modal, add_member_sheet, budget_screen, event_detail_screen, event_dashboard_screen, auth_gate_screen, privacy_dashboard_screen, sign_out_sheet, plus the named screens above.
- [x] Sweep `withValues(alpha:)` on text colors — verified ZERO text-color alpha uses; all alpha uses are background tints / shadows / borders (left untouched per spec).
- [x] Verify: `flutter analyze` clean; `flutter test` 275 passing (up from 269 — 6 new contrast tests).

**Deviation from plan**:
- Spec/plan assumed `charcoalLight` on cream would pass body AA. Test proved it's 3.93:1 (passes large-text 3.0, fails body 4.5). Adjusted strategy: on cream surfaces use `onSurface` (charcoal); reserve `onSurfaceVariant` for offWhite/white surfaces. The new theme cascade applies cleanly because the bulk of the app sits on `scaffoldBackgroundColor: offWhite` where `onSurfaceVariant` IS AA.

### Phase 3: Sign-out button redesign ✓

- **Goal**: Remove ACCOUNT section; standalone terracotta outlined Sign Out button between Payment and Danger Zone.
- [x] TDD: profile screen no longer renders the "ACCOUNT" section header label (assert `find.text('ACCOUNT')` returns nothing) — RED → GREEN by deleting the ACCOUNT block
- [x] TDD: profile screen contains exactly one `OutlinedButton.icon` whose label `Text` reads "Sign Out"; verified via stable `Key('profile.signOut.button')`
- [x] TDD: Sign Out button renders between PAYMENT header and Danger Zone Delete-Account tile (vertical-position assertion at a tall viewport so lazy slivers materialize the full body)
- [x] TDD: tapping the new button surfaces `SignOutSheet` (asserted via the sheet's distinctive title "Sign out of CrewPoint?"; explicit pump beats `pumpAndSettle` here because the sheet's Lottie animation never settles)
- [x] `lib/app/features/profile/presentation/profile_screen.dart` — DELETED the `_SectionHeader('ACCOUNT')` + the `_SectionCard` block; inserted standalone `Padding(EdgeInsets.symmetric(horizontal: AppSpacing.xl), child: OutlinedButton.icon(key: Key('profile.signOut.button'), foregroundColor: AppColors.terracotta, side: BorderSide(color: AppColors.terracotta, width: 1.5), shape: StadiumBorder(), minimumSize: Size.fromHeight(48), icon: Icons.logout_rounded, label: 'Sign Out', onPressed: SignOutSheet.show))` between Payment and Danger Zone
- [x] Confirmed `app_colors.dart` UNCHANGED (no new red constants — `git diff` empty for that file)
- [x] Verify: `flutter analyze` clean; `flutter test` 279 passing (up from 275 — 4 new sign-out tests)
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
