<goal>
Three coordinated fixes for gaps observed on the web build (deployed at `crewpoint-dev.web.app`):

1. **Profile image save is broken on web.** `FirebaseImageService` casts `XFile.path` to `dart:io File` and uploads via `putFile(file)`. On web, `XFile.path` is a Blob URL that cannot be opened as a `File`, so the upload throws and the user's avatar update silently fails. Refactor the image-upload contract to be bytes-based so a single code path works on web, iOS, and Android.

2. **Text contrast is unreadable on multiple screens.** Body text frequently uses `AppColors.mediumGrey` / `lightGrey` (or `withValues(alpha: <1)`) on light surfaces, falling below WCAG AA (4.5:1). The user reports profile, edit profile, dashboard, and create event as the worst offenders, but the issue is project-wide — sweep the codebase, not just those screens. The relevant light surfaces are **cream** (`#EADDCE`, used by dashboard / profile / edit-profile / create-event), **offWhite** (`#F8F9FA`, the default `scaffoldBackgroundColor` per `app_theme.dart:27`), and **white** (cards). The current overrides bypass the theme — the theme already cascades correctly when not overridden.

3. **Sign Out button needs a clearer destructive-action affordance.** Currently a row inside the ACCOUNT `_SectionCard` with the same charcoal styling as Privacy / Notifications, so it doesn't read as a terminal action. Promote it to a standalone full-width outlined button with terracotta tint placed between the Payment section and the Danger Zone.

**Who benefits:** every web user (the photo upload bug is an outright failure), every user across platforms (readability + sign-out clarity).

**Brand constraint:** the existing palette (cream, offWhite, white surfaces; charcoal/charcoalLight text; sage accent; terracotta destructive) stays. Only text-color overrides and the sign-out element change. No new color constants are introduced.
</goal>

<background>
**Tech stack:**
- Flutter `^3.11.5`, Riverpod 3
- `firebase_storage: ^12.4.4`, `image_picker: ^1.1.2`
- Web build: CanvasKit renderer, deployed via Firebase Hosting (`*.web.app`)

**Files to examine before implementing:**
- `@lib/app/core/services/image_service.dart` — `IImageService` interface (currently returns `Future<File?>` — the type-level smoking gun)
- `@lib/app/core/services/firebase_image_service.dart` — concrete impl using `dart:io File` and `putFile` (lines 30, 50, 64)
- `@lib/app/features/profile/presentation/edit_profile_screen.dart` — UI usage (`File? _pickedImage` line 32, `FileImage(_pickedImage!)` line 286, `imageService.uploadToStorage(...)` line 138-140)
- `@lib/app/core/constants/app_colors.dart` — the palette (`cream`, `charcoal`, `charcoalLight`, `mediumGrey`, `lightGrey`, etc.)
- `@lib/app/core/theme/app_theme.dart` — Material 3 theme; default text colors
- `@lib/app/features/dashboard/presentation/dashboard_screen.dart` — `mediumGrey` on cream at lines 80, 86
- `@lib/app/features/profile/presentation/profile_screen.dart` — sign-out tile at lines 83-92; payment subtitle `mediumGrey` at line 353
- `@lib/app/features/profile/presentation/widgets/sign_out_sheet.dart` — confirmation modal (do NOT change behavior)
- `@lib/app/features/events/` — create-event screen(s) (audit pass)
- `@lib/app/core/constants/breakpoints.dart` — already responsive; no layout changes needed

