## Overview

Fix stale profile data after edit (AuthNotifier doesn't refresh on profile update). Create reusable `ImageService` for pick/take/crop/upload with loading + error placeholder widget.

## Context

- **Stale data root cause**: `AuthNotifier` listens to `FirebaseAuth.authStateChanges` which only fires on sign-in/sign-out, NOT profile updates. After saving displayName/photoUrl, the `Authenticated(user)` state still holds the old `AppUser`. Also, `AppUser` is mapped from Firebase Auth user — it doesn't include Firestore-only fields (paymentMethod, paymentHandle, currency).
- **Fix**: After successful save, manually reload `AppUser` from Firestore via `userRepositoryProvider` and update `AuthNotifier` state. Add a `refreshUser()` method to `AuthNotifier`.
- **Image service**: Currently `edit_profile_screen.dart` has inline `ImagePicker` + `FirebaseStorage` code. Need reusable service for profile photos, receipts, event images.
- **References**: `lib/app/features/profile/presentation/edit_profile_screen.dart`, `lib/app/features/auth/application/auth_provider.dart`

## Plan

### Phase 1: Fix Profile Refresh + Reusable Image Service

- **Goal**: Profile updates reflected immediately; centralized image pick/upload service
- [x] `lib/app/features/auth/application/auth_provider.dart` — Add `refreshUser(AppUser updatedUser)` method that updates `state = Authenticated(updatedUser)` without requiring a sign-in/sign-out event
- [x] `lib/app/core/services/image_service.dart` — Reusable service (abstract `IImageService`):
  - `pickFromGallery({int maxWidth, int maxHeight, int quality})` → `File?`
  - `takePhoto({int maxWidth, int maxHeight, int quality})` → `File?`
  - `uploadToStorage({required File file, required String storagePath})` → `String` (download URL)
  - Uses `image_picker` for pick/take, `firebase_storage` for upload
  - Constructor injection for testability
- [x] `lib/app/core/services/firebase_image_service.dart` — Concrete implementation of `IImageService`
- [x] `lib/app/core/providers.dart` — Add `imageServiceProvider`
- [x] `lib/app/features/profile/presentation/edit_profile_screen.dart` — Refactor:
  - Replace inline ImagePicker/Storage code with `ref.read(imageServiceProvider)`
  - After successful save: fetch updated user from `userRepositoryProvider.getUser(uid)` → call `authProvider.notifier.refreshUser(updatedUser)`
  - Pick photo: show bottom sheet with "Gallery" / "Camera" options
- [x] `lib/app/core/widgets/network_image_with_placeholder.dart` — Reusable widget:
  - Shows `Image.network` with loading shimmer placeholder
  - On error: shows Lottie profile animation (for avatars) or grey placeholder icon
  - Circular clip option for avatars
- [x] `lib/app/features/profile/presentation/profile_screen.dart` — Use `NetworkImageWithPlaceholder` for avatar instead of raw `Image.network`
- [x] TDD: refreshUser updates AuthNotifier state to new user data
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `FirebaseAuth.currentUser.reload()` may be needed to sync Auth profile with server after `updateDisplayName` — test on device
- **Out of scope**: Image cropping (can add `image_cropper` package later); image compression beyond `maxWidth/maxHeight/quality`
