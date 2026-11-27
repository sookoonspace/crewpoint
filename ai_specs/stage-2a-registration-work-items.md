# Stage 2A: Registration — Work Items

Local copy of the Work Items for Spec [#233](https://github.com/sookoonspace/crewpoint/issues/233) (`ai_specs/stage-2a-registration-spec.md`). GitHub issues are the source of truth.

## #235 Stage 2A: Transactional email foundation

### What to build
The server side of 2A's email: a server-written outbox, an `EmailTransport` interface with one provider implementation (Resend or Postmark, chosen here by simple API and free tier) and a mock, a function that sends each outbox message, a delivery log with status per message, templates rendered on the server in the recipient's language with the event's words and no money amounts, push alongside email where the recipient has the app, and the dev and staging allowed list. Later Work Items add their own messages on top of this.

### Required context
- Spec #233 Req 51, 51a, 53, 54; Technical Decision 6; Testing Strategy 2 and 7.
- Push path: `functions/src/notifications/` (`sendCategorizedPush`, recipients read 300 at a time with `getAll`).
- Secrets: Secret Manager, like `serverSecrets` usage; never in the app or `.env*`.
- The sending domain is an Open Question: it blocks only turning on real delivery, needed by early January (L33).

### Acceptance criteria
- [ ] Clients cannot write the outbox or delivery log (rules tests); only server code enqueues messages.
- [ ] `EmailTransport` has a provider implementation and a mock; the provider API key is a Secret Manager secret.
- [ ] Each message is rendered from a server template in the recipient's language (English or Gujarati), using `resolveLabel` for event words, with no money amounts (Req 53).
- [ ] The delivery log records a status per message (queued, sent, failed, not sent).
- [ ] Dev and staging send only to an allowed list kept in a server setting; any other recipient is logged as "Not sent: not on the dev allowed list". Only prod sends to everyone (Req 51a).
- [ ] Real delivery stays off in every flavor until the sending domain's SPF, DKIM and DMARC are in place; a flag turns it on.
- [ ] Push is sent alongside email where the recipient has the app, through the existing push path (Req 54); email-only users still get every email (N-22).
- [ ] Backend tests: outbox written with the right recipient, language and template; sent only through the mock transport; N-00 proves no real email can be sent from tests.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 13
- Requirements: 51, 51a, 53, 54
- Technical Decisions: 6
- Testing Strategy: 2, 7
- Interview Ledger: L11, L33

### Blocked by
None - ready to start


## #236 Stage 2A: Translation pipeline and language choice

### What to build
Flutter gen-l10n ARB files (English and Gujarati) behind an `AppStrings` adapter so `context.strings` call sites stay as they are; a language choice (English / ગુજરાતી) on the event page before sign-in, kept on the device and then on `users/{uid}`; a Gujarati-capable font downloaded only when needed; the approved Gujarati spelling list with its CI check; and cspell on English strings. Screens built afterwards add Gujarati entries as they go; full translation of the path is #254.

### Required context
- Spec #233 Req 55, 56, 59, 59a; Technical Decision 7; Testing Strategy 8.
- `lib/app/core/i18n/app_strings.dart` (shaped for an ARB-backed adapter), CLAUDE.md UI conventions.
- `pubspec.yaml`: new packages carry their exact resolved version as the caret floor.

### Acceptance criteria
- [ ] gen-l10n is configured with English and Gujarati ARB files, and `context.strings` resolves through them with no call-site changes; a test fails if an English key is missing from the Gujarati file without an explicit English fallback.
- [ ] A person can choose English or ગુજરાતી before signing in; the choice is kept on the device, saved to `users/{uid}` after sign-in, and used for their emails (Req 56).
- [ ] Gujarati renders correctly on web and in the app with a bundled Gujarati font that downloads only when Gujarati is chosen or the event's default language is Gujarati; English visitors never download it (Req 59).
- [ ] `docs/i18n/gujarati-terms.md` and its data file list English term, approved Gujarati spelling and known wrong spellings, starting with દેરોદ (approved) / ડેરોડ (wrong), the registration path's words (actions, statuses, Yes / No / Maybe, days and months), the `GLOSSARY.md` terms and the convention's names (Req 59a).
- [ ] CI fails when a known wrong spelling appears in the Gujarati ARB file, templates, labels, email templates, seed data or fixtures, or when a Gujarati string spells a listed term another way (Req 59a, A-03).
- [ ] cspell runs on English strings in CI (Testing Strategy 8).
- [ ] Widget tests: the language switch, and a screen rendered in Gujarati at 320 px with 200% text.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 8
- Requirements: 55, 56, 59, 59a
- Technical Decisions: 7
- Testing Strategy: 3, 8
- Interview Ledger: L13, L31

### Blocked by
None - ready to start


## #237 Stage 2A: Phone numbers and phone linking

### What to build
Store phone numbers in international (E.164) form in private details wherever they come from (forms, imports, organizer edits), and extend Stage 1 account linking so a verified phone number links as a verified email does, including the HMAC keys used to link back after an account is deleted.

### Required context
- Spec #233 Req 13 (linking bullets) and Req 17 (Contact); Technical Decision 5; Testing Strategy 1.
- `functions/src/participants/linking.ts` (pure), `linkMyParticipants`, `participants/accountData.ts`, `participantKeys`, `serverSecrets/participantKeys`.
- Import mapping: `functions/src/imports/plan.ts`; app: `accountLinkerProvider`, `AccountLinkListener`.

### Acceptance criteria
- [ ] A pure phone normaliser turns entered numbers into E.164 (with the event's default country when no prefix is given) and rejects invalid ones; used by the form's Contact, imports and the person form.
- [ ] `linkMyParticipants` matches the token's verified `phone_number` against private-details phone numbers under the same rules as email: exactly one adult record links; two or more adults, or only children, open `linkRequests/{uid}`; never a child, never by name.
- [ ] `participantKeys` also keeps an HMAC key of the phone, so a deleted account's number links back and a re-import refills the entry.
- [ ] The app calls linking for a phone-verified account as it does for a verified email.
- [ ] Shared linking cases (fixtures) add phone matches, mixed email-and-phone matches and badly formatted numbers; TDD for the normaliser and matcher, one failing test at a time.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- Requirements: 13, 17
- Technical Decisions: 5
- Testing Strategy: 1, 2
- Interview Ledger: L24

### Blocked by
None - ready to start


## #238 Stage 2A: Several member invite links

### What to build
Replace today's one active invite per event with several member invite links, each with its own role, expiry and an optional single-use setting. Existing invites keep working.

### Required context
- Spec #233 Req 15; GAP-ANY-02, GAP-ANY-03 in `docs/guide/GAPS.md`.
- `event_invites/{code}`, `generateInviteCode`, `joinEvent`, `previewInvite`, `functions/src/events/inviteExpiry.ts`, `AddMemberSheet`, `dashboard/domain/models/invite.dart`.

### Acceptance criteria
- [ ] `members.manage` can create several invite links per event, each with a role, an expiry (same presets and 400-day cap as today) and an optional single-use setting; each can be turned off on its own.
- [ ] A single-use link stops working after one successful join; `previewInvite` explains why a used, expired or turned-off link cannot be used.
- [ ] Existing `event_invites` codes keep working unchanged.
- [ ] `AddMemberSheet` lists the event's links with role, expiry, use state, copy, QR and turn off.
- [ ] Backend tests for create, join, single use, expiry and turn-off; journey test for creating a second link with a different role.
- [ ] Acceptance tests GAP-ANY-02 and GAP-ANY-03 named by ID.
- [ ] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- Requirements: 15
- Testing Strategy: 2, 4, 6
- Interview Ledger: L19

### Blocked by
None - ready to start


## #239 Stage 2A: Registration settings

### What to build
The organizer's side of registration setup: `settings.registration` on the event and the **Event settings → Registration** screen holding the mode, capacity, deadline, review on or off, extra guests, sections and their order, built-in blocks, question conditions, the after-registration note and its replacement date, the role for people who register, the offer window and the slug, plus template defaults.

### Required context
- Spec #233 Req 3, 6, 8, 11 (slug), 16, 17–19 (configuration), 60 (role setting), 67; Technical Decision 1 (`settings.registration`, `eventSlugs`).
- Templates: `assets/templates/` (only place for event-specific words; `npm run gen:templates`), `createEvent`, saved templates (`saveAsTemplate`).
- Fields screen (`FieldsScreen`) stays the place to edit questions; `functions/src/shared/label_defaults.json` for RSVP / entry labels.
- Admin screen pattern: `AdminScaffold`, `AdminSaveBar` in `role_views.dart`.

### Acceptance criteria
- [ ] `settings.registration` holds `mode` (open / invited), `deadline` (date and time in the event's time zone), `review`, `extraGuests`, `sections` (named, ordered, each listing field IDs), `blocks` (People with birth date or age only, Stay, Session choices, Waivers, Contact), `afterNote` and its replacement date, `registrationRoleId` and `offerHours` (default 72); `capacity` stays where it is.
- [ ] A question's condition is a category, or one other answer's value; a condition cannot depend on a question that itself has a condition (validated on save).
- [ ] The slug (letters, numbers and hyphens) is claimed through a callable writing `eventSlugs/{slug}`, unique across CrewPoint, with a clear message when taken.
- [ ] Template defaults: open for Convention, Cricket tournament and Golf outing; invited for Wedding and Party; invited with personal links for Blank; templates set the registration words and role (for example Player). Saved templates keep the registration configuration.
- [ ] **Event settings → Registration** edits all of the above with `event.manage`, following the Person form pattern; Fields keep their Fields screen.
- [ ] Rules and role-matrix tests for `settings.registration` and `eventSlugs`; widget tests for the settings screen at 320 px with 200% text.
- [ ] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 9
- Requirements: 3, 6, 8, 11, 16, 17, 18, 19, 60, 67
- Technical Decisions: 1
- Testing Strategy: 2, 3
- Interview Ledger: L5, L6, L16, L17

### Blocked by
None - ready to start


## #240 Stage 2A: Public event page and routes

### What to build
The public entry to an event: an unauthenticated event page callable with App Check and rate limits, the `/e/:eventSlug` route outside the shell with no sign-in or onboarding, the router's public-route rules, open/closed states, the QR code, and a small server-rendered first page with link-preview tags that the Flutter app takes over, measured against the speed budget.

### Required context
- Spec #233 Req 9, 10, 11 (QR), 13a (event page), 14, 69, 70; Technical Decision 3; Testing Strategy 3.
- Router: `lib/app/core/router/app_router.dart` (`_RouterRefresh`, `?from=` accepting only `/join/` today), `/join/:code` (`JoinScreen`), `previewInvite`.
- Hosting rewrites in `firebase.json`; `scripts/build_web.sh`; `docs/web-hosting-guide.md`; `docs/testing/load-baselines.md`.
- `qrRendererProvider`, `FakeQrRenderer`.

### Acceptance criteria
- [ ] The event page callable accepts visitors who aren't signed in and returns only public fields: title, dates, time zone, venues, description, what is included, the deadline and whether places remain (never a number, other participants or money) (Req 10).
- [ ] Firebase App Check is required on it (started only in `main`; tests and emulators skip it), and about 60 opens a minute from one address are allowed; beyond that the page shows "Please try again in a few minutes" (Req 13a).
- [ ] Events are reached only by slug; event IDs are never returned. A `draft` event shows "Not open yet" without details; `ended` or `archived` shows that registration has closed (Req 14).
- [ ] `/e/:eventSlug` is a top-level route needing no sign-in and skipping onboarding for signed-out, new and signed-in visitors; `?from=` also accepts `/e/` and `/r/` paths and still refuses anything else (Req 9).
- [ ] The page shows a QR code of its link (Req 11) and, for open events, Register.
- [ ] A Hosting rewrite sends `/e/:eventSlug` to a function that renders a small page with the title, dates, place, a Register button and link-preview tags (event name, cover photo); the Flutter app loads behind it and takes over (Req 69).
- [ ] Speed measured under Req 69's conditions (Chrome DevTools "Fast 4G", 4x CPU slowdown, empty cache, release build on dev Hosting, median of 5 runs, plus one real mid-range Android check): content (title, dates, place visible) within 4 s, usable (Register tappable, first field typeable) within 6 s; results recorded in `docs/testing/load-baselines.md`. A miss is reported to the owner, not accepted silently.
- [ ] Works on iOS Safari 16+, Chrome on Android, and desktop Chrome, Safari, Edge and Firefox (Req 70).
- [ ] Router tests open `/e/:eventSlug` signed out, new and signed in, and refuse a `from=` outside `/join/`, `/e/` and `/r/`; backend tests for public fields only, draft and ended states, and the rate limit.
- [ ] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 1
- Requirements: 9, 10, 11, 13a, 14, 69, 70
- Technical Decisions: 3, 13
- Testing Strategy: 2, 3, 7
- Interview Ledger: L5, L14, L21, L23, L28

### Blocked by
- #239


## #241 Stage 2A: Light sign-in for registration

### What to build
The light sign-in Register needs: email sign-in links through the flavor's Hosting domain with App Links and Universal Links, the "different device" and "expired link" screens, Firebase phone codes limited to the US, Canada and the UK, Google and Apple as today, asked only when the event requires an account, with onboarding deferred until the app is next opened normally.

### Required context
- Spec #233 Req 9 (sign-in bullet), 12; Technical Decision 5; Testing Strategy 5 and 7.
- `IAuthService` and its fakes; onboarding redirect in `app_router.dart`; `AccountLinkListener`.
- Firebase Dynamic Links no longer exist; email links use the Hosting domain. Android `assetlinks.json`, iOS `apple-app-site-association`, per flavor; don't hand-edit `firebase_options*`.
- `pubspec.yaml`: exact resolved versions for any incoming-links package.

### Acceptance criteria
- [ ] `IAuthService` gains send/complete email sign-in link and send/confirm phone code; the email is sent with CrewPoint's own wording.
- [ ] The link opens the web app on the flavor's Hosting domain, finishes sign-in and returns to where the person started; App Links and Universal Links association files and app settings per flavor open the installed app instead.
- [ ] Opened on another device: "Confirm your email to finish signing in" with the email field and Continue; a different address shows "This link was sent to a different email".
- [ ] An expired or used link shows "This sign-in link has expired or was already used" with **Send a new link**; phone code and Google or Apple stay on the same screen.
- [ ] Phone codes are limited to US, CA and GB in Firebase settings; the same email by any method is one account (L-06).
- [ ] Register and `/e/:eventSlug/registration` ask for sign-in only when the event requires an account, and return straight to the form; someone who signed in only to register sees onboarding the next time they open the app normally (Req 9).
- [ ] `IIncomingLinkSource` (stream of opened links including the launch link) with a fake that pushes links; no widget calls a plugin directly.
- [ ] Widget tests for the sign-in screens (other device, expired link); router tests for `/e/:eventSlug/registration` signed out, new and signed in.
- [ ] Manual check recorded: a link opened on iPhone and Android, with and without the app, and on a second device; a real SMS code to US, Canadian and UK numbers.
- [ ] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 3
- Requirements: 9, 12
- Technical Decisions: 5
- Testing Strategy: 3, 5, 7
- Interview Ledger: L8, L23, L25, L30

### Blocked by
- #240


## #242 Stage 2A: Register a group (form, review and submit)

### What to build
The family-facing core: the form built from the event's sections and built-in blocks (People, Stay, Session choices with either/or, Contact), one-level conditions, the review page, an idempotent submit callable that checks capacity through `registrationTally/current` and waitlists whole groups, Participants written on first save, registration status mirrored onto groups and people, the confirmation screen and email, the after-registration note, and "my registration". No money anywhere.

### Required context
- Spec #233 Req 1, 2, 4, 4a, 7, 17–22, 25, 32, 32a, 33, 52 (confirmation), 71, 72; Technical Decisions 1, 2, 4, 9; Testing Strategy 1–4.
- Participants and private details (#75), custom fields and `AnswerInput` (#76), `GroupDraft` and `GroupEntryController` (Person form pattern), attendance `signUps`, `arrivalAt`/`departureAt` (#82), category rules (`category.dart`), `computeStats` (#83).
- Robot harnesses in `test/harness/`, robots in `test/robots/`; bounded pumps instead of `pumpAndSettle` over mirrors.

### Acceptance criteria
- [x] `registrations/{registrationId}` per Technical Decision 1 (`groupId`, `contactUid`, `status`, `submittedAt`, `updatedAt`, `waitlistPosition`, `cancelReason`, `mergedInto`, `duplicateOf`, `extraGuestsAllowed`, last `submissionId`); statuses `draft`, `submitted`, `pending` (only when review is on), `waitlisted`, `cancelled` with Req 4's effects.
- [x] Registering owns exactly one Group; its people are written as Participants on first save; a group of one hides group words (Req 1, 2).
- [x] The form renders sections in order with the enabled blocks: People (name and birth date, or age only; category worked out as today), Stay, Session choices (two by-sign-up sessions at the same time shown as one either/or choice, W-01), Contact (email and E.164 phone, private).
- [x] Conditions (category, or one answer's value) show and hide questions; hidden questions are never required and their answers are not saved. Pure evaluator built TDD with shared fixtures (Req 18).
- [x] Required questions and the People block are checked on Submit, with errors beside the field and a count at the top (Req 21); private answers and birth dates follow Stage 1 rules (Req 22).
- [x] Review page lists every person and answer with Edit per section, then Submit; the confirmation screen follows (Req 20).
- [x] Submit is a callable taking a `submissionId`; a repeat with the same ID returns the first result; in one transaction it reads and updates `registrationTally/current` (no Firestore count query); two submissions for the last places get them in turn and the one that no longer fits is waitlisted (Req 25, 32a, TD 4).
- [x] A group that would exceed capacity is waitlisted whole and sees "You're on the waitlist, number N" (Req 33).
- [ ] The server mirrors registration status onto the group and its people; confirmed counts (submitted plus organizer-added) drive sessions, agendas, exports and Counts; `pending` counts toward capacity only (Req 4a). *Done for the mirror, Counts and session counts (#275, #278). The roster export and agendas do not yet tell confirmed from waitlisted people: the export's status column is #249.*
- [x] The confirmation email lists who and what was registered with a link back to "my registration" (N-01), through #235's outbox.
- [x] Only `submitted` groups see the after-registration note, replaced after its date (Req 19, B-07, B-15).
- [x] `/e/:eventSlug/registration` shows "my registration" to the contact. No fee is shown anywhere (Req 7).
- [x] TDD for the allocator (whole groups, next group that fits), condition evaluation and either/or choices; backend tests for submit success, refusals, idempotency and the two-submit race on the emulators.
- [x] Robot journey: a family registers on an open event: event page, email sign-in (fake), sections, stays, session choices, review, submit, confirmation, "my registration"; and a full event waitlists a group.
- [x] Acceptance tests named by ID for the scenarios this delivers (B-01 to B-03, B-07, B-09, B-15, W-01, N-01), `scenarios.json` updated. *B-01, B-07, W-01 and N-01 pass; B-02, B-09 and B-15 are PARTIAL with tests; B-03 is PARTIAL. Arrival times (B-02) and meal opt-outs (B-03) moved to #244 by the owner.*
- [x] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [x] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [x] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [x] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 1, 7, 13
- Requirements: 1, 2, 4, 4a, 7, 17, 18, 19, 20, 21, 22, 25, 32, 32a, 33, 52, 71, 72
- Technical Decisions: 1, 2, 4, 9
- Testing Strategy: 1, 2, 3, 4, 6
- Interview Ledger: L1, L4, L6, L9, L18, L20, L26

### Blocked by
- #235
- #239
- #240
- #241


## #243 Stage 2A: Drafts and connection loss

### What to build
Answers kept on the device as they are typed through `IDraftStore`, server drafts saved when connected, the "Saved" / "Not saved yet: no connection" indicator, and the offline Submit message through `IConnectivity`.

### Required context
- Spec #233 Req 23–25; Technical Decision 8; Testing Strategy 4 and 5.
- `IConnectivity` / `FirestoreConnectivity` (`core/services/connectivity.dart`); harness seams pattern.

### Acceptance criteria
- [x] `IDraftStore` saves, loads and clears one draft per event and person: browser storage on web, local storage on mobile; a memory fake in tests. Cleared once submitted (Req 23).
- [x] When connected, the draft is saved to the server (`registrations` document with status `draft`) after a few seconds without typing and on moving between sections; "Saved" or "Not saved yet: no connection" shows at the top (Req 24).
- [x] Offline, Submit shows "You're offline. Your answers are kept; submit when you're back online." A submission is never queued to send later (Req 25).
- [x] Reopening the form restores the newest of the device and server drafts.
- [x] Widget tests for the saved and offline indicators; robot journey: a draft survives a reload and a lost connection, and a double submit creates one registration.
- [x] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [x] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [x] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 2
- Requirements: 23, 24, 25
- Technical Decisions: 8
- Testing Strategy: 3, 4, 5
- Interview Ledger: L18, L30

### Blocked by
- #242


## #244 Stage 2A: Edits, deadline and change log

### What to build
Free edits before the deadline, "Registration is closed" after it with what families can still do, a server-written change log for every change, and refusing extra people when there is no room.

### Required context
- Spec #233 Req 32a (adding people), 35, 36; B-06, B-13 in the convention test.
- `clockProvider` / injected `Clock`; `event.inZone` for times.

### Acceptance criteria
- [x] Before the deadline the contact edits their registration freely; every change writes `changes/{changeId}` (server only) with who, when, which field, and before and after values; `registrations.manage` reads the log (Req 36, B-06). The change-log diff is pure and built TDD.
- [x] After the deadline (a date and time in the event's time zone) the link shows "Registration is closed" with the organizer's contact line; new submissions are refused; families can still view their registration, accept waivers and update contact details; other changes are refused (Req 35, B-13). *Accepting waivers after the deadline comes with the waivers themselves (#246). Committee changes after the deadline are #249, so B-06 and B-13 are PARTIAL until then.*
- [x] Adding people to a submitted group with no room is refused with "There's no room to add more people. Please contact the organizer." and the group's existing places are kept (Req 32a).
- [x] Arrival and departure **times**, not only days, on the form's Stay step (and when editing), in the event's time zone, so someone arriving Saturday 11:00am is left out of Friday's meals and Saturday breakfast (B-02; moved from #242 by the owner, Nov 26, 2026).
- [x] Per-person **meal opt-outs** on the form (and when editing) for sessions everyone attends, written to Stage 1's `optOuts` and checked by the server, so Jaya opting out of M2 is not counted for it (B-03; moved from #242 by the owner, Nov 26, 2026).
- [x] Backend tests with an injected clock for before and after the deadline; widget test for the closed state.
- [x] Acceptance tests B-02, B-03, B-06 and B-13 named by ID; B-02 and B-03 move from PARTIAL to PASS in `scenarios.json`.
- [x] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [x] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [x] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [x] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 2, 12
- Requirements: 32a, 35, 36
- Testing Strategy: 1, 2, 6
- Interview Ledger: L9, L26

### Blocked by
- #242


## #245 Stage 2A: Membership through the registration role

### What to build
Submitting (or accepting a waitlist offer) makes the contact and each linked adult a member with the event's "role for people who register"; cancelling or merging away removes it.

### Required context
- Spec #233 Req 60–63; Technical Decision 10.
- Member documents (`events/{id}/members/{uid}`), `computePermissions`, `memberIds`/`adminIds` arrays, draft-event rule (plain members never in a draft).

### Acceptance criteria
- [ ] Submitting a registration, or accepting a waitlist offer, makes the contact and each linked adult a member with `registrationRoleId` (Participant by default); existing members keep their roles and gain this one (Req 60).
- [ ] Cancelling or merging away removes the registration role; the person stays a member only if they hold another role (Req 61).
- [ ] Personal RSVP links create no member until the guest signs in and is linked; children never become members (Req 62).
- [ ] Member documents are written only by the server, `permissions` comes from `computePermissions`, and the arrays stay in step (Req 63).
- [ ] Backend tests for each case, including an existing Admin who registers.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 14
- Requirements: 60, 61, 62, 63
- Technical Decisions: 10
- Testing Strategy: 2
- Interview Ledger: L17

### Blocked by
- #242


## #246 Stage 2A: Waivers and contact consent

### What to build
Organizer-written waivers with versions and an "applies to", server-written acceptances per person (including as guardian), required waivers blocking Submit, the Missing waiver list and its email, and contact consent stored for Stage 3.

### Required context
- Spec #233 Req 26–29, 31, 52 (waiver missing), 65 (Missing waiver); Technical Decision 1 (`waivers/{waiverId}`, `versions/{n}`).
- The convention's waiver text is an Open Question; use placeholder text.

### Acceptance criteria
- [ ] A waiver has a title, a version, an "applies to" (everyone, a category, or people signed up for a session) and whether it is required to register; edited in Event settings → Registration (Req 26).
- [ ] Acceptance is recorded per person, written only by the server and never edited: who accepted (contact or linked adult, as the person or as guardian for a minor), when, which version (Req 27).
- [ ] Changing a waiver's text makes a new version; earlier acceptances show as an earlier version and the organizer chooses whether the new version must be accepted (Req 28).
- [ ] A required waiver blocks Submit until accepted for everyone it applies to; others can be accepted later, including after the deadline (Req 29).
- [ ] People gains the "Missing waiver" filter, and `registrations.manage` sends the waiver-missing email by hand from it (W-05, W-06).
- [ ] Contact consent for announcements by email and by SMS is asked once per registration, separate from essential messages, and stored for Stage 3 (Req 31).
- [ ] TDD for waiver applicability and version status; rules and role-matrix tests for waivers and acceptances.
- [ ] Acceptance tests W-05, W-06 and Z-03 (placeholder text) named by ID.
- [ ] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 5
- Requirements: 26, 27, 28, 29, 31, 52, 65
- Technical Decisions: 1
- Testing Strategy: 1, 2, 6
- Interview Ledger: L7

### Blocked by
- #242
- #235


## #247 Stage 2A: Photo consent

### What to build
A built-in photo and video consent yes/no per person, a `photoConsent.read` permission, a Convention "Photographer" role, a server-kept list of who said no or hasn't answered, and a Photo consent screen.

### Required context
- Spec #233 Req 30; Technical Decisions 1 and 12; Testing Strategy 2.
- Permission catalogue in `functions/src/events/permissions.ts`, presets via `npm run gen:roles` (`role_presets.json`), `roleMatrix.test.ts`; Convention template in `assets/templates/`.

### Acceptance criteria
- [ ] Photo and video consent is a built-in yes/no per person on the form, unanswered by default, answered by a guardian for children, stored in private details.
- [ ] `photoConsent.read` joins the catalogue; Owner, Co-owner and Admin hold it; organizers can grant it to any role. The Convention template adds a "Photographer" role with only it and the basic read permissions.
- [ ] The server rebuilds `photoConsent/current` whenever an answer changes; it holds only name, group name and age band, marked **No** or **Not answered**; readable only with `photoConsent.read`.
- [ ] A **Photo consent** screen (hub entry only for `photoConsent.read`) shows "Said no" and "Not answered yet" with a name search and a note to treat "Not answered" as no.
- [ ] Counts show Yes, No and Not answered totals.
- [ ] Rules test: `photoConsent.read` alone reads neither private details nor the roster; role-matrix entry for the new path; the list updates when a guardian changes an answer.
- [ ] Acceptance test Z-02 named by ID.
- [ ] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 5
- Requirements: 30
- Technical Decisions: 1, 12
- Testing Strategy: 2, 6
- Interview Ledger: L7, L27

### Blocked by
- #242


## #248 Stage 2A: Waitlist offers and capacity upkeep

### What to build
Offers that hold their places when places free up, Accept and No thanks on "my registration", expiry every 15 minutes, skipped groups keeping their number, organizer withdraw, extend and offer by hand, lowering capacity without removing anyone, and a nightly recount of the tally.

### Required context
- Spec #233 Req 32, 32a, 34, 52 (offer); Technical Decision 11; Testing Strategy 1, 2, 4.
- Scheduled functions pattern: `onCountsScheduled`, `onEventStatusScheduled`; injected `Clock`.

### Acceptance criteria
- [ ] When places free up, the first waitlisted group that fits is offered them by email and push for `offerHours` (72 by default); the offer holds its places in the tally; several offers can be open at once.
- [ ] The offer email's **Accept my place** opens "my registration" (signing in if needed), showing "A place is available for your group until {date and time}" in the event's time zone with **Accept** and **No thanks**.
- [ ] Accepting makes the registration `submitted` and sends the confirmation; **No thanks**, after a confirm, takes the group off the waitlist and offers the places onward at once.
- [ ] A scheduled function every 15 minutes expires late offers, offers the places onward and emails "Your offer has expired"; the group moves to the end of the queue.
- [ ] A larger group skipped because it did not fit keeps its position.
- [ ] Organizers see open offers with expiry on the waitlist (queue order, "Offer a place") and can withdraw or extend one; no automatic offers after the deadline.
- [ ] Lowering capacity below places used removes nobody and shows how far over the event is; a nightly recount corrects tally drift and logs the correction.
- [ ] TDD for the allocator (skips, several offers, expiry) with an injected clock; emulator test of acceptance racing expiry; robot journey: a full event waitlists a group, a cancellation offers the place, and the group accepts.
- [ ] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 10
- Requirements: 32, 32a, 34, 52, 65
- Technical Decisions: 11
- Testing Strategy: 1, 2, 4
- Interview Ledger: L9, L26, L29

### Blocked by
- #242
- #235


## #249 Stage 2A: Registration summary and organizer actions

### What to build
The committee's view: a Registration hub entry and summary with status and not-yet-confirmed counts linking to follow-up lists, a Counts line, People filters by status, the group detail's registration actions, the over-capacity warning, the closing reminder, "complete your registration" links and the roster export's new columns.

### Required context
- Spec #233 Req 4 (pending), 4a (display), 5, 37, 52 (closing reminder), 64–66, 68.
- `RosterScreen`, `rosterFiltersProvider`, `GroupSheet`, `CountsScreen`, `exportRoster`, `neutraliseCsvCell` / `toCsv`; `registrations.manage` permission.

### Acceptance criteria
- [ ] The event home shows **Registration** to `registrations.manage`; the summary shows counts by status (submitted, pending review, waitlisted, cancelled, drafts not yet sent), not-yet-confirmed counts in groups and people (drafts, pending, waitlisted, Maybe, not answered) each opening its follow-up list, capacity used, the deadline, and the public link and QR with copy and share (Req 64, 4a).
- [ ] Counts shows a line of not-yet-confirmed totals (Req 4a).
- [ ] People gains filters for registration status and each group row shows its status as a tag (Req 65).
- [ ] A group's detail shows status, change log, contact and linked adults, waiver acceptances per person, and actions approve (when review is on), waitlist, cancel, reinstate, resend confirmation and send a "complete your registration" link, which attaches a registration to an organizer-added group (Req 5, 66).
- [ ] `registrations.manage` can add, edit, approve, waitlist, cancel and reinstate at any time, including after the deadline; going over capacity shows a warning they must confirm (Req 37, B-12).
- [ ] A closing reminder is sent by hand by email (Req 52).
- [ ] The roster export adds registration status, contact, submitted date and waiver acceptances per person (Req 68).
- [ ] Widget tests for the summary at 320 px with 200% text; backend tests for each action's permission and refusal paths.
- [ ] Acceptance tests B-12 and B-16 named by ID.
- [ ] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 11
- Requirements: 4, 4a, 5, 37, 52, 64, 65, 66, 68
- Testing Strategy: 2, 3, 6
- Interview Ledger: L16, L20

### Blocked by
- #242
- #235


## #250 Stage 2A: Duplicates and merge

### What to build
Flag likely duplicates on submit without telling the submitter, list them for the committee, merge side by side, clear a pair with "Not a duplicate", and note any payment for finance.

### Required context
- Spec #233 Req 38–42, 65 (Possible duplicates); B-11.
- Group detail and People filters from #249.

### Acceptance criteria
- [ ] On submit the server flags a likely duplicate: normalised name (case, spacing, accents ignored) and birth date match, or normalised name and the group's contact email or phone match; the registration still goes in and the submitter is never told (Req 38). Pure matcher built TDD.
- [ ] People gains "Possible duplicates"; `registrations.manage` opens two groups side by side, chooses which to keep and which people are the same, and merges (Req 39).
- [ ] A merge moves new people into the kept group, keeps matched people once (filling blank answers), marks the other registration `cancelled` as merged, updates counts at once, logs the merge, and removes the duplicate contact's access unless they are an adult in the kept group (Req 40, B-11).
- [ ] "Not a duplicate" clears the flag for that pair for good (Req 41); a merged-away payment is noted for finance (Req 42).
- [ ] Robot journey: the committee merges a flagged duplicate; backend tests for the merge transaction.
- [ ] Acceptance tests B-08 and B-11 named by ID.
- [ ] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 11
- Requirements: 38, 39, 40, 41, 42, 65
- Testing Strategy: 1, 2, 4, 6
- Interview Ledger: L10

### Blocked by
- #249


## #251 Stage 2A: Linked adults

### What to build
The contact invites other adults in the group by email (emailed) or phone (shared from their own phone through `IShareSheet`); invites last 14 days and work only for the email or phone they were sent to; linked adults can do everything the contact can on that group only; the contact can remove a linked adult and hand over the contact role.

### Required context
- Spec #233 Req 43–46, 52 (family invite); Testing Strategy 4 and 5.
- Groups' `adultUids`, `group.editOwn`, `setGroupAdults`; phone linking from #237.
- `pubspec.yaml`: exact resolved version for any share package.

### Acceptance criteria
- [ ] The contact invites another adult in the group by email (the family invite email, N-02) or by phone (the invite link sent from their own phone through `IShareSheet`; CrewPoint sends no SMS) (Req 43).
- [ ] Only adults (18+ on the event's first day) can be invited; an invite works only for the email or phone it was sent to, expires after 14 days, and can be resent; children never get accounts this way (Req 45).
- [ ] Accepting by signing in with that email or phone (or Google/Apple with that email) makes them a linked adult (`adultUids`, `group.editOwn`) who can do everything the contact can on that group, including waivers for themselves and the group's children, and sees no other group (Req 44, L-05).
- [ ] The contact can remove a linked adult and hand the contact role to another; a group always has exactly one contact (Req 46).
- [ ] `IShareSheet` (share text and a link) with a fake that records shares.
- [ ] Robot journey: a contact invites a family member, who edits the registration and sees no other group.
- [ ] Acceptance tests L-05 and N-02 named by ID.
- [ ] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 4
- Requirements: 43, 44, 45, 46, 52
- Testing Strategy: 2, 4, 5, 6
- Interview Ledger: L12, L24, L30

### Blocked by
- #242
- #235
- #237


## #252 Stage 2A: Personal RSVP links and answers

### What to build
`/r/:token` personal links that need no account: hashed 128-bit tokens, rate limits and "no longer valid", Yes / No / Maybe per invited guest, extra guests, Maybe shown separately, turning a link off or replacing it, and the "Not answered" filter.

### Required context
- Spec #233 Req 13, 13a (links), 47–49, 62, 65 (Not answered); Technical Decision 1 (`registrationLinks/{tokenHash}`, `rsvp`).
- Router public-route rules from #240.

### Acceptance criteria
- [ ] Each invited group gets one link token (random, at least 128 bits) stored as `registrationLinks/{tokenHash}`; `/r/:token` needs no sign-in or onboarding and opens only that group (Req 13).
- [ ] The link callables accept visitors who aren't signed in, require App Check, and allow about 30 RSVP saves an hour per link ("Please try again in a few minutes" beyond); a missing, wrong or turned-off token shows "This invitation is no longer valid" (Req 13a).
- [ ] The page lists the group's invited guests by name; each is **Yes**, **No** or **Maybe**, with any questions the form asks; one person can answer for the party; answers change until the deadline (Req 47).
- [ ] Yes counts like submitted; Maybe shows separately ("42 coming, 6 maybe") and is not in meal or session counts; No stays on the guest list as declined (Req 48).
- [ ] Extra guests up to the group's allowance (0 by default), each by name or as "Guest of <name>", counting like invited guests (Req 49, WE-01).
- [ ] `registrations.manage` can turn a link off or replace it at any time; links create no member until the guest signs in and is linked (Req 62).
- [ ] People gains "Not answered" (Req 65).
- [ ] TDD for RSVP counts (yes, maybe, no, extras); backend tests for missing, wrong and turned-off tokens and the rate limit; robot journey: an RSVP with Yes, Maybe, a plus-one and a declined guest.
- [ ] Acceptance tests WE-01, WE-03 to WE-05, PA-02 and GAP-WED-13 named by ID (those this delivers).
- [ ] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 6
- Requirements: 13, 13a, 47, 48, 49, 62, 65
- Technical Decisions: 1
- Testing Strategy: 1, 2, 4, 6
- Interview Ledger: L5, L15, L21

### Blocked by
- #242


## #253 Stage 2A: Personal link delivery and reminders

### What to build
Getting personal links to guests: create one or all, the invitation email, copy, share sheet, QR and CSV export, Not sent / Sent / Opened / Answered tracking, and "Remind those who haven't answered".

### Required context
- Spec #233 Req 13b, 50, 52 (RSVP invitation, reminder).
- `IShareSheet` from #251 (create it here if 17 has not landed); `qrRendererProvider`; CSV via `neutraliseCsvCell`.

### Acceptance criteria
- [ ] `registrations.manage` creates a link for one group from its detail, or "Create links for all invited groups" from the Registration summary; groups with a link keep it.
- [ ] The invitation email (event name, date, button to the link) goes to one group or every group with an email not yet sent one, through the outbox.
- [ ] Each group offers copy link, the share sheet and a QR code; a CSV export lists group name, contact and link.
- [ ] Each invited group shows **Not sent**, **Sent**, **Opened** or **Answered** (`registrationLinks` delivery state), filterable on the Registration summary.
- [ ] "Remind those who haven't answered" emails parties with no answer (Req 50, WE-02).
- [ ] No SMS is sent by CrewPoint.
- [ ] Widget tests for the link actions; backend tests for bulk creation, invitation sends and state changes.
- [ ] Acceptance test WE-02 named by ID.
- [ ] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 6
- Requirements: 13b, 50, 52
- Testing Strategy: 2, 3, 6
- Interview Ledger: L15, L22, L30

### Blocked by
- #252
- #235


## #254 Stage 2A: Gujarati across the registration path

### What to build
Every screen and email on the registration path in Gujarati, organizers entering the event's own words in both languages, and the Gujarati robot journey.

### Required context
- Spec #233 Req 57, 58; Testing Strategy 4.
- ARB pipeline and spelling list from #236; the owner reviews the Gujarati (#255).

### Acceptance criteria
- [ ] Every registration-path screen and email is translated: event page, sign-in, form, review, confirmation, "my registration", family invites, RSVP links, waitlist offers and the 2A emails; other screens stay English (Req 57).
- [ ] Organizers enter the event's own words in both languages (labels, section names, field labels and options, waiver text, the after-registration note); missing Gujarati falls back to English (Req 58).
- [ ] The spelling-list CI check passes on all new strings.
- [ ] Robot journey: the registration path in Gujarati, end to end.
- [ ] Acceptance tests U-03 and A-03 named by ID.
- [ ] Quality floor (Req 71): 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with icon and colour together, all text through `context.strings` (English and Gujarati ARB entries), general concepts through `event.words`; design system only (guard test passes); a `domain.feature.action` key on every new interactive widget.
- [ ] `cd functions && npm run build` and `npm test` pass on the `demo-crewpoint` emulators; every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`) and every new restricted path joins `roleMatrix.test.ts`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass; no test initialises Firebase or touches a real project; naming guardrail passes.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- User Stories: 8
- Requirements: 57, 58
- Testing Strategy: 4, 6
- Interview Ledger: L13

### Blocked by
- #236
- #240
- #241
- #242
- #243
- #244
- #246
- #248
- #251
- #252
- #253


## #255 Stage 2A: Release readiness

### What to build
Close out 2A: the release checklist with the owner's Gujarati sign-off and the manual checks, the acceptance suite brought up to date, and the Spec's follow-ups.

### Required context
- Spec #233 Req 59b, 69 (record); Testing Strategy 6, 7; Follow-Ups.
- `test_acceptance/fixtures/scenarios.json`, `finished_scenarios.json`, `check_finished.py`, `generate_report.py`, `docs/testing/CONVENTION_TEST_REPORT_v4.md`, `scripts/check_platform_plan.py`.
- L32 (glossary terms) was delivered by PR #234.

### Acceptance criteria
- [ ] `docs/release/registration-release-checklist.md` exists and is complete: "Gujarati reviewed by a native speaker" signed off by the owner from a generated sheet of every Gujarati string added or changed since the last release beside its English (each OK or corrected; corrections join the spelling list); cspell green; the manual checks of Testing Strategy 7 (Req 59b).
- [ ] Manual checks recorded: real email delivery to Gmail, Outlook and Yahoo from the sending domain (O-04); a real SMS code to US, Canadian and UK numbers; email links on iPhone and Android with and without the app and on a second device; the speed budget under Req 69's conditions in `docs/testing/load-baselines.md`; Savita's unaided web registration in Gujarati (U-05).
- [ ] Scenarios L-03 to L-07, B-01 to B-03, B-06 to B-09, B-11 to B-13, B-15, B-16, W-01, W-05, Z-02, Z-03, N-01, N-02, N-22, PA-02, WE-01 to WE-05, GAP-WED-13, GAP-ANY-02 and GAP-ANY-03 have tests named by ID; `scenarios.json` is updated, finished ones are in `finished_scenarios.json`, and the v4 report is regenerated.
- [ ] L-04 in `docs/testing/CREWPOINT_CONVENTION_TEST_v4.md` reads "email sign-in link"; `ai_specs/event-platform-plan.md` shows Stage 2 split into 2A, 2B, 2C and the raffle, with basic email and registration-path Gujarati in 2A; `scripts/check_platform_plan.py` passes.
- [ ] CLAUDE.md's Architecture sections cover registrations, public routes, email and languages.
- [ ] Acceptance suite and both CI suites green.
- [ ] Merges after green CI and the owner's go-ahead; reaches dev only with the owner's approval for that deploy; stg and prod are untouched. CLAUDE.md's Architecture section is updated for what landed.

### Covers
- Requirements: 59b, 69
- Testing Strategy: 6, 7
- Interview Ledger: L2, L3, L14, L28, L31, L32

### Blocked by
- #235
- #236
- #237
- #238
- #239
- #240
- #241
- #242
- #243
- #244
- #245
- #246
- #247
- #248
- #249
- #250
- #251
- #252
- #253
- #254