**Relevant constraints:**
- The web upload must use `Reference.putData(bytes, SettableMetadata(contentType: ...))` (works on every platform). `putFile` is mobile/desktop-only.
- Drop `dart:io` from any file that is reachable from the web entry point; use conditional imports only if absolutely necessary (current cleanest path is to remove `dart:io` entirely from the image service since `putData` doesn't need it).
- The picker MUST keep its existing resize+quality settings (`maxWidth: 512`, `maxHeight: 512`, `quality: 85`) so we don't read multi-megabyte bytes on desktop browsers. `XFile.readAsBytes()` runs *after* `image_picker` has already done the downscale.
- WCAG AA minimum: 4.5:1 contrast for body text, 3:1 for large text (≥18pt regular or ≥14pt bold). Aim for AA across all body text; AAA (7:1) on heroes.
- Existing hero card on profile screen (offWhite text on charcoal gradient) is fine — leave it alone.
- Existing sign-out confirmation sheet (`SignOutSheet.show`) unchanged — it already has good contrast and a clear destructive button.
- `AppColors.error` / `AppColors.terracotta` (`#CC704B`) already exists as the canonical destructive-action color. Do not introduce a new red.
</background>

<user_flows>
**Primary flow — update profile photo on web:**
1. User on `crewpoint-dev.web.app` opens Edit Profile.
2. Taps avatar → bottom sheet with "Take photo" / "Pick from gallery".
3. Selects gallery → browser file picker opens → user selects JPEG/PNG.
4. `image_picker` returns `XFile`; we read its bytes with `XFile.readAsBytes()`.
5. Avatar preview shows the picked bytes via `MemoryImage(bytes)`.
6. User taps Save → `imageService.uploadToStorage(bytes: ..., path: 'users/{uid}/profile.jpg', contentType: 'image/jpeg')` → returns the download URL.
7. `userRepository.saveProfile(photoUrl: url, ...)` writes to Firestore public doc.
8. `currentUserDocProvider` re-emits → profile screen shows new avatar; success snackbar.

**Primary flow — update profile photo on iOS/Android:** same code path now. `XFile.readAsBytes()` works identically; `putData` works identically; `MemoryImage` works identically. No platform branching.

**Sign-out flow:**
1. User scrolls to bottom of profile screen.
2. Sees a clearly-distinct red **Sign Out** outlined button (full-width inside `ContentMaxWidth`, generous vertical padding, red border + red text).
3. Taps → existing `SignOutSheet.show` modal appears with Cancel / Sign Out actions.
4. Confirms → signed out; router redirects to auth gate.

**Readability flow (every screen):**
- Any body/secondary text the user reads renders at ≥4.5:1 contrast against its container background.
- Helper text ("Tap photo to change", "Optional — helps your crew settle up", empty-state descriptions) all readable without strain.
- Section-header all-caps labels ("SETTINGS", "PAYMENT", "ACCOUNT") still read as quiet but pass AA.

**Error flows:**
- **Image upload network failure:** picked-bytes preview retained; existing snackbar shows the error; user can retry without re-picking.
- **Image too large** (file picker may surface huge images on desktop): out of scope for this spec, but note in implementation that `XFile.length()` is available if size validation becomes needed later.
- **User picks an unsupported file type** (e.g., HEIC on web): browsers usually filter to selected `accept` types; if HEIC slips through, the upload's `contentType` defaults to `image/jpeg` and Storage accepts the bytes anyway — display path doesn't crash but might not render. Acceptable; flag as known limitation.
</user_flows>

<requirements>
**Functional — Image upload (Phase 1):**

1. `IImageService` (in `lib/app/core/services/image_service.dart`) MUST drop `Future<File?>` return types. Replace with bytes-based API. KEEP existing method names (`pickFromGallery`, `takePhoto`) and the existing `storagePath` parameter name to minimize churn across call sites and tests:
   ```dart
   abstract class IImageService {
     /// Pick from gallery; returns null on cancel. Bytes are already
     /// downscaled to maxWidth/maxHeight by the underlying picker.
     Future<PickedImage?> pickFromGallery({
       int maxWidth = 512,
       int maxHeight = 512,
       int quality = 85,
     });
     /// Capture from camera; returns null on cancel.
     Future<PickedImage?> takePhoto({
       int maxWidth = 512,
       int maxHeight = 512,
       int quality = 85,
     });
     /// Upload [bytes] to Firebase Storage at [storagePath]; returns the
     /// download URL.
     Future<String> uploadToStorage({
       required Uint8List bytes,
       required String storagePath,
       required String contentType,
     });
   }
   class PickedImage {
     const PickedImage({required this.bytes, required this.filename, required this.contentType});
     final Uint8List bytes;
     final String filename;
     final String contentType;
   }
   ```

2. `FirebaseImageService` MUST:
   - Drop the `import 'dart:io'` line.
   - Implement `pickFromGallery` / `takePhoto` by calling `image_picker` with the same `maxWidth` / `maxHeight` / `imageQuality` it already passes (defaults `512` / `512` / `85`), then `await xfile.readAsBytes()`, then resolving `contentType` from `xfile.mimeType` if non-null else from filename extension (`.jpg`/`.jpeg` → `image/jpeg`, `.png` → `image/png`, fallback `image/jpeg`).
   - Implement `uploadToStorage` using `ref.putData(bytes, SettableMetadata(contentType: contentType))`. No `putFile`. No `File` references.

3. `EditProfileScreen`:
   - Drop `import 'dart:io'`.
   - Replace `File? _pickedImage` state with `PickedImage? _picked` (or `Uint8List? _pickedBytes` + `String? _pickedFilename` + `String? _pickedContentType`).
   - Replace `FileImage(_pickedImage!)` in the `CircleAvatar` preview with `MemoryImage(_picked!.bytes)`.
   - On save, pass `bytes` + `storagePath: 'users/${user.uid}/profile.jpg'` + `contentType` to `imageService.uploadToStorage(...)`.
   - DELETE the redundant `repo.getUser(user.uid)` + `authProvider.notifier.refreshUser(updatedUser)` block at the end of `_save` (currently `edit_profile_screen.dart:168-171`). The existing `currentUserDocProvider` (added in the prior commit) auto-emits the new `photoUrl` via Firestore snapshot, so manual refresh is redundant.

4. The image bottom sheet's "Take photo" path on web MUST work or degrade gracefully. `image_picker_for_web` supports `ImageSource.camera` via `<input capture>` on supported browsers; on unsupported, it falls through to gallery. Acceptable for V1.

**Functional — Readability sweep (Phase 2):**

5. Every screen-rendered text MUST meet WCAG AA (4.5:1) against its actual visible background. Hero/large text (≥18pt) may use 3:1.

6. Theme cascade fix (do this FIRST so subsequent sweeps inherit good defaults):
   - In `lib/app/core/theme/app_theme.dart`, the light `ColorScheme.light(...)` block already sets `onSurface: AppColors.charcoal`. ADD `onSurfaceVariant: AppColors.charcoalLight` to it. Optionally also set `onSurfaceVariant` on `ColorScheme.dark(...)` to `AppColors.lightGrey` for parity.

7. **Default rule for the sweep — prefer DELETION over REPLACEMENT.** For every `Theme.of(context).textTheme.X.copyWith(color: AppColors.mediumGrey | lightGrey)` on a light surface (cream, offWhite, or white):
   - **First choice: DELETE the `copyWith(color: ...)` entirely.** The theme's `onSurface` (charcoal) cascades through `textTheme` and gives correct AA contrast. Less code, future-proof.
   - **Fallback (only when the design genuinely wants a quieter secondary tone):** Replace with `Theme.of(context).colorScheme.onSurfaceVariant` (which now resolves to `charcoalLight`).
   - **Avoid hard-coding `AppColors.charcoal` / `charcoalLight` directly** unless the widget is already off-theme (e.g., the hero card on the charcoal gradient).
   - On charcoal/dark surfaces, KEEP `lightGrey` / `mediumGrey` — they're AA there. Don't touch.

8. Apply rule #7 specifically to (and verify the fix visually):
   - `dashboard_screen.dart` lines 75, 80, 86 — empty state icon (`lightGrey`) is fine as-is on cream because it's an icon not text; the two `mediumGrey` text overrides should be DELETED so theme takes over.
   - `edit_profile_screen.dart` lines 332, 371 — helper text on cream → DELETE the override; let theme cascade.
   - `profile_screen.dart` line 353 — payment-card subtitle on cream → switch to `colorScheme.onSurfaceVariant` (this one IS intended as quieter secondary text).
   - `create_event_screen.dart` line 175 — `darkGrey` (alias of `charcoalLight`) is acceptable; leave it.
   - All section-header all-caps labels (`'SETTINGS'`, `'PAYMENT'`, etc.) currently using `mediumGrey` → switch to `colorScheme.onSurfaceVariant`.

9. Sweep `withValues(alpha: ...)` / `withOpacity(...)` calls applied to text colors. For text-color usages where alpha < 0.7 on light backgrounds, either bump alpha to ≥0.85 or drop the alpha entirely.

10. **Test-fake migration enumeration** — before changing the `IImageService` interface, run:
    ```
    grep -rln "IImageService\|imageServiceProvider" test/
    ```
    and update every fake/mock to match the new signatures. Known sites at the time of writing:
    - `test/app/features/profile/edit_profile_screen_layout_test.dart`
    - `test/app/features/profile/widgets/delete_account_dialog_test.dart`
    - `test/app/features/profile/profile_test.dart`
    - any others surfaced by the grep
    All of these must be updated in the same Phase 1 commit so the project compiles.

**Functional — Sign-out redesign (Phase 3):**

11. In `profile_screen.dart`, REMOVE both the `_SectionHeader(label: 'ACCOUNT')` (currently line 79) AND the entire ACCOUNT `_SectionCard` (currently lines 81-93). With sign-out extracted, the ACCOUNT section is empty and should disappear, not stay as a bare header.

12. Place a standalone Sign Out button **between the Payment section and the Danger Zone** (i.e. at the location currently occupied by the deleted ACCOUNT section). The final order on the profile screen becomes: Hero → Settings → Payment → **Sign Out (standalone)** → Danger Zone (Delete Account) → AppVersion. This keeps the destructive-but-recoverable action (sign out) above the destructive-and-permanent action (delete account).

13. Sign Out button widget specs:
    - Widget: `OutlinedButton.icon` with `StadiumBorder` shape (matches the "Edit Profile" pill in the hero card).
    - Icon: `Icons.logout_rounded`.
    - Label: `Sign Out`.
    - Foreground (icon + label): `AppColors.terracotta` (already aliased as `AppColors.error`). DO NOT introduce a new red constant.
    - Border: `BorderSide(color: AppColors.terracotta, width: 1.5)`.
    - Background: transparent (lets cream show through).
    - Width: full inside `ContentMaxWidth` clamp; min height `48` (matches `elevatedButtonTheme` minimum).
    - Tap handler: existing `SignOutSheet.show(context: context, onSignOut: () => ref.read(authProvider.notifier).signOut())` — preserves the exact current behavior.
    - Padding: wrap in `Padding(EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xl))` so it has comfortable breathing room.

14. Existing `SignOutSheet` (`widgets/sign_out_sheet.dart`) is OUT OF SCOPE — do not modify.

**Error Handling:**

15. `FirebaseImageService.uploadToStorage` MUST surface `FirebaseException` to the caller (don't swallow silently). The edit screen's existing try/catch wraps it in a snackbar; preserve that behavior.

16. If `XFile.readAsBytes()` throws (very rare; corrupted file), the picker method returns `null` so the UI treats it as a cancelled pick. Log to `dart:developer.log(name: 'image')`.

**Edge Cases:**

17. User picks a 0-byte or extremely small image: upload anyway; let Storage / Firestore round-trip. No client-side size guards in this spec.

18. User picks the same file twice in succession: each pick replaces the previous bytes; no deduplication.

19. User leaves Edit Profile mid-pick (route pop): `_picked` state lost (lifecycle of StatefulWidget); not a bug.

**Validation (test surface):**

20. Image-service tests MUST cover: `pickFromGallery` and `takePhoto` returning a `PickedImage` whose bytes match the fake's seed (with `maxWidth/maxHeight/quality` defaults applied to the underlying `pickImage` call); `uploadToStorage` calling `putData` with the right metadata; mime-type derivation from filename when `xfile.mimeType` is null.

21. Edit profile widget test MUST cover: picking shows `MemoryImage` preview; saving calls `uploadToStorage` with bytes + `storagePath: 'users/{uid}/profile.jpg'` + `contentType` (not a `File` reference); the `getUser` + `refreshUser` block has been removed (regression guard against re-introducing the manual refresh).

22. Color sweep — at minimum a snapshot/widget test for the dashboard empty state, edit-profile helper text, and payment-card subtitle asserting the rendered `Text` widget's effective `style.color` resolves to the theme's `onSurface` or `onSurfaceVariant` (regression guard against re-introducing `mediumGrey` overrides).

23. Sign-out redesign — widget test on `profile_screen.dart` MUST verify: the ACCOUNT `_SectionHeader` and `_SectionCard` are NOT present in the tree; a single `OutlinedButton.icon` with label "Sign Out" IS present between the Payment section and `_DangerCard`; tapping it triggers `SignOutSheet.show` (assert via bottom-sheet presence in the widget tree).

24. Color contrast unit test — new file `test/app/core/constants/app_colors_contrast_test.dart` using `Color.computeLuminance` to assert: `cream` ↔ `charcoal` ≥ 4.5:1; `cream` ↔ `charcoalLight` ≥ 4.5:1; `offWhite` ↔ `charcoal` ≥ 4.5:1; `offWhite` ↔ `charcoalLight` ≥ 4.5:1; `cream` ↔ `mediumGrey` < 4.5:1 (negative assertion documenting why mediumGrey is forbidden on light surfaces).
</requirements>

<boundaries>
**Edge cases:**
- **Camera capture on web:** `image_picker_for_web` translates `ImageSource.camera` into a file `<input>` with the `capture="user"` hint. On mobile browsers (iOS Safari, Chrome on Android) the OS may surface the camera; on desktop browsers it shows the file dialog. No separate web UI for "Take a Photo" is needed; behavior depends on the browser. Acceptable for V1 — document with a one-line code comment near the picker call.
- **Drag-and-drop image upload on web:** out of scope. Image picker only.
- **HEIC/HEIF input:** Storage accepts bytes regardless; whether the resulting URL renders depends on the consuming widget (`Image.network`). Out of scope; flag as known limitation.
- **Existing avatars referencing Storage URLs that have rotated/expired:** out of scope (separate from photo upload bug).

**Error scenarios:**
- **Storage write quota / network failure:** existing snackbar pattern in `edit_profile_screen.dart`'s save handler surfaces the error; user retries.
- **Picked file size huge (>10MB):** no client-side guard added in this spec. If Storage rejects, user sees error.
- **Permission denied on Storage rules:** propagates as `FirebaseException`; surfaced via snackbar.

**Limits:**
- This spec does NOT introduce image compression/resize. The bytes uploaded are whatever the picker returned.
- This spec does NOT add web-specific drag-drop, paste, or URL-paste flows.
- This spec does NOT alter the cream background color or the broader brand palette.
- This spec does NOT modify the sign-out confirmation sheet (`SignOutSheet`); only the entry button changes.
- This spec does NOT introduce dark mode or high-contrast themes — purely fixes the existing light theme.
</boundaries>

<implementation>
**Phase 1 — Cross-platform image upload (vertical slice):**

Files to modify:
- `lib/app/core/services/image_service.dart` — replace interface (keeping method names `pickFromGallery` / `takePhoto` and the `storagePath` parameter); add `PickedImage` value type
- `lib/app/core/services/firebase_image_service.dart` — drop `dart:io` import; implement bytes-based API; preserve existing `maxWidth: 512`, `maxHeight: 512`, `imageQuality: 85` arguments to the underlying `pickImage` call; use `putData` with `SettableMetadata(contentType: ...)`
- `lib/app/features/profile/presentation/edit_profile_screen.dart` — drop `dart:io` import; replace `File? _pickedImage` with `PickedImage? _picked`; `MemoryImage` for preview; pass bytes + `storagePath: 'users/${user.uid}/profile.jpg'` + `contentType` to upload; **delete the redundant `repo.getUser` + `refreshUser` block** at the end of `_save`
- `test/app/core/services/firebase_image_service_test.dart` — new tests for bytes-based contract using a mock `Reference` / fake firebase storage (or a hand-rolled `IImageService` fake)
- Test fakes that implement `IImageService` — at least these (verify with grep before starting):
  - `test/app/features/profile/edit_profile_screen_layout_test.dart`
  - `test/app/features/profile/widgets/delete_account_dialog_test.dart`
  - `test/app/features/profile/profile_test.dart`
  - any other site surfaced by `grep -rln "IImageService\|imageServiceProvider" test/`

Patterns:
- Use `package:flutter/foundation.dart` `Uint8List` directly.
- For mime-type fallback: a small pure helper `String mimeTypeFor(String filename)` returning `image/jpeg`, `image/png`, or default. Place in the service file (private) or a tiny helper module.

What to avoid:
- DO NOT introduce conditional imports (`io.dart` vs `web.dart`). The bytes-based API removes the need.
- DO NOT keep `dart:io File` in any file under `lib/app/features/profile/` after this phase.
- DO NOT change the storage path (`users/{uid}/profile.jpg`) — downstream consumers reference it.

**Phase 2 — Readability audit + fix:**

Files to modify (initial known set; sweep finds the rest):
- `lib/app/core/theme/app_theme.dart` — add `onSurfaceVariant: AppColors.charcoalLight` to `ColorScheme.light(...)`. Touch this FIRST so the cascade applies before subsequent screen edits are evaluated.
- `lib/app/features/dashboard/presentation/dashboard_screen.dart` — lines 80, 86 (DELETE the `mediumGrey` overrides)
- `lib/app/features/profile/presentation/edit_profile_screen.dart` — lines 332, 371 (DELETE the overrides; theme cascade handles them)
- `lib/app/features/profile/presentation/profile_screen.dart` — line 353 payment subtitle → switch to `colorScheme.onSurfaceVariant`; section-header all-caps labels using `mediumGrey` → switch to `colorScheme.onSurfaceVariant`
- `lib/app/features/dashboard/presentation/create_event_screen.dart` — audit; current `darkGrey` on cream is acceptable
- Sweep produces the rest

Sweep procedure:
1. `grep -rn "AppColors.mediumGrey\|AppColors.lightGrey" lib/` → expect ~127 hits across 35 files; ignore non-text uses (icons, borders, dividers)
2. For each TEXT hit, identify the surrounding container background (Container `decoration.color`, Scaffold default `offWhite`, parent `_SectionCard` `white`, hero card charcoal, etc.)
3. If on light surface (cream / offWhite / white): apply rule #7 from `<requirements>` — DELETE first, fall back to `colorScheme.onSurfaceVariant` only when secondary tone is intentional
4. If on charcoal/dark surface: leave alone
5. Run app on web after the sweep; visually confirm the named screens

Patterns:
- Prefer Theme-driven colors (`Theme.of(context).colorScheme.onSurface` / `.onSurfaceVariant`) over hard-coded `AppColors.charcoal` where the screen already uses theme defaults — keeps future palette tweaks centralized.
- For text inside the hero card (charcoal background) keep `offWhite` / `sageLight` — those are AA already.

What to avoid:
- DO NOT change the cream / offWhite / white surface colors.
- DO NOT touch the hero card's offWhite-on-charcoal contrast — it's already fine.
- DO NOT introduce a separate "high-contrast theme" — fold improvements into the default theme.
- DO NOT touch icon, border, or divider uses of `lightGrey` / `mediumGrey` — they are intentional non-text uses.

**Phase 3 — Sign-out redesign:**

Files to modify:
- `lib/app/features/profile/presentation/profile_screen.dart` — DELETE the entire ACCOUNT block (the `_SectionHeader('ACCOUNT')` AND the `_SectionCard` containing the sign-out tile, plus the surrounding `SizedBox(height: AppSpacing.xl)` if redundant); insert a new `_SignOutButton` widget at that position (between Payment and Danger Zone)
- `lib/app/core/constants/app_colors.dart` — UNCHANGED. `AppColors.terracotta` / `AppColors.error` already exists.

Patterns:
- `OutlinedButton.icon(onPressed: () => SignOutSheet.show(context: context, onSignOut: () => ref.read(authProvider.notifier).signOut()), icon: const Icon(Icons.logout_rounded), label: const Text('Sign Out'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.terracotta, side: const BorderSide(color: AppColors.terracotta, width: 1.5), shape: const StadiumBorder(), minimumSize: const Size.fromHeight(48)))`.
- Wrap in `Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xl))`.
- Live inside the existing `ContentMaxWidth` clamp already used by the profile body.

What to avoid:
- DO NOT change the bottom-sheet contents (`SignOutSheet`).
- DO NOT add a confirm dialog *and* the sheet — the sheet IS the confirm step.
- DO NOT use a filled red button — too heavy; outlined is the destructive-but-not-primary affordance.
- DO NOT introduce a new color constant. Reuse `AppColors.terracotta` (which is also exposed as `AppColors.error`).
- DO NOT leave an empty ACCOUNT section header behind. If sign-out is the only tile in ACCOUNT, the section disappears entirely.
</implementation>

<validation>
**Baseline automated coverage outcomes:**

- **Logic:** mime-type derivation helper covered for `.jpg`, `.jpeg`, `.png`, fallback (no extension, unknown extension).
- **Service behavior:** `FirebaseImageService.uploadToStorage` covered for: `putData` invoked with the expected bytes + metadata content-type; download URL returned matches the fake's seed.
- **UI behavior:**
  - Edit Profile widget test: avatar preview is a `MemoryImage` after pick; save handler invokes the fake `IImageService.uploadToStorage` with the picked bytes and the canonical path.
  - Profile screen widget test: standalone Sign Out outlined button rendered below sections; ACCOUNT card no longer contains a Sign Out row; tapping the button invokes `SignOutSheet.show` (verified via injected fake or by asserting the sheet appears).
- **Readability regression guards:** small targeted widget tests for the named screens (dashboard empty state, edit-profile helper text, payment subtitle) asserting the resolved text color is `AppColors.charcoal` or `AppColors.charcoalLight`.

**TDD-first expectations (per `flutter-tdd`):**

Implement Phase 1 in vertical slices — one RED → GREEN → REFACTOR cycle per slice; no batching tests.

- Slice 1.A: `mimeTypeFor('photo.jpg') == 'image/jpeg'` (RED → minimal helper → GREEN)
- Slice 1.B: `mimeTypeFor('photo.PNG') == 'image/png'` (covers case-insensitive)
- Slice 1.C: `mimeTypeFor('weird') == 'image/jpeg'` (fallback)
- Slice 1.D: `FirebaseImageService.uploadToStorage(bytes:, storagePath:, contentType:)` calls `putData` with the right metadata (use a `MockReference`/fake or an injectable Storage seam)
- Slice 1.E: `pickFromGallery` returns a `PickedImage` whose bytes match the seeded XFile (mock `image_picker` via the seam, or wrap the picker in an injectable function); the underlying `pickImage` call receives `maxWidth: 512`, `maxHeight: 512`, `imageQuality: 85`
- Slice 1.F: `takePhoto` mirrors slice 1.E (camera source)
- Slice 1.G: Edit profile widget test — pick → preview is `MemoryImage` containing the bytes
- Slice 1.H: Edit profile save → fake `IImageService.uploadToStorage` invoked with bytes + `storagePath: 'users/{uid}/profile.jpg'` + `contentType`; `repo.getUser` is NOT called after save (regression guard against re-introducing manual refresh)

Phase 2:
- Slice 2.A: New `app_colors_contrast_test.dart` — `Color.computeLuminance` based ratio computation; assert AA on `cream`/`offWhite` ↔ `charcoal` and `↔ charcoalLight`; negative-assert AA fails on `cream` ↔ `mediumGrey` (locks in why mediumGrey is forbidden on light surfaces).
- Slice 2.B: Theme update — add `onSurfaceVariant: charcoalLight` to `ColorScheme.light`. Validate with a small widget test that `Theme.of(context).colorScheme.onSurfaceVariant == charcoalLight`.
- Slice 2.C-onward: mechanical sweep with regression widget tests on the named screens (dashboard empty state, edit-profile helper text, profile payment subtitle) asserting effective text color resolves to a theme-driven AA-safe value, not `mediumGrey`.

Phase 3:
- Slice 3.A: Profile screen no longer contains the ACCOUNT `_SectionHeader` or `_SectionCard`.
- Slice 3.B: Profile screen contains a single `OutlinedButton.icon` with label "Sign Out" placed between the Payment section and `_DangerCard`.
- Slice 3.C: Tapping the new button invokes `SignOutSheet.show` (assert by waiting for the bottom-sheet widget in the tree).

**Testability seams:**

- `IImageService` is already abstracted via interface — tests inject a `FakeImageService` that captures bytes + path.
- `FirebaseImageService` constructor accepts `FirebaseStorage? storage` (already used pattern in repos). If not, add it. Tests use a mock storage / mock ref pair.
- `image_picker` itself is harder to mock; introduce a private function-typed seam in `FirebaseImageService` constructor: `Future<XFile?> Function(ImageSource source)? _pickerOverride`. Default to `ImagePicker().pickImage`. Tests pass a closure returning a stub `XFile`.
- `SignOutSheet.show` is a static method on a class — to test the tap-→-sheet wiring, either assert the bottom-sheet widget appears in the tree after tap, or refactor `SignOutSheet.show` to delegate to an injectable callback. Prefer assertion-on-tree approach (no production-side refactor needed).

**Mocking policy:**
- Prefer hand-rolled fakes for `IImageService`, `IUserRepository`, `FirebaseStorage` interactions.
- Avoid `mocktail` unless already established in the file under test.
- Do NOT mock `firebase_auth` directly — work at the `AuthRepository` interface seam (already established).

**Test-type mapping:**
- **Unit:** mime-type helper, service-level upload behavior.
- **Widget:** edit profile pick + save, profile screen sign-out button presence + tap.
- **Robot-driven journey:** out of scope for this spec — the existing journeys (sign-in → onboarding → dashboard → profile) implicitly exercise the readability changes by rendering. Add a robot test only if a new critical journey emerges (none here).

**Manual verification (after code lands):**
- Build web: `flutter build web --release --dart-define=FLAVOR=dev && firebase deploy --only hosting:crewpoint-dev`.
- On `crewpoint-dev.web.app`:
  - Sign in (any provider), open Edit Profile, tap avatar, pick a JPEG → preview shows → save → snackbar success → Profile screen shows new avatar.
  - Repeat with a PNG; verify content-type in the Storage console.
  - Cycle through Dashboard, Profile, Edit Profile, Create Event — confirm no text reads as washed-out.
  - Scroll to bottom of Profile — confirm new red Sign Out button.
- On iOS / Android device:
  - Repeat the photo-update flow (gallery + camera if applicable) — confirm parity.

**Known testing risks:**
- `image_picker` plugin tests cannot exercise the actual native picker — the seam-injection approach means we test our wrapper, not `image_picker` itself. Acceptable; documented limitation.
- Color contrast tests assert on the `Color` value, not on a true contrast computation. If a test wants real contrast math, use `package:flutter/painting.dart`'s `Color.computeLuminance` and assert the ratio. Add only if a reviewer requests it.
</validation>

<done_when>
1. `lib/app/core/services/image_service.dart` exposes a `PickedImage` value type and an `IImageService` interface that returns `Future<PickedImage?>` for picks and `Future<String>` (download URL) for uploads. No `dart:io` references in this file.

2. `lib/app/core/services/firebase_image_service.dart` implements the new interface using `XFile.readAsBytes()` and `Reference.putData(...)`. No `dart:io` references in this file.

3. `lib/app/features/profile/presentation/edit_profile_screen.dart` has no `dart:io` import; preview uses `MemoryImage`; save passes bytes to `uploadToStorage`. The same flow works on web, iOS, and Android.

4. Every TEXT use of `AppColors.mediumGrey` / `lightGrey` on a light surface (cream / offWhite / white) is either DELETED (theme cascade applies) or switched to `colorScheme.onSurfaceVariant`. Non-text uses (icons, borders, dividers) are untouched. `app_theme.dart`'s light `ColorScheme` has `onSurfaceVariant: charcoalLight`. New `app_colors_contrast_test.dart` proves the AA-safe pairs and the AA-fail pair (`cream` ↔ `mediumGrey`).

5. Profile screen no longer renders the ACCOUNT `_SectionHeader` or `_SectionCard`. A standalone outlined Sign Out button (foreground + border `AppColors.terracotta`, no new color constants) sits between the Payment section and the Danger Zone, full width inside `ContentMaxWidth`, and tapping it shows the existing `SignOutSheet`.

6. `flutter analyze` clean; `flutter test` all green (existing 260 + new tests).

7. `firestore.rules`, Cloud Functions, the auth flow, and the cream background palette are all unchanged.

8. Manual web smoke: profile photo upload completes successfully on Safari + Chrome; new red Sign Out button visible and functional; named screens read clearly without strain.
</done_when>
