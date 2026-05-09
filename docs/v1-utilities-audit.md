# V1 Utilities Audit

> *Generated against commit `0f6d357` on 2026-05-09. Re-run the verification steps in [`ai_specs/v1-utilities-audit-spec.md`](../ai_specs/v1-utilities-audit-spec.md) if `pubspec.yaml` has changed since.*

Companion to [`docs/v1-progress-audit.md`](v1-progress-audit.md). That audit covers the **architecture** (Drift, Riverpod, GoRouter, Firebase, etc.); this one covers the **utility** packages — `share_plus`, `intl`, `image_picker`, etc. — and names the follow-up specs we still need to write before public launch.

Severity legend: **must-ship** = V1 launch blocker; **should-ship** = V1 if cheap; **nice-to-have** = V1.x.

Scope is the explicit allow-list defined in the spec. Anything found in `pubspec.yaml` that's NOT in the allow-list (firebase_*, drift, flutter_riverpod, riverpod_annotation, go_router, cloud_firestore, cloud_functions, web, cupertino_icons) is core architecture or framework infrastructure — covered by `docs/v1-progress-audit.md`, not here.

---

## 1. Already in pubspec

| Package | Version | Status | Where used | Note |
| --- | --- | --- | --- | --- |
| `share_plus` | ^10.1.4 | ✅ Used | `lib/app/features/dashboard/presentation/widgets/add_member_sheet.dart:107-109` (`Share.share('Join my event on CrewPoint! Use code: $_code')`); `lib/app/core/services/file_export_service_native.dart:23` (`Share.shareXFiles(...)` for non-PDF exports). | System share sheet. Wired for invite codes (member-management context) and export deliveries. Refined gap → see Section 2. |
| `url_launcher` | ^6.3.1 | ✅ Used | `lib/app/core/services/url_launcher_service.dart` (test seam wrapping `launchUrl`); consumers include `pay_link_builder.dart` (Venmo/CashApp deep links) and the legal-doc tiles in profile. | Wrapped behind `IUrlLauncher` interface for testability. |
| `image_picker` | ^1.1.2 | ✅ Used | `lib/app/core/services/firebase_image_service.dart:37` (`ImagePicker().pickImage(source: source, maxWidth: ..., maxHeight: ..., imageQuality: ...)`). | Pluggable picker function lets tests inject a stub. Used for profile photos AND receipt attachments. |
| `intl` | ^0.20.2 | ✅ Used | Across feature screens — date formatting in `event_dashboard_screen.dart` (`DateFormat.yMMMd()`), task due-date formatting, expense amount formatting, etc. | Standard date/number formatting library. |
| `package_info_plus` | ^8.3.0 | ⚠️ Underused | Imported in `lib/app/features/profile/presentation/profile_screen.dart` but no `.version` / `.appName` call site found. | Likely placeholder for future version-display in settings. Decision: keep for now, revisit at launch — if no call site by then, drop. |
| `path_provider` | ^2.1.5 | ✅ Used | `lib/app/core/database/connection/native.dart:6,12` (`getApplicationDocumentsDirectory()` for the Drift DB file path on mobile/desktop). | Exclusive to the native Drift connection. |
| `path` | ^1.9.1 | ✅ Used | `lib/app/core/database/connection/native.dart:5` (`p.join(dir.path, 'crewpoint.db')`). | Used together with `path_provider` for cross-platform path joins. |
| `uuid` | ^4.5.1 | ✅ Used | `expense_modal.dart:130`, `create_task_screen.dart:62`, `checklist_editor.dart:50`, `create_event_screen.dart` — `const Uuid().v4()` for client-side IDs. | Foundation for offline-friendly id generation (no server round-trip). |
| `flutter_secure_storage` | ^9.2.4 | ✅ Used | `lib/app/core/services/secure_storage_service.dart` (wrapper). | Used for sensitive small values (e.g., onboarding flag, session-related data). |
| `pdf` | ^3.11.0 | ✅ Used | `lib/app/features/budget/data/expense_pdf_builder.dart`, `lib/app/features/tasks/data/task_pdf_builder.dart`. | Pure-Dart PDF builder — no Flutter context needed; testable without a Flutter binding. |
| `printing` | ^5.13.0 | ✅ Used | `lib/app/core/services/file_export_service_native.dart:3,19` (`Printing.sharePdf(bytes: ..., filename: ...)`). | Mobile/desktop PDF share-sheet integration. Web uses `package:web` Blob+anchor instead. |
| `csv` | ^6.0.0 | ✅ Used | `lib/app/features/budget/data/expense_csv_builder.dart` (`ListToCsvConverter().convert(...)` with RFC-4180 escaping). | Tested for embedded commas, quotes, multi-line cells. |
| `lottie` | ^3.3.1 | ✅ Used | `lib/app/core/widgets/loading_animation.dart` — Lottie-backed loading indicator with `CircularProgressIndicator` fallback if the asset fails to load. | One concrete animation asset; not heavily used elsewhere. |
| `flutter_markdown_plus` | ^1.0.7 | ✅ Used | `lib/app/features/profile/presentation/markdown_render_screen.dart` — renders bundled Privacy + Terms markdown with YAML frontmatter (last-updated stamps). | The actively-maintained successor to the now-archived `flutter_markdown` (per the comment in `pubspec.yaml`). |
| `clock` | ^1.1.1 | ✅ Used | `lib/app/features/budget/application/pending_settlement_notifier.dart` (`Clock().now()` for elapsed-time logic). | Testable wall-clock; `withClock(...)` lets tests advance time deterministically. |
| `yaml` | ^3.1.2 | ✅ Used | `lib/app/features/profile/presentation/markdown_render_screen.dart:7` (`loadYaml(...)` to parse markdown frontmatter); also `scripts/build_legal_html.dart:29` for the offline HTML build. | Legitimate use; not dead. |

