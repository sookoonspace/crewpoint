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
- [x] `IUserRepository` abstract interface + `FirestoreUserRepository` concrete
- [x] `userRepositoryProvider` in providers.dart
- [x] Edit screen uses `repo.saveProfile()` instead of direct Firestore
- [x] Better error messages (permission, network, generic)
- [x] `CustomTextField` upgraded: label param, filled offWhite bg, charcoal text, sage focus, terracotta errors
- [x] Edit screen redesigned: no card wrappers, section headers, labeled fields, sage glow avatar
- [x] Verify: 54 tests, 0 warnings

### Phase 3: Abstract Repository Interfaces

- **Goal**: Refactor all concrete repositories to abstract interfaces + implementations
- [x] 5 abstract interfaces: IAuthRepository, IEventRepository, ITaskRepository, IExpenseRepository, IChatRepository
- [x] Each concrete repo now `implements` its interface with @override annotations
- [x] Verify: 54 tests, 0 warnings

## Risks / Out of scope

- **Risks**: Phase 3 touches 5 files + their tests — ensure no broken imports
- **Out of scope**: Migrating existing repositories to Firestore (they currently use Drift DAOs — that's correct for offline-first; Firestore sync is separate)
