## GLOBAL CODING STANDARDS (Must be strictly followed)

1. **Absolute Imports Only:**
   - NEVER use relative imports (e.g., `import '../ui/widget.dart'`).
   - ALWAYS use package imports (e.g., `import 'package:app_name/feature/ui/widget.dart'`).

2. **No Magic Strings or Numbers:**
   - Hardcoded strings, colors, padding values, and dimensions are strictly forbidden inside UI widgets.
   - All values must reference the centralized `app/core/constants/` directory (e.g., `AppSpacing.md`, `AppColors.primary`).

3. **Widget Composition over Large Build Methods:**
   - If a `build()` method exceeds ~60 lines of code, it must be refactored.
   - Extract complex nested UI trees into smaller, separate, private `StatelessWidget` classes within the same file. DO NOT extract widgets into functional methods (e.g., `Widget _buildHeader() { ... }`); always use classes.

4. **Strict Null Safety & Error Handling:**
   - The force unwrap operator (`!`) is absolutely forbidden unless checking a value that was asserted as non-null on the line immediately preceding it.
   - Always use safe unwrapping (`?.`, `??`) or explicit null checks.
   - All repository layer methods must catch exceptions and return typed failure models.

5. **Linter Compliance (CRITICAL TASK):**
   - The agent MUST generate a custom, strict `analysis_options.yaml` in the project root enforcing `always_use_package_imports: true`, `prefer_const_constructors: true`, and `avoid_print: true`.
   - Code must pass `flutter analyze` with zero warnings before a phase is considered complete.

---

# ACT Specification: CrewPoint - Collaborative Event Management App (V1.0 MVP)

## 1. Project Overview
CrewPoint is a comprehensive event management Flutter application by Sookoon LLC. It facilitates event creation, task management, real-time communication, and budgeting. The app utilizes a freemium model and targets iOS, Android, and Web natively. 

**Development Phasing:** This specification defines the Phase 1 MVP. Complex features (E2EE, Live Location) are architecturally planned but deferred to Phase 2.

## 2. Architecture & Code Standards
Strict adherence to a Feature-First architecture, utilizing Domain-Driven Design principles.

### 2.1 Directory Structure
* `lib/app/core/services/`: **Crucial:** ALL third-party packages MUST be wrapped in abstract service interfaces (e.g., `IChatService`, `ILocationService`).
* `lib/app/features/<feature_name>/`: Each feature must contain `domain/`, `data/`, `presentation/`, and `application/` layers.

### 2.2 Core Technologies (Phase 1)
* **State Management:** `flutter_riverpod`.
* **Navigation:** `go_router`.
* **Backend:** `firebase_core`, `firebase_auth`, `cloud_firestore`.
* **Local Database:** `drift` (with `sqlite3_flutter_libs` for offline-first architecture).
* **Secret Management:** `envied` for build-time keys; `flutter_secure_storage` for runtime tokens.

## 3. Environment & Flavor Setup
Initialize three build flavors: `dev`, `stg`, and `prod`.

* **App IDs (Reverse Domain Standard):**
   - Dev: `space.sookoon.crewpoint.dev`
   - Staging: `space.sookoon.crewpoint.stg`
   - Prod: `space.sookoon.crewpoint.app`
* **Setup Tooling:** Use `flutter_flavorizr` or manually configure native files for these three variants.
* **App Icons:** Use `flutter_launcher_icons` to generate distinct icons (e.g., overlay a "DEV" or "STG" ribbon on the development variants).
* **Build-Time Secrets:** Add `envied` and `envied_generator`. Create `.env.dev`, `.env.stg`, and `.env.prod`. Obfuscate API keys into encrypted Dart classes.
* **Runtime Secrets:** Add `flutter_secure_storage` for session tokens. No sensitive data in `shared_preferences`.

## 4. Feature Specifications (What to Build Now)

### 4.1 Onboarding & Authentication
* **Carousel Onboarding:** 3 screens using `lottie` animations. Include an explicit "Data Collection Opt-In" toggle (defaults to OFF).
* **Auth Gateway:** Social Auth (Google, Apple) and Email/Password.

### 4.2 Offline-First Data Sync & Backend Strategy
* **Local Database (Drift):** Initialize `drift`. Configure the relational schema (Events, Tasks, Users) as the single source of truth for all UI state.
* **Firebase:** Initialize `firebase_core` for all three platforms and flavors.
* **Service Wrappers:** Create `IChatService` to wrap Firestore, ensuring E2EE logic can be swapped in later without breaking the UI.
* **Sync Engine:** Implement basic background synchronization bridging `drift` and Firestore.

### 4.3 Dashboard & Task Management
* **Routing:** `go_router` with StatefulShellRoute for Bottom Navigation.
* **Tasks:** Status tracking, assignees, checklists, and file attachments.

### 4.4 Communication & Budgeting
* **Group Chat (Phase 1):** Real-time chat using standard Firestore listeners. **Security:** Implement strict Firestore Security Rules.
* **Critical Alerts:** High-priority push notifications via a predefined list/custom text modal.
* **Expense Modal:** Track amounts, upload receipts, toggle "Donate this cost", and calculate split amounts dynamically.

### 4.5 Profile, Privacy & Destructive Actions
* **Privacy Dashboard:** Settings section listing all dependencies used.
* **Account Deletion:** Multi-step dialog requiring password confirmation to trigger complete local and remote data erasure.

## 5. UI/UX Design System
Establish a serene and premium aesthetic.

* **Themes:** Full Light and Dark themes utilizing a tokenized `ThemeData` setup. 
* **Typography:** Implement `google_fonts` using Poppins for headings and Inter for body text.
* **Color Palette:** Use the established premium palette: charcoal for primary text/background depth, sage green for positive actions/success states, and terracotta brown for alerts or destructive actions. 
* **Components:** Standardized widgets: `PrimaryButton`, `DestructiveButton`, `CustomTextField`, and `DialogOverlay`. Ensure all spacing and radii map strictly to `app/core/constants/`.
* **LottieAnimations:** We will be using Lotti animations for any loading, waiting, etc animations

## 6. Deferred Features (Architect for Phase 2 - DO NOT IMPLEMENT LOGIC YET)
* **End-to-End Encryption (E2EE):** Leave a TODO in the `ChatService`. Do not add `cryptography` package yet.
* **Live Location Tracking:** Create the UI tab for the map, but leave a TODO in `LocationService`. Do not implement Google Maps SDK yet.
* **Biometric Lock:** Leave a TODO in the app lifecycle manager. Do not add `local_auth` yet.

## 7. Definition of Done & Quality Gates
1.  **Offline Capability:** The app can launch and display cached `drift` data with Wi-Fi disabled.
2.  **Secret Audit:** No API keys exist in plain text. `envied` is fully implemented.
3.  **Strict Analysis:** Tests target 80% coverage. Code MUST pass `flutter analyze` referencing the strict rules defined in section 1.