### Dev dependencies (utility-shaped, in scope)

| Package | Status | Note |
| --- | --- | --- |
| `image` | ✅ Script-only | Used by `scripts/generate_flavor_icons.dart` to draw DEV/STG flavor badges on launcher icons (PNG decode/draw/encode). Justified as dev-only. |
| `markdown` | ✅ Script-only | Used by `scripts/build_legal_html.dart` to render bundled markdown into the static `web/legal/*.html` pages served by Firebase Hosting. Justified as dev-only. |

---

## 2. V1 launch blockers (utility-shaped)

### 2.1 Invite-share UX wiring *(pre-decided)*

**User journey:** *(see [`ai_specs/v1-utilities-audit-spec.md`](../ai_specs/v1-utilities-audit-spec.md) `<user_flows>` row 1)* — admin opens an event → taps "Invite" → app surfaces the invite code → admin shares via system share sheet → recipient pastes into `JoinEventSheet`.

**What we have:** `share_plus` is wired in `lib/app/features/dashboard/presentation/widgets/add_member_sheet.dart:107-109` — `_shareCode()` calls `Share.share('Join my event on CrewPoint! Use code: $_code')`. Shipped today.

**What's missing — narrowed scope:**
1. The share affordance lives **inside the Add Member sheet**, which most users won't open until they realise they need to invite someone. The share button needs to surface from the **event detail screen** itself (`EventDashboardScreen` — likely next to the Members preview card).
2. **No post-create share prompt** — after `CreateEventScreen` submits successfully, the user is dropped back on the dashboard with no nudge to invite anyone. A SnackBar action ("Share invite code →") or a follow-up sheet would close that loop.

**Recommended package:** none — `share_plus` already in pubspec. Spec is wiring + UX placement, not a package add.

**Follow-up spec:** [`invite-share-spec.md`](../ai_specs/invite-share-spec.md) *(to be written)*. **must-ship.**

### 2.2 Cross-references to architecture-shaped V1 launch blockers

These are tracked in the V1 progress audit; mentioned here for completeness so a reader landing on either doc finds both:

