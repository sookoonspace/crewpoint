## Overview

Fix edit profile save error (add proper user repository with Firestore wiring), redesign edit screen for better text visibility/UX on cream bg, refactor all repositories to abstract interfaces.

## Context

- **Save error root cause**: `edit_profile_screen.dart` calls `FirebaseFirestore.instance` directly (no repository). Likely fails because: 1) user doc may not exist on first edit, 2) no error context in catch block, 3) no repository abstraction
- **Repository pattern**: All 5 repos (`ChatRepository`, `TaskRepository`, `AuthRepository`, `ExpenseRepository`, `EventRepository`) are concrete — need abstract interfaces per spec §2.1
- **Text visibility**: `CustomTextField` uses theme's `InputDecoration` which works on white bg but hint/label contrast is poor when inside white cards on cream bg
- **Reference**: `lib/app/features/profile/presentation/edit_profile_screen.dart`, `lib/app/core/widgets/custom_text_field.dart`

## Plan

### Phase 1: User Profile Repository + Fix Save

- **Goal**: Create abstract `IUserRepository` + concrete `FirestoreUserRepository`; fix save flow
- [ ] `lib/app/features/profile/domain/repositories/i_user_repository.dart` — Abstract interface:
  - `Future<AppUser?> getUser(String uid)`
  - `Future<void> saveProfile({required String uid, required String displayName, String? photoUrl, String? paymentMethod, String? paymentHandle})`
  - `Future<void> createUserIfNotExists(String uid, String email)`
- [ ] `lib/app/features/profile/data/firestore_user_repository.dart` — Implements `IUserRepository`:
  - `saveProfile`: uses `set(merge: true)` with `updatedAt: serverTimestamp()`
  - `createUserIfNotExists`: creates doc with email + displayName from auth if doc doesn't exist
  - Error logging with `dart:developer`
- [ ] `lib/app/core/providers.dart` — Add `userRepositoryProvider`
- [ ] `lib/app/features/profile/presentation/edit_profile_screen.dart` — Replace direct Firestore calls with `ref.read(userRepositoryProvider).saveProfile()`; show specific error messages
- [ ] `lib/main.dart` — After Firebase init, call `createUserIfNotExists` to ensure user doc exists on login
- [ ] TDD: saveProfile creates/updates Firestore user doc
- [ ] TDD: createUserIfNotExists is idempotent (no error on existing doc)
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Edit Profile UI Redesign

- **Goal**: Better text visibility, improved field UX on cream background
- [ ] `lib/app/core/widgets/custom_text_field.dart` — Add optional `label` parameter; improve styling:
  - Floating label above field (not just hint inside)
  - `filled: true` with `AppColors.offWhite` fill for contrast on cream bg
  - Charcoal text, darkGrey hint, sage focus border
  - Error text in terracotta
- [ ] `lib/app/features/profile/presentation/edit_profile_screen.dart` — Redesign:
  - Remove card wrapper around name field (field styling handles it)
  - Group payment fields with a section header ("Payment Info — Optional")
  - Use labeled fields: "Display Name", "Payment Method", "Payment Handle"
  - Show current values as labels, not just hints
  - Ensure all text is readable on cream/white backgrounds
  - Better spacing between sections
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Abstract Repository Interfaces

- **Goal**: Refactor all concrete repositories to abstract interfaces + implementations
- [ ] `lib/app/features/auth/domain/repositories/i_auth_repository.dart` — Extract from `AuthRepository`
- [ ] `lib/app/features/dashboard/domain/repositories/i_event_repository.dart` — Extract from `EventRepository`
- [ ] `lib/app/features/tasks/domain/repositories/i_task_repository.dart` — Extract from `TaskRepository`
- [ ] `lib/app/features/budget/domain/repositories/i_expense_repository.dart` — Extract from `ExpenseRepository`
- [ ] `lib/app/features/chat/domain/repositories/i_chat_repository.dart` — Extract from `ChatRepository`
- [ ] Each concrete repo `implements` its interface; rename files to `firestore_*_repository.dart` or `drift_*_repository.dart`
- [ ] Update providers to use interface types
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: Phase 3 touches 5 files + their tests — ensure no broken imports
- **Out of scope**: Migrating existing repositories to Firestore (they currently use Drift DAOs — that's correct for offline-first; Firestore sync is separate)