- **Firestore offline persistence on web** — see [`docs/v1-progress-audit.md` Pillar 1](v1-progress-audit.md#pillar-1--offline-first-foundation). One-line fix: `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true)` in `firebase_service.dart` for the web build path.
- **Zelle deep-link UX** — see [`docs/v1-progress-audit.md` Pillar 3](v1-progress-audit.md#pillar-3--zero-liability-settlements). Either implement a web-banking fallback, or scope-cut Zelle from V1 with explicit copy.

---

## 3. V1 should-ship

### 3.1 On-device receipt OCR *(pre-decided)*

**User journey:** *(see spec `<user_flows>` row 2)* — user taps "Add Expense" → fills amount → taps "Scan Receipt" → camera opens → on-device OCR extracts total + merchant → fields pre-fill → user confirms.

**What we have:** **Nothing.** Confirmed zero references to `mlkit` / `ocr` / `text_recognizer` / `tesseract` in `lib/`. Only manual amount entry today.

**Recommended package:** `google_mlkit_text_recognition` (mobile-only). Free, on-device, no per-call cost.

**Cross-platform contract:**
- **Button visibility:** shown-with-fallback. The "Scan Receipt" button is hidden on web (`kIsWeb` branch); web users continue to use manual amount entry plus the existing gallery/camera receipt-image attachment.
- **Fallback path:** existing manual amount entry (`expense_modal.dart`) — already works; no UX gap.
- **Conditional-branch location:** `kIsWeb` check inside the receipt-attachment widget in the expense modal. Mirror the conditional-import pattern at `lib/app/core/database/connection/native.dart` ⇄ `web.dart` and `lib/app/core/services/file_export_service_native.dart` ⇄ `_web.dart`.

**Caveats** (the receipt-ocr-spec is responsible for designing UX around these):
- **iOS bundle size delta** — the bundled text-recognition model adds ~5–10MB to the iOS install. Worth confirming on first TestFlight upload.
- **First-call model-download UX on Android** — the model is fetched via Play Services on first invocation. The follow-up spec needs loading copy + an offline fallback ("OCR isn't available offline yet — enter the amount manually").

**Follow-up spec:** [`receipt-ocr-spec.md`](../ai_specs/receipt-ocr-spec.md) *(to be written)*. **should-ship.**

### 3.2 `permission_handler` — decision rule outcome

**Verification result: NOT NEEDED for V1.**

Decision rule: *Add `permission_handler` IF (a) we want a custom pre-prompt rationale screen before the OS prompt, OR (b) we need to detect a previously-denied state to show "go to Settings" copy in a custom UI.*

Evidence:
- `lib/app/core/services/firebase_image_service.dart:37` calls `ImagePicker().pickImage(...)` directly. iOS/Android prompt natively at the right moment; we don't wrap.
- `lib/app/core/services/fcm_service.dart` calls `_gateway.requestPermission()`, which resolves to Firebase Messaging's native prompt. No custom rationale screen.
- Zero matches for `permission_handler` import anywhere in `lib/`.
- No "go to Settings" remediation UI exists today; not on the V1 backlog.

**Outcome:** existing native prompts are sufficient. Don't add the package. Revisit if user testing reveals a permission-pit-of-failure (e.g., users denying camera permission and never getting back to it).

### 3.3 `flutter_local_notifications` — decision rule outcome

**Verification result: NOT NEEDED for V1.**

Decision rule: *Add `flutter_local_notifications` IF V1 has a concrete user journey that fires a notification without a server-side trigger.*

Evidence:
- Every notification path flows through FCM (`firebase_messaging`) — see `lib/app/core/services/fcm_handler.dart` for the foreground/background/cold-start routing. All payloads carry server-issued `deepLink` data.
- `lib/app/features/budget/application/pending_settlement_notifier.dart` uses `Clock().now()` to track elapsed time but does NOT fire a notification when a settlement expires.
- Zero matches for `flutter_local_notifications` import anywhere in `lib/`.
- No journeys in the V1 backlog require a device-local trigger (e.g., "remind me 1 hour before the event starts").

**Outcome:** defer to V1.x. If a device-local reminder becomes a user story (most likely candidate: *"settlement expires in 1 hour, last chance to dispute"*), schedule then.

---

## 4. V1.x follow-ups

| Capability | Recommended package | User journey it'd serve |
| --- | --- | --- |
| QR code generation for invites | `qr_flutter` | Admin shares an invite QR for in-person events; recipient scans with the camera. |
| Deep-link / universal-link for invite URLs | `app_links` (or Firebase Hosting redirect-to-app pattern) | Recipient taps `crewpoint.sookoon.space/join/ABC123` → opens the app to the prefilled `JoinEventSheet`, falls back to the web app if the app isn't installed. |
| Connectivity-state UI | `connectivity_plus` | Show a top banner when offline so users know their writes are queued. Today the offline write is silent. |
| Contact picker | `flutter_contacts` | "Invite from contacts" flow — pick a phone contact and the share text is pre-prepped with their name. |
| Biometrics / app lock | `local_auth` | Optional Face ID / fingerprint gate before the app reveals balances. Privacy-conscious adopters will want this. |

**Screenshot capture/share package:** *deferred*. The settlement-summary "share my totals with friends" use case is already covered by the existing PDF export pipeline (`expense_pdf_builder.dart` + `Printing.sharePdf`). Revisit only if user testing reveals a real demand for in-app screenshot sharing of, say, a chat thread.

---

## 5. Explicitly NOT adopting

- **Cloud OCR** *(Google Cloud Vision, AWS Textract, etc.)* — **conditional → revisit when** V1 telemetry on the on-device ML Kit path shows >20% of receipts mis-parsed (the receipt-ocr-spec defines the exact metric and threshold). Until then: avoid the per-call cost, the new failure modes, and the Cloud Function plumbing.
- **Screenshot capture/share package** *(`screenshot`, `screenshot_callback`, etc.)* — **firm.** The PDF export pipeline already covers the settlement-summary share. No journey identified for in-app screenshot sharing.
- **State-management swap** *(Bloc, MobX, Provider, GetX, etc.)* — **firm.** Riverpod 3 is in place across the app; no migration justified.

---

## 6. Follow-up specs index

In V1 priority order:

1. **`invite-share-spec.md`** — surface the Share Invite affordance from event detail; add post-create share prompt. *(must-ship; uses `share_plus` already in pubspec.)*
2. **`receipt-ocr-spec.md`** — wire `google_mlkit_text_recognition`; mobile-only with `kIsWeb` fallback; bundle-size + first-launch model-download UX. *(should-ship.)*
3. **`qr-invite-spec.md`** — `qr_flutter`-backed QR generation for an invite code. *(nice-to-have.)*
4. **`deep-link-invite-spec.md`** — `app_links` or Firebase Hosting redirect-to-app for `crewpoint.sookoon.space/join/{code}`. *(nice-to-have.)*
5. **`connectivity-state-ui-spec.md`** — top-of-screen offline banner via `connectivity_plus`. *(nice-to-have.)*

(Section 5's NOT-adopting entries do not generate follow-up specs.)

---

*Section appended as Phase 1 of the V1 utilities audit work. The audit covers utility-shaped packages only; for architecture (Drift, Riverpod, GoRouter, Firebase), see [`docs/v1-progress-audit.md`](v1-progress-audit.md).*
