# Stage 1: Platform foundation — Work Items

Local copy of the Work Items for [Spec #44](https://github.com/sookoonspace/crewpoint/issues/44). The GitHub issues linked below are the source of truth, and this copy follows them. Generated on 2026-11-03.

Local Spec copy: `ai_specs/stage-1-platform-foundation-spec.md`.

## Index

| Slice | Issue | Work Item | Blocked by |
|---|---|---|---|
| 1.1 | [#46](https://github.com/sookoonspace/crewpoint/issues/46) | Glossary and naming guardrail | None |
| 1.1 | [#47](https://github.com/sookoonspace/crewpoint/issues/47) | Backlog and gap triage | None |
| 1.1 | [#48](https://github.com/sookoonspace/crewpoint/issues/48) | Backend tests in CI and general acceptance suite | None |
| 1.2 | [#49](https://github.com/sookoonspace/crewpoint/issues/49) | Server-validated expenses | #48 |
| 1.2 | [#50](https://github.com/sookoonspace/crewpoint/issues/50) | Server-written settlements and notices | #49 |
| 1.2 | [#51](https://github.com/sookoonspace/crewpoint/issues/51) | createEvent callable and no added strangers | #48 |
| 1.2 | [#52](https://github.com/sookoonspace/crewpoint/issues/52) | Urgent message limits and message size | #48 |
| 1.2 | [#53](https://github.com/sookoonspace/crewpoint/issues/53) | Task permissions | #48 |
| 1.2 | [#54](https://github.com/sookoonspace/crewpoint/issues/54) | memberLimit and safe joins | #48 |
| 1.2 | [#55](https://github.com/sookoonspace/crewpoint/issues/55) | CSV formula neutralising | #48 |
| 1.2 | [#56](https://github.com/sookoonspace/crewpoint/issues/56) | Complete deletion | #48 |
| 1.2 | [#57](https://github.com/sookoonspace/crewpoint/issues/57) | Departed members and dispute window | #48 |
| 1.2 | [#58](https://github.com/sookoonspace/crewpoint/issues/58) | Administration limits | #48 |
| 1.3 | [#59](https://github.com/sookoonspace/crewpoint/issues/59) | Event configuration and settings screen | #51, #52 |
| 1.3 | [#60](https://github.com/sookoonspace/crewpoint/issues/60) | Status lifecycle | #59 |
| 1.3 | [#61](https://github.com/sookoonspace/crewpoint/issues/61) | Label resolver | #59 |
| 1.3 | [#62](https://github.com/sookoonspace/crewpoint/issues/62) | Modules and event hub | #59 |
| 1.3 | [#63](https://github.com/sookoonspace/crewpoint/issues/63) | Event time zones | #59 |
| 1.4 | [#64](https://github.com/sookoonspace/crewpoint/issues/64) | Minimum app version | None |
| 1.4 | [#65](https://github.com/sookoonspace/crewpoint/issues/65) | Permissions, presets, member documents and migration script | #48, #51, #59, #60 |
| 1.4 | [#66](https://github.com/sookoonspace/crewpoint/issues/66) | Cutover to permissions | #49, #50, #51, #52, #53, #54, #56, #57, #58, #60, #62, #64, #65 |
| 1.4 | [#67](https://github.com/sookoonspace/crewpoint/issues/67) | Role screens and invite carrying a role | #66 |
| 1.4 | [#68](https://github.com/sookoonspace/crewpoint/issues/68) | Crews and task crew | #66 |
| 1.4 | [#69](https://github.com/sookoonspace/crewpoint/issues/69) | Co-owners and ownership transfer | #66 |
| 1.4 | [#70](https://github.com/sookoonspace/crewpoint/issues/70) | Vendor scope and role matrix | #67 |
| 1.5 | [#71](https://github.com/sookoonspace/crewpoint/issues/71) | Move budgetEstimate and payment handles | #66 |
| 1.5 | [#72](https://github.com/sookoonspace/crewpoint/issues/72) | Expense access setting | #49, #66 |
| 1.5 | [#73](https://github.com/sookoonspace/crewpoint/issues/73) | No money leaks elsewhere | #72 |
| 1.5 | [#74](https://github.com/sookoonspace/crewpoint/issues/74) | Privacy policy update | None |
| 1.6 | [#75](https://github.com/sookoonspace/crewpoint/issues/75) | Participants, groups and roster | #66 |
| 1.6 | [#76](https://github.com/sookoonspace/crewpoint/issues/76) | Custom fields and categories | #75 |
| 1.6 | [#77](https://github.com/sookoonspace/crewpoint/issues/77) | Roster import | #76 |
| 1.6 | [#78](https://github.com/sookoonspace/crewpoint/issues/78) | Account linking and deletion of participant data | #56, #75 |
| 1.6 | [#79](https://github.com/sookoonspace/crewpoint/issues/79) | Invite link, QR and /join/:code | #67 |
| 1.6 | [#80](https://github.com/sookoonspace/crewpoint/issues/80) | Member picker and screens at scale | #66 |
| 1.7 | [#81](https://github.com/sookoonspace/crewpoint/issues/81) | Sessions and venues | #63, #66 |
| 1.7 | [#82](https://github.com/sookoonspace/crewpoint/issues/82) | Attendance policies and personal agenda | #75, #81 |
| 1.7 | [#83](https://github.com/sookoonspace/crewpoint/issues/83) | Server-calculated counts | #76, #77, #82 |
| 1.7 | [#84](https://github.com/sookoonspace/crewpoint/issues/84) | Count export and freeze | #83 |
| 1.8 | [#85](https://github.com/sookoonspace/crewpoint/issues/85) | Chat paging and mirror fixes | #48 |
| 1.8 | [#86](https://github.com/sookoonspace/crewpoint/issues/86) | Chat summary for the inbox | #66, #85 |
| 1.8 | [#87](https://github.com/sookoonspace/crewpoint/issues/87) | Expense and task mirrors apply only changes | None |
| 1.8 | [#88](https://github.com/sookoonspace/crewpoint/issues/88) | Load fixture, baselines, costs and large pushes | #77, #83, #85, #87 |
| 1.9 | [#89](https://github.com/sookoonspace/crewpoint/issues/89) | System templates and picker | #61, #62, #67, #72, #76, #82 |
| 1.9 | [#90](https://github.com/sookoonspace/crewpoint/issues/90) | Follow-up setup and save as template | #89 |
| 1.10 | [#91](https://github.com/sookoonspace/crewpoint/issues/91) | Restore rehearsal | None |
| 1.10 | [#92](https://github.com/sookoonspace/crewpoint/issues/92) | Crash reporting | None |
| 1.10 | [#93](https://github.com/sookoonspace/crewpoint/issues/93) | Backend alerts and outside billing check | None |
| 1.10 | [#94](https://github.com/sookoonspace/crewpoint/issues/94) | Live sign-in check | #78 |
| Exit | [#95](https://github.com/sookoonspace/crewpoint/issues/95) | Stage 1 exit verification | All other Stage 1 Work Items |

## #46 Stage 1.1: Glossary and naming guardrail

Source: https://github.com/sookoonspace/crewpoint/issues/46 · Parent: #44

### What to build
Add `GLOSSARY.md` with the agreed general vocabulary, and a CI test that fails when event-specific words appear in code or user-facing strings.

### Required context
- `ai_specs/event-platform-plan.md` for the convention, cricket, golf, wedding and party examples.
- `.github/workflows/flutter.yml` for where the guardrail runs.

### Acceptance criteria
- [x] `GLOSSARY.md` has a one-line definition of each of: Event, Organizer, Member, Participant, Group, Category, Session, Crew, Registration, Custom field, Pass, Charge, Payment, Contribution, Goal, Update, Incident, Audience.
- [x] `GLOSSARY.md` includes the convention, cricket, golf, wedding and party examples from the plan.
- [x] CI fails if the words `family`, `meal`, `derod`, `wedding`, `cricket`, `golf` or `tee` appear as whole words in identifiers or user-facing strings in `lib/` or `functions/src/`, outside the template data in Req 62.
- [x] The guardrail ignores comments, Riverpod's `.family`, and `fontFamily`. Any other exception is listed explicitly.
- [x] The architecture, RBAC and data-model sections of `CLAUDE.md` have a note that they are updated as each slice lands.
- [x] Tests for scenario GE-05 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- Requirements: 1-2
- Scenarios: GE-05
- Interview Ledger: L1, L2

### Blocked by
None - ready to start

## #47 Stage 1.1: Backlog and gap triage

Source: https://github.com/sookoonspace/crewpoint/issues/47 · Parent: #44

### What to build
Triage `ai_specs/todo.md` and refresh `docs/guide/GAPS.md` against the current code.

### Required context
- Section "Already built" in `ai_specs/event-platform-plan.md`.

### Acceptance criteria
- [x] Every entry in `ai_specs/todo.md` is triaged.
- [x] `docs/guide/GAPS.md` is refreshed, recording `GAP-ANY-09`, `-25`, `-26`, `-27` and `-35` as built, after checking each against the code.
- [x] If a check shows one of these is not built, that is reported and it is not marked as built.

### Covers
- Requirements: 3

### Blocked by
None - ready to start

## #48 Stage 1.1: Backend tests in CI and general acceptance suite

Source: https://github.com/sookoonspace/crewpoint/issues/48 · Parent: #44

### What to build
Run functions tests under the emulators in CI, rename the convention suite to a general acceptance suite with one fixture per template, and add a gate on finished scenarios.

### Required context
- `.github/workflows/functions.yml` runs only `npm run build` today, and does not trigger on rules or index changes.
- `test_convention/`, `functions/test_convention/`, `functions/jest.convention.config.js`, `test_convention/generate_report.py`, `scripts/check_platform_plan.py`.

### Acceptance criteria
- [x] `npm test` for functions runs under the emulators in CI.
- [x] The job also triggers on `firestore.rules`, `storage.rules` and `firestore.indexes.json`, as well as `functions/**`.
- [x] `test_convention/` and `functions/test_convention/` are renamed to `test_acceptance/`, with `generate_report.py` and `jest.convention.config.js` updated.
- [x] The suite has one fixture per template: the convention fixture and its expected values stay as they are, and party, wedding, cricket and golf fixtures are added.
- [x] CI runs a list of finished scenario IDs from the acceptance suite, and fails if any of them goes red. Unfinished scenarios stay outside this list, so a planned gap does not block work.
- [x] Automated tests use emulators only, and none writes to a real project.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- Requirements: 4, 5, 5a
- Testing Strategy: 2 (Acceptance), 4
- Interview Ledger: L12

### Blocked by
None - ready to start

## #49 Stage 1.2: Server-validated expenses

Source: https://github.com/sookoonspace/crewpoint/issues/49 · Parent: #44

### What to build
Move expense create and edit to a callable that validates money, and make the expense form handle having no connection.

### Required context
- Approved with the Work Item proposal (2026-11-03): permissions that do not exist until #66 are treated as owner or admin until that cutover, then #66 moves the check to the named permission.
- Approved with the Work Item proposal (2026-11-03): migration maps creator to Owner, admins to Admin, and everyone else to Participant. Adding your own expense and creating tasks stay open to every member except Observer and Vendor, because no catalogue permission covers them and Req 34 preserves access.
- Follows Spec section 1.2: keeps working for current members, and a regression test is written first.
- `lib/app/features/budget/data/expense_repository.dart`, `lib/app/features/budget/domain/models/expense.dart`, the expenses block in `firestore.rules`, and the budget robot `test/robots/budget_ledger_robot.dart`.
- Payment expense creation stays open until #50 closes it, so settle-up keeps working between the two items.

### Acceptance criteria
- [x] Expense create and edit go through a callable, listed in `functions/src/index.ts` and `docs/cloud-functions-guide.md`.
- [x] It rejects non-positive or non-finite amounts, amounts over a configured maximum, splits whose total differs from the amount by more than 0.01 per split, and payers or split users who are not members.
- [x] It writes `involvedUids` on every expense it saves.
- [x] Who may act keeps today's rule: a member adds an expense as its payer, and the payer, owner or admin may edit it.
- [x] Rules deny direct client expense create and update, apart from the payment path noted above.
- [x] Existing stored records stay readable, including negative payment splits.
- [x] Without a connection, the expense form keeps what was entered, explains that it needs a connection, and offers retry.
- [x] Forged amounts and splits are rejected in emulator tests.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenario FND-01 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 26
- Requirements: 6, 6a
- Technical Decisions: 4a, 5, 7
- Scenarios: FND-01
- Interview Ledger: L17

### Blocked by
- #48 Stage 1.1: Backend tests in CI and general acceptance suite

## #50 Stage 1.2: Server-written settlements and notices

Source: https://github.com/sookoonspace/crewpoint/issues/50 · Parent: #44

### What to build
Add a `recordSettlement` callable that writes a payment and its chat notice together, and stop clients forging payments or notices.

### Required context
- Follows Spec section 1.2: keeps working for current members, and a regression test is written first.
- `lib/app/features/budget/application/settle_up_controller.dart`, `pending_settlement_notifier.dart`, and the messages block in `firestore.rules`.

### Acceptance criteria
- [x] A new `recordSettlement` callable writes the payment and its chat notice together.
- [x] Clients can no longer create payment expenses directly.
- [x] The notice retry that rules deny today no longer fails.
- [x] Rules reject any client message with a `kind` field.
- [x] `settlement` and `settlement_disputed` are written only by the server.
- [x] Forged notices and forged payments are rejected in emulator tests.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenarios FND-01, FND-02 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 26
- Requirements: 7-8
- Technical Decisions: 7
- Scenarios: FND-01, FND-02

### Blocked by
- #49 Stage 1.2: Server-validated expenses

## #51 Stage 1.2: createEvent callable and no added strangers

Source: https://github.com/sookoonspace/crewpoint/issues/51 · Parent: #44

### What to build
Create events only through a `createEvent` callable, with the caller as Owner, so nobody can be listed as a member without their own action. #89 extends it with template data.

### Required context
- Follows Spec section 1.2: keeps working for current members, and a regression test is written first.
- `lib/app/features/dashboard/data/event_repository.dart`, `create_event_screen.dart`, `functions/src/events/joinEvent.ts`, the events block in `firestore.rules`, and `test/journeys/create_event_journey_test.dart`.
- Until #66, the callable writes today's array shape.

### Acceptance criteria
- [x] Events are created only through the `createEvent` callable, with the caller as Owner.
- [x] Rules deny direct client creation of events.
- [x] Nobody can be listed as a member without their own action through the join flow or a permitted role assignment.
- [x] A failed creation leaves nothing behind.
- [x] Creation needs a connection. Without one, the form keeps what was entered, and explains and offers retry.
- [x] A client attempt to add a stranger as a member is rejected in emulator tests.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenario FND-03 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 26
- Requirements: 9, 63a (base)
- Technical Decisions: 5, 7
- Scenarios: FND-03

### Blocked by
- #48 Stage 1.1: Backend tests in CI and general acceptance suite

## #52 Stage 1.2: Urgent message limits and message size

Source: https://github.com/sookoonspace/crewpoint/issues/52 · Parent: #44

### What to build
Gate urgent messages by permission, rate limit their pushes, and cap message size.

### Required context
- Approved with the Work Item proposal (2026-11-03): permissions that do not exist until #66 are treated as owner or admin until that cutover, then #66 moves the check to the named permission.
- Follows Spec section 1.2: keeps working for current members, and a regression test is written first.
- This means plain members lose urgent sending at this item, which matches the Participant preset in Req 26a.
- `functions/src/events/onUrgentMessageCreated.ts`, `functions/src/notifications/sendPush.ts`, and `lib/app/features/chat/`.

### Acceptance criteria
- [x] Sending an urgent message needs `chat.urgent`, on the server and in the UI.
- [x] Beyond a configurable rate per sender per event (default 5 per hour), the message is still saved but sends no urgent push, and the sender is told.
- [x] Message text is limited to 4,000 characters in rules and UI.
- [x] Backend time comparisons use a clock seam.
- [x] Tests use a mocked `firebase-admin/messaging` transport.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenario FND-04 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 26
- Requirements: 10
- Scenarios: FND-04

### Blocked by
- #48 Stage 1.1: Backend tests in CI and general acceptance suite

## #53 Stage 1.2: Task permissions

Source: https://github.com/sookoonspace/crewpoint/issues/53 · Parent: #44

### What to build
Make task edit permissions match between UI and rules, and keep `markTaskComplete` as the only completion path.

### Required context
- Approved with the Work Item proposal (2026-11-03): permissions that do not exist until #66 are treated as owner or admin until that cutover, then #66 moves the check to the named permission.
- Approved with the Work Item proposal (2026-11-03): migration maps creator to Owner, admins to Admin, and everyone else to Participant. Adding your own expense and creating tasks stay open to every member except Observer and Vendor, because no catalogue permission covers them and Req 34 preserves access.
- Follows Spec section 1.2: keeps working for current members, and a regression test is written first.
- `lib/app/features/tasks/domain/models/task.dart` (`canChangeStatus`), the tasks block in `firestore.rules`, `functions/src/events/markTaskComplete.ts`, and `test/robots/tasks_robot.dart`.

### Acceptance criteria
- [x] `tasks.manage` and a task's creator may edit it. An assignee may change only status and checklist. UI and rules match.
- [x] Clients cannot write `done`, `completedAt` or `completedBy` directly, so `markTaskComplete` stays the only path.
- [x] A second completion does not overwrite the first `completedBy`.
- [x] Any member may still create a task.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenario FND-05 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 26
- Requirements: 11
- Scenarios: FND-05

### Blocked by
- #48 Stage 1.1: Backend tests in CI and general acceptance suite

## #54 Stage 1.2: memberLimit and safe joins

Source: https://github.com/sookoonspace/crewpoint/issues/54 · Parent: #44

### What to build
Replace the fixed 50-member limit with an optional `memberLimit`, enforced by a transaction so simultaneous joins cannot exceed it.

### Required context
- Follows Spec section 1.2: keeps working for current members, and a regression test is written first.
- `functions/src/events/joinEvent.ts` and `lib/app/features/dashboard/presentation/widgets/join_event_sheet.dart`.
- `memberLimit` caps logins. `capacity` is a separate setting, added in #59.

### Acceptance criteria
- [x] `memberLimit` caps how many people can log in to an event. It is optional and off by default, and no value means unlimited.
- [x] The fixed 50-member limit is gone.
- [x] Joining uses a transaction on `memberCount`, so simultaneous joins cannot exceed the limit.
- [x] A test runs 8 joins at one place remaining and must admit exactly 1.
- [x] Existing events have a correct `memberCount`.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenarios FND-06, S-01 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- Requirements: 12, 55
- Scenarios: FND-06, S-01
- Interview Ledger: L7, L18

### Blocked by
- #48 Stage 1.1: Backend tests in CI and general acceptance suite

## #55 Stage 1.2: CSV formula neutralising

Source: https://github.com/sookoonspace/crewpoint/issues/55 · Parent: #44

### What to build
Neutralise formula cells in every CSV export.

### Required context
- Follows Spec section 1.2: keeps working for current members, and a regression test is written first.
- `lib/app/features/budget/data/expense_csv_builder.dart`, `lib/app/features/budget/data/expense_export_pipeline.dart`, `lib/app/features/tasks/data/task_export_pipeline.dart`. Keep the helper free of Flutter and Firebase imports.

### Acceptance criteria
- [x] Cells that begin with `=`, `+`, `-`, `@`, tab or carriage return are neutralised in every export.
- [x] Later CSV exports, including counts and rosters in #84, can use the same helper.
- [x] Unit tests cover each leading character.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenario FND-07 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- Requirements: 13
- Scenarios: FND-07

### Blocked by
- #48 Stage 1.1: Backend tests in CI and general acceptance suite

## #56 Stage 1.2: Complete deletion

Source: https://github.com/sookoonspace/crewpoint/issues/56 · Parent: #44

### What to build
Make account and event deletion remove everything they should, while keeping shared ledgers balanced.

### Required context
- Follows Spec section 1.2: keeps working for current members, and a regression test is written first.
- `functions/src/account/deleteUserAccount.ts` and `functions/src/events/deleteEvent.ts`. #78 adds participant data, and #69 adds owner succession.

### Acceptance criteria
- [x] Account deletion removes `chatReads` and `eventMutes`.
- [x] In shared records, it replaces the user ID in expense splits, `involvedUids`, `createdBy` and `completedBy` with one anonymous ID per person per event.
- [x] A ledger still balances after deletion, and two deleted people are never merged.
- [x] Event deletion also removes checklists, new subcollections, and members' per-event personal documents.
- [x] Emulator tests prove deletion completeness.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenarios FND-08, Z-04 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 28
- Requirements: 14
- Scenarios: FND-08, Z-04

### Blocked by
- #48 Stage 1.1: Backend tests in CI and general acceptance suite

## #57 Stage 1.2: Departed members and dispute window

Source: https://github.com/sookoonspace/crewpoint/issues/57 · Parent: #44

### What to build
Let former members' debts be settled, warn people leaving with a balance, and time-limit disputes with an event setting.

### Required context
- Approved with the Work Item proposal (2026-11-03): permissions that do not exist until #66 are treated as owner or admin until that cutover, then #66 moves the check to the named permission.
- Follows Spec section 1.2: keeps working for current members, and a regression test is written first.
- `functions/src/events/disputeSettlement.ts`, `lib/app/features/budget/domain/models/balance_ledger.dart`, and `lib/app/features/budget/presentation/widgets/settle_sheet.dart`.
- Open Question 2: the 30-day default is a setting, and can change.

### Acceptance criteria
- [x] Debts stay visible, labelled by the existing "(no longer in event)" name.
- [x] Anyone with `money.record` can record a settlement on a departed person's behalf.
- [x] Leaving shows a warning if the person has an outstanding balance. Leaving is not blocked.
- [x] `settings.disputeWindowDays` (default 30) limits disputes, enforced in `disputeSettlement`.
- [x] The dispute option explains when the window has closed.
- [x] Time checks use `Clock` in the app and a clock seam in the backend.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenarios FND-09, FND-10 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 27
- Requirements: 15-16
- Scenarios: FND-09, FND-10

### Blocked by
- #48 Stage 1.1: Backend tests in CI and general acceptance suite

## #58 Stage 1.2: Administration limits

Source: https://github.com/sookoonspace/crewpoint/issues/58 · Parent: #44

### What to build
Limit who can remove whom, require a transfer before an owner leaves, and lock currency once an event has money.

### Required context
- Approved with the Work Item proposal (2026-11-03): permissions that do not exist until #66 are treated as owner or admin until that cutover, then #66 moves the check to the named permission.
- Follows Spec section 1.2: keeps working for current members, and a regression test is written first.
- `functions/src/events/removeEventMember.ts` and `member_management_screen.dart`.
- Co-owners and transfer arrive in #69. Until then, only the owner can remove an admin, and an owner cannot leave.

### Acceptance criteria
- [x] Removing a member needs `members.manage`.
- [x] Only an Owner or Co-owner can remove someone with `members.manage`.
- [x] Owners can only leave after transferring ownership.
- [x] Currency cannot change once an event has any expense or charge, on the server and in the UI.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenario FND-12 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- Requirements: 17
- Scenarios: FND-12

### Blocked by
- #48 Stage 1.1: Backend tests in CI and general acceptance suite

## #59 Stage 1.3: Event configuration and settings screen

Source: https://github.com/sookoonspace/crewpoint/issues/59 · Parent: #44

### What to build
Add the new event fields with defaults so a new event needs only a title, a personal organizer, `templateId` in place of `EventType`, and the event settings screen.

### Required context
- Approved with the Work Item proposal (2026-11-03): permissions that do not exist until #66 are treated as owner or admin until that cutover, then #66 moves the check to the named permission.
- `lib/app/features/dashboard/domain/models/` (`EventType`, `EventStatus`), `lib/app/features/dashboard/domain/event_type_emoji.dart`, `edit_event_screen.dart`, `lib/app/core/router/app_router.dart`, and `lib/app/core/database/app_database.dart` (schema v7).
- Any Drift bump adds a migration step and a `test/database/migration_vN_to_vN+1_test.dart`.
- Open Question 1: Stage 1 only adds the `organizer.verified` flag.
- Since #58, rules deny every client change to `currency`. If event settings let an organizer change it, add a callable that refuses once the event has any expense or charge (Req 17), and disable the control in the UI once that is the case.

### Acceptance criteria
- [x] Events gain `organizerId`, `timeZone`, `venues`, `currency`, `languages`, `status`, `modules`, `labels`, `settings`, `capacity` and `memberLimit`, with defaults so a new event needs only a title.
- [x] A personal organizer is created automatically for each user on first event creation. Legal name and tax ID wait for Stage 2.
- [x] `creatorId` stays as a read-only record of who created the event, and no permission check uses it once #66 lands.
- [x] `capacity` is how many people can attend, with or without an account. It is stored and the count is shown against it. Enforcement and waitlists wait for Stage 2.
- [x] `EventType` is replaced with `templateId`. The current values map to `blank`, keeping their names as display text only.
- [x] Anyone signed in may create events.
- [x] An `organizer.verified` flag exists, which the urgent rate limit reads, with no verification flow yet.
- [x] The `settings` route exists under `/dashboard/event/:eventId` and is visible only to `event.manage`. #60, #62 and #72 add status, modules and expense access to it.
- [x] Key on every interactive widget follows `domain.feature.action`.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [x] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [x] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [x] Tests for scenarios A-01, GE-07 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 6
- Requirements: 18, 18a, 18b, 21, 24, 78a (`settings`)
- Technical Decisions: 6
- Scenarios: A-01, GE-07
- Interview Ledger: L3, L8, L18

### Blocked by
- #51 Stage 1.2: createEvent callable and no added strangers
- #52 Stage 1.2: Urgent message limits and message size

## #60 Stage 1.3: Status lifecycle

Source: https://github.com/sookoonspace/crewpoint/issues/60 · Parent: #44

### What to build
Add the five event statuses with their access rules, automatic changes on a schedule, and the mapping for existing events.

### Required context
- Approved with the Work Item proposal (2026-11-03): permissions that do not exist until #66 are treated as owner or admin until that cutover, then #66 moves the check to the named permission.
- `EventStatus` in `lib/app/features/dashboard/domain/models/`, `firestore.rules`, and `functions/src/events/onTaskDueScheduled.ts` as an example of a scheduled function.
- #65 carries the status mapping into the migration script.

### Acceptance criteria
- [x] Status values are exactly `draft`, `published`, `live`, `ended`, `archived`.
- [x] `draft` is visible only to `event.manage`, and nobody can join.
- [x] `published` is visible to members and open to joining. An organizer moves an event here.
- [x] `live` is set automatically from the start time, in the event's time zone. An organizer can also set it by hand.
- [x] `ended` is set automatically after the end time, or by hand. Settlements, expenses and chat stay open, and everything else is read-only except to `event.manage`.
- [x] `archived` is set by hand and read-only for everyone. `event.manage` can restore it.
- [x] Events without dates stay in their current status until changed by hand.
- [x] The mapping turns `active` into `ended` if the end date has passed, or else `published`, and `archived` stays `archived`.
- [x] Automatic changes run on a schedule with a clock seam.
- [x] Rules enforce read-only states on the server.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [x] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [x] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [x] Tests for scenario GE-08 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 7
- Requirements: 19
- Scenarios: GE-08
- Interview Ledger: L20

### Blocked by
- #59 Stage 1.3: Event configuration and settings screen

## #61 Stage 1.3: Label resolver

Source: https://github.com/sookoonspace/crewpoint/issues/61 · Parent: #44

### What to build
Add a label resolver with one shared defaults file, used across screens, exports and message text.

### Required context
- `lib/app/core/i18n/app_strings.dart`, `functions/src/notifications/templates.ts`, and the export pipelines.

### Acceptance criteria
- [x] A label resolver returns an event's label, or the default for a concept, with singular and plural.
- [x] It is used by screens, exports and message text.
- [x] Changing a label changes it everywhere with no restart.
- [x] Label defaults live in one shared data file, read by both the app and the backend, so the two cannot drift apart.
- [x] Organizers rename concepts from event settings.
- [x] Unit tests cover the resolver.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [x] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [x] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [x] Tests for scenario GE-01 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 4
- Requirements: 20
- Scenarios: GE-01

### Blocked by
- #59 Stage 1.3: Event configuration and settings screen

## #62 Stage 1.3: Modules and event hub

Source: https://github.com/sookoonspace/crewpoint/issues/62 · Parent: #44

### What to build
Let organizers turn modules on and off, and make the event screen a hub of the enabled modules.

### Required context
- Approved with the Work Item proposal (2026-11-03): permissions that do not exist until #66 are treated as owner or admin until that cutover, then #66 moves the check to the named permission.
- `lib/app/features/dashboard/presentation/event_dashboard_screen.dart`, `lib/app/core/constants/` (`Breakpoints`), `global_inbox_provider.dart`, and `global_balance_ledger_provider.dart`.
- Agenda arrives in #82. Until then, the hub shows enabled modules only.

### Acceptance criteria
- [x] Turning a module off hides its screens and entry points, and its server paths reject writes.
- [x] Its data is kept, and comes back when turned on.
- [x] The global Tasks, Chat and Budget tabs leave out that event's data for that module.
- [x] The event screen shows one entry per enabled module plus Agenda, in a list that scrolls at 375 px and a grid from 840 px.
- [x] Settings is visible only to `event.manage`.
- [x] Back returns to the event screen, cancel discards with the confirmation in Req 73, and a person who loses access goes to the event list as in Req 76.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [x] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [x] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [x] Tests for scenario GE-02 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 5
- Requirements: 22, 78b
- Scenarios: GE-02

### Blocked by
- #59 Stage 1.3: Event configuration and settings screen

## #63 Stage 1.3: Event time zones

Source: https://github.com/sookoonspace/crewpoint/issues/63 · Parent: #44

### What to build
Display all dates in the event's time zone, and keep stored times correct across zones and daylight saving.

### Required context
- `lib/app/core/services/device_timezone.dart` (`IDeviceTimezone`) and `pubspec.yaml`.
- `pubspec.yaml` constraints carry the exact resolved version as the caret floor. The `analyzer` and `sqlite3_flutter_libs` holds stay.
- Since #59, `timeZone` is stored on every event and edited on the settings screen as a validated text field, because the zone list arrives with the `timezone` package. Replace it with a picker here. `createEvent` falls back to `UTC` for a zone the server does not know.

### Acceptance criteria
- [x] All dates display in the event's time zone, with the zone shown where a viewer's device differs.
- [x] Session times are stored in UTC along with the event's zone.
- [x] Date-only events stay on the chosen calendar date in every zone.
- [x] Times stay correct across daylight-saving changes.
- [x] The `timezone` package and its web data are added, with the exact resolved version as the caret floor.
- [x] Time logic uses `Clock` and is covered by unit tests, including a daylight-saving change.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenario GE-07 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 6
- Requirements: 23
- Technical Decisions: 10
- Scenarios: GE-07

### Blocked by
- #59 Stage 1.3: Event configuration and settings screen

## #64 Stage 1.4: Minimum app version

Source: https://github.com/sookoonspace/crewpoint/issues/64 · Parent: #44

### What to build
Read a minimum version at startup and show an upgrade message below it, so the app and backend can move together at cutover.

### Required context
- `package_info_plus` is already in `pubspec.yaml`. It goes behind a new seam and provider in `lib/app/core/providers.dart`.
- `lib/app/core/router/app_router.dart`: never rebuild or recreate the router.

### Acceptance criteria
- [x] The app reads a public `config/app` document at startup, using `package_info_plus` behind a new seam.
- [x] Rules allow public read of `config/app`, and no client write.
- [x] Below the minimum, it shows a full-screen upgrade message, with a store link on mobile and a reload on web.
- [x] If the document cannot be read, the app continues normally.
- [x] Widget tests cover below-minimum, at-minimum and read-failure, on mobile and web variants.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- Requirements: 34a

### Blocked by
None - ready to start

## #65 Stage 1.4: Permissions, presets, member documents and migration script

Source: https://github.com/sookoonspace/crewpoint/issues/65 · Parent: #44

### What to build
Add the permission catalogue, role presets, server-calculated member documents and the migration script. Existing reads stay on the arrays until #66.

### Required context
- Approved with the Work Item proposal (2026-11-03): migration maps creator to Owner, admins to Admin, and everyone else to Participant. Adding your own expense and creating tasks stay open to every member except Observer and Vendor, because no catalogue permission covers them and Req 34 preserves access.
- `firestore.rules`, `functions/src/events/` and `docs/cloud-functions-guide.md`.
- Member documents also hold group IDs for own-group checks (Req 26b), filled in by #75 and #78, and `expenses.readAll` per Technical Decision 4a, set from the access setting by #72.
- Automated tests use emulators and a seeded old-shape fixture. Running the script on a real project is a deliberate manual step in #66.
- Since #60, the status mapping is `mapLegacyStatus` in `functions/src/events/eventStatus.ts`. Use it in the migration script. Until then `active` keeps working everywhere it is read. Member documents must keep plain members out of drafts (L23), because list queries cannot filter them out in rules.
- Since #63, older events have no `dateOnly` and may have no `timeZone`. The migration should set `timeZone` from the creator's stored zone when known, and convert `startDate` and `endDate` to midnight UTC on the date they show on that zone, with `dateOnly: true`. Task due dates on older events are midnight on the creator's device, so check they read correctly in the event's zone.

### Acceptance criteria
- [x] `events/{id}/members/{uid}` holds `uid`, `roleIds`, `crewIds`, `permissions`, `participantId` and `joinedAt`.
- [x] The catalogue is exactly: `event.manage`, `event.transfer`, `members.manage`, `roles.manage`, `schedule.edit`, `updates.send`, `participants.read`, `participants.edit`, `participants.readPrivate`, `participants.import`, `group.readOwn`, `group.editOwn`, `registrations.manage`, `money.read`, `money.record`, `money.refund`, `money.dueAtDoor`, `budget.read`, `budget.edit`, `expenses.readAll`, `contributions.manage`, `tasks.manage`, `chat.send`, `chat.urgent`, `messages.send`, `checkin.scan`, `checkin.lookup`, `counts.read`, `incidents.report`, `incidents.receive`, `reports.export`, `competition.manage`, `scores.enter`.
- [x] Owner holds all permissions; Co-owner all except `event.transfer`; Admin all except `event.transfer` and `roles.manage`.
- [x] Finance holds `money.read`, `money.record`, `money.refund`, `budget.read`, `budget.edit`, `expenses.readAll`, `contributions.manage`, `participants.read`, `counts.read`, `reports.export`, `chat.send`.
- [x] Crew lead holds `tasks.manage`, `schedule.edit`, `updates.send`, `participants.read`, `participants.edit`, `money.dueAtDoor`, `counts.read`, `chat.send`, `chat.urgent`, `messages.send`, `incidents.report`, `incidents.receive`.
- [x] Crew member holds `updates.send`, `participants.read`, `money.dueAtDoor`, `counts.read`, `chat.send`, `incidents.report`, `incidents.receive`.
- [x] Volunteer holds `checkin.scan`, `checkin.lookup`, `money.dueAtDoor`, `incidents.report`, `chat.send`. Scorer holds `scores.enter`, `chat.send`. Sponsor and Participant hold `chat.send`.
- [x] Vendor holds none beyond Req 32. Observer holds none: read-only access to the event and published schedule.
- [x] Every preset includes `group.readOwn`, and every member can read the event and its published schedule. `group.editOwn` is granted to a group's contact and to linked adults in that group.
- [x] Organizers may edit presets per event and add custom roles. The data model supports this, and #67 adds the screens.
- [x] A callable recalculates `permissions` on the member document whenever a role or assignment changes. Clients cannot write it.
- [x] An idempotent admin script with a dry-run mode converts each event, preserving everyone's access and old data, including status and `involvedUids`, using the migration mapping above. #71 adds `budgetEstimate`.
- [x] A verification script compares every event's old arrays with its new members.
- [x] Callables that change membership write both the arrays and member documents from this item on, so rollback and verification stay accurate until the arrays are removed.
- [x] `createEvent` writes the owner's member document.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenarios H-01, GE-03, GAP-CRK-29, GAP-CON-30 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- Requirements: 25 (data), 26, 26a, 26b, 27, 34 (script)
- Technical Decisions: 2, 3, 7
- Testing Strategy: 2 (Migration)
- Scenarios: H-01, GE-03, GAP-CRK-29, GAP-CON-30
- Interview Ledger: L9

### Blocked by
- #48 Stage 1.1: Backend tests in CI and general acceptance suite
- #51 Stage 1.2: createEvent callable and no added strangers
- #59 Stage 1.3: Event configuration and settings screen
- #60 Stage 1.3: Status lifecycle

## #66 Stage 1.4: Cutover to permissions

Source: https://github.com/sookoonspace/crewpoint/issues/66 · Parent: #44

### What to build
Move every rule, callable, trigger and UI gate to permissions, switch "my events" to member documents, and roll out on dev and stg in the Spec's order.

### Required context
- Approved with the Work Item proposal (2026-11-03): permissions that do not exist until #66 are treated as owner or admin until that cutover, then #66 moves the check to the named permission.
- Approved with the Work Item proposal (2026-11-03): migration maps creator to Owner, admins to Admin, and everyone else to Participant. Adding your own expense and creating tasks stay open to every member except Observer and Vendor, because no catalogue permission covers them and Req 34 preserves access.
- The arrays appear across app and functions code: `grep -rlE 'memberIds|adminIds' lib functions/src`.
- `lib/app/core/providers.dart`, `firestore.rules`, `functions/src/index.ts`, and `Event.isOwner` / `isAdmin` / `isMember`.
- `crewpoint-dev` holds the owner's real data. Billing is the first thing to check if callables or deploys fail.
- This is the Spec's biggest unknown. Follow-Ups says to review pace after slice 1.4.

### Acceptance criteria
- [ ] "My events" uses a collection-group query on member documents, then reads the event documents.
- [ ] Every Firestore path, callable and trigger uses permissions instead of `creatorId`, `adminIds` or job titles.
- [ ] UI gating reads the same permissions and updates live if a role changes while a screen is open.
- [ ] Rules check one permission with one member-document read.
- [ ] Holding several roles grants the union, and own-group access applies regardless of role.
- [ ] Adding your own expense and creating tasks work for every member except Observer and Vendor.
- [ ] The interim owner-or-admin checks from #52, #53, #57, #58, #59, #60 and #62 now read the named permissions.
- [ ] Membership and ownership use server transactions, and other documents use last-write-wins with server timestamps.
- [ ] If access is lost while on a screen, the app shows a clear message and returns to the event list.
- [ ] Permission-denied responses are shown as understandable messages, and logged, never as raw errors.
- [ ] On dev, then stg, the order is: confirm a fresh backup; run the dry run, then the migration, keeping the old arrays; deploy functions and rules together; release the app and raise the minimum version; run the verification script. The result is recorded.
- [ ] The rollback before array removal is documented and tested: redeploy the previous rules and functions and lower the minimum version.
- [ ] Removing the old arrays is a separate later step, and is added to `ai_specs/todo.md`, with prod.
- [ ] Prod is not touched: it waits for the lawyer approval in Req 39.
- [ ] `CLAUDE.md` RBAC and data-model sections are updated, and `docs/cloud-functions-guide.md` lists changes.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] Tests for scenario H-06 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 13
- Requirements: 25, 28-29, 34 (rollout), 76-77
- Technical Decisions: 2, 3
- Scenarios: H-06
- Interview Ledger: L9, L16

### Blocked by
- #49 Stage 1.2: Server-validated expenses
- #50 Stage 1.2: Server-written settlements and notices
- #51 Stage 1.2: createEvent callable and no added strangers
- #52 Stage 1.2: Urgent message limits and message size
- #53 Stage 1.2: Task permissions
- #54 Stage 1.2: memberLimit and safe joins
- #56 Stage 1.2: Complete deletion
- #57 Stage 1.2: Departed members and dispute window
- #58 Stage 1.2: Administration limits
- #60 Stage 1.3: Status lifecycle
- #62 Stage 1.3: Modules and event hub
- #64 Stage 1.4: Minimum app version
- #65 Stage 1.4: Permissions, presets, member documents and migration script

### Notes
- **H-06 finishes with #72.** This item proves combined roles (the union) and own-group access through `editsOwnGroup`. "Sees no other money" needs expense reads limited to `involvedUids`, which is #72. The H-06 money test is in the acceptance suite as a planned gap, and H-06 joins the finished list when #72 lands.
- **Permissions chosen for checks the catalogue does not name.** Deleting an event uses `event.transfer`, which only the Owner holds. Editing or deleting someone else's expense, and recording a payment for someone who has left, use `money.record`. Removing someone who holds `members.manage`, and promoting or demoting, use `roles.manage`. Event-level notices of a new member go to `members.manage` holders.
- **No "last admin" guard.** The creator is always Owner and cannot be demoted, so an event can never lose everyone who manages it.

## #67 Stage 1.4: Role screens and invite carrying a role

Source: https://github.com/sookoonspace/crewpoint/issues/67 · Parent: #44

### What to build
Add the Roles, Role editor and Member detail screens, custom roles, and a role applied when someone joins through the invite.

### Required context
- `member_management_screen.dart`, `functions/src/events/generateInviteCode.ts`, `functions/src/events/joinEvent.ts`, and PR #40 for existing revocation behaviour.
- The link and QR arrive in #79.

### Acceptance criteria
- [x] Screens exist at the `roles` and `roles/:roleId` routes, plus Member detail, each with loading, empty, error and permission-denied states.
- [x] Owners assign built-in roles, edit presets per event, and create custom roles.
- [x] An event has one active invite, which carries a role applied on join.
- [x] An owner can invite someone directly into a role, with no promotion needed after joining.
- [x] Removing someone with permission revokes write access on all paths, and existing behaviour from PR #40 is retained, including rotating the code.
- [x] Leaving warns when it would leave at most one person holding `members.manage`, naming them, so there is always a backup. It never blocks leaving.
- [x] A robot journey shows role assignment changing access live.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [x] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [x] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [x] Tests for scenarios H-01, H-07, GE-03, GAP-ANY-33, GAP-CRK-29, GAP-CON-30 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 8, 10
- Requirements: 31, 33 (Roles, Role editor, Member detail), 78a (`roles`, `roles/:roleId`)
- Testing Strategy: 2 (Robot journeys)
- Scenarios: H-01, H-07, GE-03, GAP-ANY-33, GAP-CRK-29, GAP-CON-30
- Interview Ledger: L19

### Blocked by
- #66 Stage 1.4: Cutover to permissions

## #68 Stage 1.4: Crews and task crew

Source: https://github.com/sookoonspace/crewpoint/issues/68 · Parent: #44

### What to build
Let organizers create crews and assign members, and let tasks belong to a crew.

### Required context
- `lib/app/features/tasks/domain/models/task.dart`, `lib/app/features/tasks/data/task_repository.dart`, and `test/journeys/tasks_filter_sort_group_journey_test.dart`.
- A new task field needs a Drift bump with a migration test.

### Acceptance criteria
- [x] A Crews screen at the `crews` route has loading, empty, error and permission-denied states.
- [x] Organizers create crews and assign members. `crewIds` is kept on the member document by server code.
- [x] Tasks gain optional `crewId`, shown and filterable when crews are in use.
- [x] Tasks keep owner, due date, status and the overdue filter.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [x] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [x] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [x] Tests for scenario H-02 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 11
- Requirements: 33 (Crews), 72, 78a (`crews`)
- Technical Decisions: 6
- Scenarios: H-02

### Blocked by
- #66 Stage 1.4: Cutover to permissions

## #69 Stage 1.4: Co-owners and ownership transfer

Source: https://github.com/sookoonspace/crewpoint/issues/69 · Parent: #44

### What to build
Add co-owners, confirmed transfer and return of ownership, and automatic succession when an owner deletes their account.

### Required context
- `functions/src/account/deleteUserAccount.ts`. Ownership uses server transactions (Req 76).
- Since #59, `organizerId` follows ownership when an account is deleted (`anonymizeUserInEvent`, using `ensurePersonalOrganizer`). Ownership transfer must move it the same way, and #66 must stop permission checks using `creatorId`.

### Acceptance criteria
- [x] An event has one Owner and any number of Co-owners.
- [x] Ownership can be transferred to anyone in the event, whatever their role, needs confirmation by the new owner, and can be returned the same way. The old owner becomes a Co-owner.
- [x] An event always has an Owner.
- [x] A Transfer ownership screen at the `transfer` route has loading, empty, error and permission-denied states.
- [x] When an owner deletes their account, ownership passes automatically to a Co-owner, or else the longest-standing Admin, or else the longest-standing member. This is the one exception to the confirmation.
- [x] An event with no other members is deleted.
- [x] Owners can leave once they have transferred ownership, per Req 17.
- [x] A robot journey transfers ownership and returns it.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [x] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [x] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [x] Tests for scenarios WE-07, WE-10, GAP-WED-32, GAP-ANY-31 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 9
- Requirements: 14b, 30, 33 (Transfer ownership), 78a (`transfer`)
- Testing Strategy: 2 (Robot journeys)
- Scenarios: WE-07, WE-10, GAP-WED-32, GAP-ANY-31

### Blocked by
- #66 Stage 1.4: Cutover to permissions

## #70 Stage 1.4: Vendor scope and role matrix

Source: https://github.com/sookoonspace/crewpoint/issues/70 · Parent: #44

### What to build
Limit Vendors to their own tasks and payments, and prove every role against every restricted path on the server and in the UI.

### Required context
- Approved with the Work Item proposal (2026-11-03): migration maps creator to Owner, admins to Admin, and everyone else to Participant. Adding your own expense and creating tasks stay open to every member except Observer and Vendor, because no catalogue permission covers them and Req 34 preserves access.
- Open Question 5: a Vendor's view does not cover crew chat unless it is added to their role.
- Decided 2026-11-07: reading chat needs `chat.send`, so Vendors and Observers have no chat unless the Owner adds it to their role. Observers see only the event and its schedule: tasks assigned to them, and expenses they paid or share in, which is normally nothing. Organizers open expenses to them through #72.
- #71, #72 and later items add restricted paths, and extend this matrix as they land.

### Acceptance criteria
- [x] Vendors see only tasks assigned to them, and their own payments or documents.
- [x] A sponsor, vendor or observer sees only what their role allows.
- [x] A role matrix test proves every role against every restricted path, on the server and in the UI, using the Req 26a table.
- [x] Committee-style roles cannot read any money field through the API. The money fields arrive in #71 (`budgetEstimate`, payment handles) and #72 (expense access), which add these rows to this matrix; until then every contributing member reads expenses, as today.
- [x] The matrix shows Observer and Vendor cannot create tasks or expenses, and other roles can.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenarios H-05, WE-08 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 12
- Requirements: 32, 35, 82
- Testing Strategy: 2 (Rules and backend)
- Scenarios: H-05, WE-08

### Blocked by
- #67 Stage 1.4: Role screens and invite carrying a role

## #71 Stage 1.5: Move budgetEstimate and payment handles

Source: https://github.com/sookoonspace/crewpoint/issues/71 · Parent: #44

### What to build
Move `budgetEstimate` to a permission-gated document, and limit payment handles to people who share an event, without breaking names.

### Required context
- Firestore rules cannot hide single fields (Technical Decision 4).
- `lib/app/features/profile/data/firestore_user_repository.dart`, `lib/app/core/providers.dart` (`usersByIdProvider`), `lib/app/features/budget/presentation/widgets/settle_sheet.dart`, and the users block in `firestore.rules`.

### Acceptance criteria
- [x] `budgetEstimate` moves off tasks to a document that needs `budget.read`.
- [x] Existing values are migrated by the script from #65, which stays idempotent.
- [x] Tasks show it only to those with permission.
- [x] Payment handles move out of the public profile, and are visible only to people who share an event with that person, through a callable or a per-event projection.
- [x] Removing the broad read on `users/{uid}` does not break names in chat, tasks and budget.
- [x] Pay links still work for people who share an event.
- [x] The role matrix covers the new paths.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenario H-05 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- Requirements: 36-37
- Technical Decisions: 4
- Scenarios: H-05

### Blocked by
- #66 Stage 1.4: Cutover to permissions

## #72 Stage 1.5: Expense access setting

Source: https://github.com/sookoonspace/crewpoint/issues/72 · Parent: #44

### What to build
Let `event.manage` holders choose who can read expenses, enforced on the server, with limited members still seeing their own balance.

### Required context
- Rules deny a list query unless every possible result is allowed, so queries must follow access (Req 38e).
- `lib/app/features/budget/data/expense_repository.dart`, `lib/app/features/budget/domain/models/balance_ledger.dart`, and `lib/app/features/budget/application/global_balance_ledger_provider.dart`.
- Mirrored streams keep the `kIsWeb` fork, with teardown through `ref.onDispose`.
- Template defaults (Req 38a) arrive in #89.
- Decided 2026-11-08: **Everyone in the event** leaves out Observers and Vendors, unless the admin turns on a switch, **Also show Observers and Vendors**, which is off by default. The Observer and Vendor roles can also be picked under **Selected roles and people**. An organizer shares final financials with everyone this way when they choose. #70's rules already open expenses to `expenses.readAll`.

### Acceptance criteria
- [x] Anyone with `event.manage` chooses in Event settings: **Everyone in the event** (all members read all expenses), **Only people involved** (members read only expenses they paid for or are part of), or **Selected roles and people** (the admin picks any roles and individual members, who can read all expenses).
- [x] In every option, the payer and people in a split can read that expense, and holders of `money.read` can read all expenses.
- [x] The setting is enforced on the server, takes effect immediately for open screens, and each change is recorded with who made it and when.
- [x] Only reading is affected. This does not grant adding, editing or deleting.
- [x] The access setting is copied onto member documents as `expenses.readAll` by the callable that recalculates `permissions`, including when a role or the setting changes.
- [x] Someone with limited access still sees their own balance and who to pay, without seeing other people's expenses. A callable returns that person's balance, calculated from all of the event's expenses on the server.
- [x] Totals and exports show only what that person may read.
- [x] A member with `expenses.readAll` reads the whole collection. Anyone else reads with `involvedUids array-contains uid`. Both the mirror and the web stream choose the query by access, and reset when access changes.
- [x] The migration backfills `involvedUids`, and existing events work on the new queries.
- [x] The setting screen has loading, error and saved states. The selected list shows roles and people by name, and warns before narrowing access, naming how many people will lose it. Choosing nobody is allowed, since permission holders keep access.
- [x] Emulator tests cover every access option against every role, plus balances for limited members.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [x] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [x] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [x] Tests for scenario H-05 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- Requirements: 38, 38b, 38c, 38d, 38e
- Technical Decisions: 4a
- Testing Strategy: 2 (Rules and backend, Widget)
- Scenarios: H-05
- Interview Ledger: L15

### Blocked by
- #49 Stage 1.2: Server-validated expenses
- #66 Stage 1.4: Cutover to permissions

## #73 Stage 1.5: No money leaks elsewhere

Source: https://github.com/sookoonspace/crewpoint/issues/73 · Parent: #44

### What to build
Make every other path that carries money follow expense access.

### Required context
- `functions/src/events/onExpenseCreated.ts`, `functions/src/events/onSettlementDisputed.ts`, `functions/src/notifications/templates.ts`, the settlement notice from #50, `lib/app/features/budget/data/expense_export_pipeline.dart`, and `lib/app/features/budget/data/expense_pdf_builder.dart`.

### Acceptance criteria
- [x] Expense pushes go only to people who may read that expense, and leave out the amount otherwise.
- [x] Settlement notices in chat leave out the amount unless the access option is Everyone.
- [x] The global Budget tab, reports and exports all follow the same access.
- [x] A test covers each of these paths.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] Tests for scenario H-05 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- Requirements: 38f
- Scenarios: H-05
- Interview Ledger: L15

### Blocked by
- #72 Stage 1.5: Expense access setting

## #74 Stage 1.5: Privacy policy update

Source: https://github.com/sookoonspace/crewpoint/issues/74 · Parent: #44

### What to build
Update the privacy policy for children and for Canada, regenerate the hosted pages, and record the lawyer approval TODO.

### Required context
- `assets/legal/privacy-policy.md` and `scripts/build_legal_html.dart`.
- The policy says CrewPoint is for ages 13 and up, while events register young children.
- Open Question 3: the owner arranges the lawyer before prod. This does not block development.

### Acceptance criteria
- [x] `assets/legal/privacy-policy.md` is updated for children and for Canada.
- [x] Hosted pages are regenerated.
- [x] `ai_specs/todo.md` has this TODO: a lawyer must approve this policy before the platform work in this spec moves to prod, including the migration in Req 34.
- [x] Development and testing on dev and stg carry on without waiting, and the operations work in 1.10 is not affected.
- [x] Tests for scenarios Z-01, Z-04 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.

### Covers
- Requirements: 39
- Scenarios: Z-01, Z-04
- Interview Ledger: L10, L16

### Blocked by
None - ready to start

## #75 Stage 1.6: Participants, groups and roster

Source: https://github.com/sookoonspace/crewpoint/issues/75 · Parent: #44

### What to build
Add participants who may have no account, including children, groups, and a paged roster that stays usable at 5,000 people.

### Required context
- New feature folder follows `data/domain/application/presentation`. Providers are hand-written in `lib/app/core/providers.dart`, with no `@riverpod`.
- Rosters stay online and paged, and are never fully mirrored (Req 74). `test/harness/dashboard_harness.dart` and `test/robots/` show the journey pattern, with bounded pumps.
- Since #59, the settings screen shows `capacity` against `memberIds.length`, the only count that exists so far. Once participants exist, count them instead, because capacity includes people without accounts (Req 18b).

### Acceptance criteria
- [x] `participants`, `groups` and per-participant `private` documents exist, with rules.
- [x] Participants may have no account.
- [x] Children are created only by someone with `participants.edit` or by a linked adult in their group.
- [x] Participants can be put into groups, so a family, team or foursome is handled together. The word used comes from the label resolver.
- [x] Roster screens page, search and filter by group, category and field, and stay usable at 5,000 people. #76 adds category and field filters.
- [x] Non-permitted members cannot browse the roster.
- [x] The `people` and `people/:participantId` routes exist.
- [x] Roster screens explain they need a connection.
- [x] Member documents carry the person's group IDs, and own-group checks use those IDs.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [x] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [x] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [x] Tests for scenarios PA-05, Z-01 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 14-15
- Requirements: 40, 43, 78a (`people`, `people/:participantId`)
- Scenarios: PA-05, Z-01
- Interview Ledger: L7

### Blocked by
- #66 Stage 1.4: Cutover to permissions

## #76 Stage 1.6: Custom fields and categories

Source: https://github.com/sookoonspace/crewpoint/issues/76 · Parent: #44

### What to build
Let organizers add custom fields with visibility levels, and define categories per event, including rule-based ones.

### Required context
- Private fields use the `private` documents from #75.
- Keep category and age logic in pure, unit-tested code.

### Acceptance criteria
- [x] Custom fields support at least text, number, date, single choice, multiple choice and yes/no, plus required, per-participant or per-group, and a visibility level.
- [x] Private fields are stored in `private`.
- [x] Reports show age bands rather than birth dates unless a viewer has `participants.readPrivate`.
- [x] Categories are defined per event, and can be derived by a rule such as age on a date.
- [x] Convention boundary: age 17 on event start is a child and age 18 an adult.
- [x] The `fields` route exists, and the roster filters by category and field.
- [x] Unit tests cover category and age rules, and emulator tests cover field visibility.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [x] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [x] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [x] Tests for scenarios GE-04, GAP-WED-14, Z-01 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 16
- Requirements: 41-42, 78a (`fields`)
- Testing Strategy: 2 (Unit)
- Scenarios: GE-04, GAP-WED-14, Z-01

### Blocked by
- #75 Stage 1.6: Participants, groups and roster

## #77 Stage 1.6: Roster import

Source: https://github.com/sookoonspace/crewpoint/issues/77 · Parent: #44

### What to build
Add CSV import with column mapping, a dry-run report and safe re-import, run by a server job that can be left and reopened.

### Required context
- `csv` is already in `pubspec.yaml`. File picking goes through a new seam and provider.
- `storage.rules`, and `functions/src/index.ts` for registering new functions.
- Import stays source-agnostic, since it must serve both a bought tool and native registration in Stage 2 (L6).

### Acceptance criteria
- [x] CSV upload offers column mapping, a dry-run validation report, and row-level errors that do not stop good rows.
- [x] Re-import matches on a mapped external ID, or else on normalised group plus name, and never duplicates.
- [x] Manual edits to unmapped fields are kept.
- [x] The file uploads to a new `events/{id}/imports/` Storage path, readable and writable only with `participants.import`.
- [x] A function parses and validates it, and tracks progress in an `imports/{id}` job document, so the job can be left and reopened.
- [x] The uploaded file is deleted when the job finishes, and after 7 days at the latest.
- [x] File picking goes through a new seam.
- [x] Rows missing from a re-import are listed for review. Confirming marks those groups as cancelled and removes them from counts, keeping the record.
- [x] Long imports show progress, can be left running on the server, and report results when reopened.
- [x] Import needs a connection, and explains this rather than failing silently.
- [x] The `people/import` route exists.
- [x] A robot journey covers import with errors and re-import. Unit tests cover mapping and re-import matching.
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [x] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [x] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [x] Tests for scenarios X-01, X-02, X-03, X-06, S-02 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 17
- Requirements: 44, 44a, 45, 75, 78a (`people/import`)
- Testing Strategy: 2 (Unit, Robot journeys)
- Scenarios: X-01, X-02, X-03, X-06, S-02
- Interview Ledger: L6

### Blocked by
- #76 Stage 1.6: Custom fields and categories

## #78 Stage 1.6: Account linking and deletion of participant data

Source: https://github.com/sookoonspace/crewpoint/issues/78 · Parent: #44

### What to build
Link a signed-in person to their own participant record safely, and extend account deletion to the new participant data.

### Required context
- `docs/account-linking-behavior.md` and `IAuthService`. `functions/src/account/deleteUserAccount.ts`, as extended by #56.
- Verification is not enforced today. Phone matching and personal links wait for Stage 2.

### Acceptance criteria
- [x] Linking happens when a signed-in user's **verified** email matches a participant, with `emailVerified` required.
- [x] Linking never happens on name alone.
- [x] Only adult records count: exactly one adult with that email links automatically, while two or more adults, or only children, is ambiguous and goes to an organizer. Children are never linked to an account. (Decided here.)
- [x] Linking creates a member with the Participant role, unless they already are one, and grants access only to that person's own group.
- [x] A participant sees their own schedule and never another person's. (Rules and screens limit them to their own record and group; schedules arrive with sessions in #81.)
- [x] Deleting an account removes that person's member documents and their own `private` documents.
- [x] Their participant record is unlinked and anonymised: an unnamed entry keeping only age band, status, group and choice answers. In an event that has not ended it also keeps a server-only scrambled match key of the email and import ID, so a new account with the same verified email links back and a re-import refills it without a duplicate. A past event keeps anonymous counts only. (Decided here.)
- [x] Children entered by that person in a group they are a linked adult of are deleted with them, unless another linked adult remains in the group. Imported records and children entered for other groups stay. (Decided here.)
- [x] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [x] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [x] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [x] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [x] Tests for scenarios X-05, L-01, L-02, Z-04 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [x] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 18, 28
- Requirements: 14a, 46
- Scenarios: X-05, L-01, L-02, Z-04

### Blocked by
- #56 Stage 1.2: Complete deletion
- #75 Stage 1.6: Participants, groups and roster

## #79 Stage 1.6: Invite link, QR and /join/:code

Source: https://github.com/sookoonspace/crewpoint/issues/79 · Parent: #44

### What to build
Add one shareable, role-carrying link and QR code per event, with an organizer-set expiry, and a web join flow.

### Required context
- `functions/src/events/generateInviteCode.ts`, `lib/app/core/router/app_router.dart` (router is built once and uses `refreshListenable`), and `ai_specs/invite-share-spec.md`.
- QR rendering gets a new interface and provider. New dependencies use the exact resolved version as the caret floor.
- Stage 1 has one active invite per event, so a convention cannot send individual invites until Stage 2. Per-group, single-use and personal links, and opening links directly in the app, wait for Stage 2.
- Since #60, new events start as `draft` (L23), and `generateInviteCode` and `joinEvent` refuse unless the event is published or live. The invite link and `/join/:code` must do the same, and explain it to the person joining.

### Acceptance criteria
- [ ] There is one shareable link and QR code per event, carrying a role, with an expiry the organizer sets.
- [ ] Rotating replaces the old link.
- [ ] On web, `/join/:code` opens the join flow, and signed-out users return there after signing in.
- [ ] On a phone, a scanned QR opens this web flow.
- [ ] The default expiry stays 24 hours on Blank and Party, and lasts until the event starts on other templates.
- [ ] An expiry can last a whole registration period.
- [ ] Joining explains that it needs a connection when offline.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [ ] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [ ] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [ ] Tests for scenario GAP-CON-01 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 19
- Requirements: 47, 56, 78a (`/join/:code`)
- Technical Decisions: 10
- Scenarios: GAP-CON-01
- Interview Ledger: L19

### Blocked by
- #67 Stage 1.4: Role screens and invite carrying a role

## #80 Stage 1.6: Member picker and screens at scale

Source: https://github.com/sookoonspace/crewpoint/issues/80 · Parent: #44

### What to build
Replace screens built on the old member arrays with paged pickers and on-screen name loading.

### Required context
- `usersByIdProvider` in `lib/app/core/providers.dart`, task assignment under `lib/app/features/tasks/presentation/`, and expense splitting under `lib/app/features/budget/presentation/`.

### Acceptance criteria
- [ ] Task assignment and expense splitting use a searchable, paged member picker.
- [ ] Event tiles use `memberCount`.
- [ ] Names load only for people on screen, replacing `usersByIdProvider`'s whole-list load.
- [ ] Equal splits need choosing who is included once an event passes 50 members, instead of defaulting to everyone.
- [ ] Tasks, chat and shared expenses stay smooth at large sizes.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [ ] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [ ] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 25
- Requirements: 43a

### Blocked by
- #66 Stage 1.4: Cutover to permissions

## #81 Stage 1.7: Sessions and venues

Source: https://github.com/sookoonspace/crewpoint/issues/81 · Parent: #44

### What to build
Let organizers build a multi-day schedule of sessions across venues, and edit times as plans change.

### Required context
- `lib/app/core/database/app_database.dart`: new mirrored tables need a Drift bump, a migration test, the `kIsWeb` fork, and teardown via `ref.onDispose`.
- Times follow #63.
- Since #59, `venues` holds `{id, name, address}` on the event, edited on the settings screen. Add map link, directions and "to be announced" here. A-01 is finished with this item, once venues are complete, so add it to the finished list then.

### Acceptance criteria
- [ ] `sessions` hold title, start, end, venue, type (free text with suggestions), tags, capacity and eligibility.
- [ ] Schedules span several days, with day and venue grouping.
- [ ] Placeholder times can be flagged as "to be confirmed".
- [ ] Venues hold address, map link and directions, and locations may be "to be announced".
- [ ] Editing needs `schedule.edit`, and every member can read the published schedule.
- [ ] The `schedule` and `schedule/:sessionId` routes exist.
- [ ] Module-off and status rules apply to the new paths.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [ ] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [ ] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [ ] Tests for scenarios A-01, A-02, A-05, GAP-WED-12 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 20
- Requirements: 48-49, 78a (`schedule`, `schedule/:sessionId`)
- Technical Decisions: 5, 6
- Scenarios: A-01, A-02, A-05, GAP-WED-12

### Blocked by
- #63 Stage 1.3: Event time zones
- #66 Stage 1.4: Cutover to permissions

## #82 Stage 1.7: Attendance policies and personal agenda

Source: https://github.com/sookoonspace/crewpoint/issues/82 · Parent: #44

### What to build
Work out attendance from an event policy plus stored exceptions, and give each person an agenda and now-and-next view from their own record.

### Required context
- Keep attendance logic pure, so #83 can use it on the server. If it must run in both Dart and TypeScript, one shared fixture proves both agree.
- `Clock` for time logic.
- Offline check-in look-ups wait for Stage 5.

### Acceptance criteria
- [ ] Participants have optional arrival and departure times.
- [ ] Attendance uses an event policy: `arrivalToDeparture` (default for Convention, sessions within a person's arrival and departure), `invitedOnly` (default for Wedding, sessions a person or their group was invited to), `everyone` (default for Party, all sessions), or `bySession` (each person chooses sessions, and nothing is assumed).
- [ ] Only exceptions are stored, as per-person opt-outs and invitations, and attendance is otherwise worked out from the policy.
- [ ] Personal agenda and now-and-next screens use the viewer's own record.
- [ ] A fixture proves that someone arriving later sees nothing earlier, opted-out sessions are hidden, and sessions are limited to those invited.
- [ ] A person's own group, agenda and sessions, and their tasks and chat, read from the local mirror on mobile, and show when they were last updated.
- [ ] The `agenda` route exists, and the hub shows Agenda.
- [ ] A robot journey builds a schedule and views the agenda.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [ ] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [ ] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [ ] Tests for scenarios J-05, J-06 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 21-22
- Requirements: 50-51, 74, 78a (`agenda`)
- Technical Decisions: 6
- Testing Strategy: 2 (Unit, Robot journeys)
- Scenarios: J-05, J-06

### Blocked by
- #75 Stage 1.6: Participants, groups and roster
- #81 Stage 1.7: Sessions and venues

## #83 Stage 1.7: Server-calculated counts

Source: https://github.com/sookoonspace/crewpoint/issues/83 · Parent: #44

### What to build
Calculate counts per session and per event in a function, stored in a `stats` document, so devices never need the whole roster.

### Required context
- `test_acceptance/fixtures/` (renamed by #48), and section 4 of `docs/testing/CREWPOINT_CONVENTION_TEST_v3.md` for the per-meal table.
- The before-merge, walk-in and post-event rows of section 4 belong to Stages 2 and 5.

### Acceptance criteria
- [ ] Counts per session and per event, by category and by any custom field, are calculated by a function and stored in a `stats` document with a last-updated time.
- [ ] Counts are recalculated after changes, using the attendance policy plus stored exceptions.
- [ ] The screen, at the `counts` route, shows when counts were last updated and needs `counts.read`.
- [ ] With F1–F7 loaded and F8 cancelled through re-import, and with F10 absent because merging is Stage 2, the fixture produces: 7 groups, 16 adults, 10 children, 26 people; 18, 2 and 6 by diet; 7 kids activity sign-ups; and the full section 4 per-meal table for M1–M8.
- [ ] `capacity` shows the count against it, using these counts.
- [ ] Unit tests cover count logic.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [ ] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [ ] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [ ] Tests for scenarios B-04, B-05, GE-04 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 23
- Requirements: 52, 52a, 78a (`counts`)
- Technical Decisions: 8
- Scenarios: B-04, B-05, GE-04

### Blocked by
- #76 Stage 1.6: Custom fields and categories
- #77 Stage 1.6: Roster import
- #82 Stage 1.7: Attendance policies and personal agenda

## #84 Stage 1.7: Count export and freeze

Source: https://github.com/sookoonspace/crewpoint/issues/84 · Parent: #44

### What to build
Export counts and rosters, and let an authorised user lock counts on a date so suppliers get a stable number.

### Required context
- `IFileExporter`, `lib/app/core/services/file_export_service.dart`, `test/harness/recording_file_exporter.dart`, and the CSV helper from #55.

### Acceptance criteria
- [ ] Counts and rosters export to CSV, with permissions enforced and any private fields excluded by default.
- [ ] Formula cells are neutralised.
- [ ] An authorised user locks counts on a date.
- [ ] Later changes appear as a list of differences, and the frozen numbers remain available.
- [ ] A robot journey covers counts and export.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [ ] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [ ] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [ ] Tests for scenarios B-10, B-14 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 23-24
- Requirements: 53-54
- Testing Strategy: 2 (Robot journeys)
- Scenarios: B-10, B-14

### Blocked by
- #83 Stage 1.7: Server-calculated counts

## #85 Stage 1.8: Chat paging and mirror fixes

Source: https://github.com/sookoonspace/crewpoint/issues/85 · Parent: #44

### What to build
Page chat history, apply only changed documents in the mirror, and fix settlement and deleted-message handling on mobile.

### Required context
- `lib/app/features/chat/data/chat_repository.dart` and `lib/app/core/database/app_database.dart`.
- `ChatMessage` already has `kind`, but Drift does not store it.
- The Drift bump needs a migration step and a migration test.

### Acceptance criteria
- [ ] Chat loads the most recent 50 messages, with older pages on demand.
- [ ] Mirrors apply only changed documents through `docChanges`, and all older messages remain reachable when online.
- [ ] Offline, the most recent cached messages are shown, with a note that older ones need a connection.
- [ ] One new message with 5,000 in history settles in under 2 seconds in the same Mac test that measures about 53 seconds today.
- [ ] A `kind` column is added to Drift chat messages and carried through, so settlement and dispute bubbles work on mobile.
- [ ] Deleted messages disappear from the mirror.
- [ ] The `kIsWeb` fork stays in place.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] Tests for scenarios S-07, FND-11 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 25
- Requirements: 57-58
- Technical Decisions: 6
- Scenarios: S-07, FND-11

### Blocked by
- #48 Stage 1.1: Backend tests in CI and general acceptance suite

## #86 Stage 1.8: Chat summary for the inbox

Source: https://github.com/sookoonspace/crewpoint/issues/86 · Parent: #44

### What to build
Keep a server-maintained chat summary per event, and use it for inbox previews and unread badges.

### Required context
- `lib/app/features/chat/application/global_inbox_provider.dart`, `lib/app/features/dashboard/application/unread_badge_provider.dart`, `chat_inbox_screen.dart`, and `test/robots/chat_inbox_robot.dart`.

### Acceptance criteria
- [ ] Each event keeps a server-maintained chat summary with the latest message and a message count.
- [ ] The global inbox uses this, plus `chatReads`, for previews and unread badges, instead of loading every event's messages.
- [ ] Urgent-unread status comes from the same summary.
- [ ] Previews never show an amount the viewer may not read. If #73 has not landed yet, it covers this path when it does.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- Requirements: 57a

### Blocked by
- #66 Stage 1.4: Cutover to permissions
- #85 Stage 1.8: Chat paging and mirror fixes

## #87 Stage 1.8: Expense and task mirrors apply only changes

Source: https://github.com/sookoonspace/crewpoint/issues/87 · Parent: #44

### What to build
Stop expense and task mirrors rewriting rows in a way that triggers a UI update per row.

### Required context
- `lib/app/features/budget/data/expense_repository.dart`, `lib/app/features/tasks/data/task_repository.dart`, and the DAOs in `lib/app/core/database/daos/`.
- Coordinate with #72 if it is in progress, since it also changes the expense query.

### Acceptance criteria
- [ ] Expense and task mirrors apply only changes.
- [ ] They do not write once per row in a way that triggers a UI update per row.
- [ ] A test proves that one changed document causes one bounded UI update.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 25
- Requirements: 59

### Blocked by
None - ready to start

## #88 Stage 1.8: Load fixture, baselines, costs and large pushes

Source: https://github.com/sookoonspace/crewpoint/issues/88 · Parent: #44

### What to build
Generate deterministic load fixtures, record baselines and costs per tier, and make large push sends read recipients in batches.

### Required context
- `functions/src/notifications/sendPush.ts` and `functions/src/utils/batch.ts`.
- Local timings are baselines rather than production promises.
- Open Question 6: revisit the baselines after measurement.

### Acceptance criteria
- [ ] A deterministic load fixture generates 108 groups and 400 people, and a 2,000-person tier.
- [ ] Baselines are recorded: import of 400 under 2 minutes, a roster page under 1 second, counts under 2 seconds at 2,000.
- [ ] A measured cost estimate per tier covers reads, writes and function runs.
- [ ] Large push sends read recipients in batches, not one read per person, and fit the function's time limit at 2,000 recipients, measured with a mocked transport.
- [ ] If this cannot hold at 5,000, the limit is recorded for Stage 3's message queue.
- [ ] Timings are recorded in the report, on emulators only.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] Tests for scenarios S-02, S-08, GE-09 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- Requirements: 60, 61, 61a, 83
- Testing Strategy: 5
- Scenarios: S-02, S-08, GE-09
- Interview Ledger: L7, L11

### Blocked by
- #77 Stage 1.6: Roster import
- #83 Stage 1.7: Server-calculated counts
- #85 Stage 1.8: Chat paging and mirror fixes
- #87 Stage 1.8: Expense and task mirrors apply only changes

## #89 Stage 1.9: System templates and picker

Source: https://github.com/sookoonspace/crewpoint/issues/89 · Parent: #44

### What to build
Add the six system templates as data, make the first step of creation a picker, and give small events a fast path.

### Required context
- `createEvent` from #51, `lib/app/features/dashboard/presentation/create_event_screen.dart`, `test/robots/create_event_robot.dart`, and `pubspec.yaml` for the assets folder.
- Template files are the guardrail's only exception for event-specific words (Req 2).
- Since #59, `createEvent` always writes `templateId: 'blank'` and ignores any client value. Accept a validated template ID here. `eventType` is display text on older events only, and rules deny changing it or `templateId`.
- Since #60, new events start as `draft` (L23), including events from templates. Creation still has no further screens (Req 63), and the organizer is then offered "Publish and invite". PA-01's under-a-minute test covers creating the event.

### Acceptance criteria
- [ ] System templates are data only, in versioned JSON files under `assets/templates/`, also read by functions, so they need no separate seeding per environment: Blank, Party, Wedding, Cricket tournament, Golf outing, Convention.
- [ ] Each sets modules, labels, roles, fields, categories, attendance policy and settings.
- [ ] Events keep a copy of what they were created with, so a later template version never changes an existing event.
- [ ] The first step of creation is a picker, at `/dashboard/create`.
- [ ] Choosing Party or Blank with only a title and date creates the event in under a minute on a phone, with no further screens.
- [ ] `createEvent` creates the event, owner member, roles and template data together, so a failed creation leaves nothing behind.
- [ ] Expense access defaults are **Everyone** for Party, Wedding and Blank, **Selected roles and people** with nobody selected for Convention, so that only people holding `money.read` have full access, and **Only people involved** for Cricket tournament and Golf outing. The admin can change this at any time.
- [ ] Organizers can change anything after starting from a template.
- [ ] Fixtures prove each template creates correctly with no code differences.
- [ ] Robot journeys cover create from each template and the party fast path. Unit tests cover template validation.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [ ] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [ ] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [ ] Tests for scenarios GE-06, PA-01 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 1-2
- Requirements: 38a, 62, 63, 63a, 66, 78a (`/dashboard/create`)
- Technical Decisions: 1
- Testing Strategy: 2 (Unit, Robot journeys)
- Scenarios: GE-06, PA-01
- Interview Ledger: L1, L2, L3, L15

### Blocked by
- #61 Stage 1.3: Label resolver
- #62 Stage 1.3: Modules and event hub
- #67 Stage 1.4: Role screens and invite carrying a role
- #72 Stage 1.5: Expense access setting
- #76 Stage 1.6: Custom fields and categories
- #82 Stage 1.7: Attendance policies and personal agenda

## #90 Stage 1.9: Follow-up setup and save as template

Source: https://github.com/sookoonspace/crewpoint/issues/90 · Parent: #44

### What to build
Offer skippable follow-up setup on larger templates, and let users save a configured event as their own template.

### Required context
- Templates from #89, and event settings from #59.

### Acceptance criteria
- [ ] Other templates offer optional follow-up setup that can be skipped and completed later from Event settings.
- [ ] Save-as-template copies configuration only, and never people, money or messages.
- [ ] Saved templates belong to the user who created them.
- [ ] A test proves that no people, money or messages are copied.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] New or changed screens have loading, empty, error and offline states, with retry where an action failed. Forms keep entered data on failure, and leaving a form with unsaved changes asks for confirmation.
- [ ] New or changed screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode.
- [ ] Strings go through `context.strings` and the label resolver once it exists. Interactive widgets have `domain.feature.action` keys, and journeys use bounded pumps.
- [ ] Tests for scenario GE-06 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 3
- Requirements: 64-65
- Scenarios: GE-06

### Blocked by
- #89 Stage 1.9: System templates and picker

## #91 Stage 1.10: Restore rehearsal

Source: https://github.com/sookoonspace/crewpoint/issues/91 · Parent: #44

### What to build
Rehearse a Firestore restore into a new database on dev, and document the result. Manual.

### Required context
- `docs/ops/backups-and-alerts.md` has the commands and the "Still to do" list.
- `crewpoint-dev` holds real data, so restore only into a new database.

### Acceptance criteria
- [ ] A backup is restored into a new database on dev, with live data untouched.
- [ ] Events and expenses are checked in the restored database, then it is deleted.
- [ ] The result is documented in `docs/ops/backups-and-alerts.md`, and its list is updated.
- [ ] Manual results for scenario O-03 are recorded. A scenario shared with another Work Item is finished when all of its parts are.

### Covers
- User Stories: 29
- Requirements: 67
- Testing Strategy: 6
- Scenarios: O-03

### Blocked by
None - ready to start

## #92 Stage 1.10: Crash reporting

Source: https://github.com/sookoonspace/crewpoint/issues/92 · Parent: #44

### What to build
Add crash reporting on iOS, Android and web behind a seam, with no personal data in reports.

### Required context
- Open Question 4: default is Sentry, since it covers web as well as mobile and Crashlytics does not. This item confirms the choice.
- `pubspec.yaml`: exact resolved version as the caret floor, and the existing holds stay.
- New platform calls go behind an interface and provider. `docs/ops/backups-and-alerts.md` tracks status.

### Acceptance criteria
- [ ] Crash reporting works on iOS, Android and web.
- [ ] Reports contain no personal data, with a test on the scrubbing.
- [ ] Tests never reach a real reporter, using the seam.
- [ ] One real test crash from dev is confirmed as received.
- [ ] The status table in `docs/ops/backups-and-alerts.md` is updated.
- [ ] Domain logic, rules, callables and migrations in this item are written test first, one behaviour at a time.
- [ ] Tests for scenario O-02 are passing in the acceptance suite, and finished IDs are added to the CI list from Req 5a. A scenario shared with another Work Item is finished when all of its parts are.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass, as relevant to the change, using emulators and seams only.

### Covers
- User Stories: 29
- Requirements: 68
- Technical Decisions: 10
- Scenarios: O-02

### Blocked by
None - ready to start

## #93 Stage 1.10: Backend alerts and outside billing check

Source: https://github.com/sookoonspace/crewpoint/issues/93 · Parent: #44

### What to build
Add backend error alerts for dev and prod, and a scheduled billing check that runs outside Google Cloud.

### Required context
- `docs/ops/backups-and-alerts.md`, `docs/gcp_budget_settings.md`, and the Nov 2 billing lapse, which took down every function with nobody told.
- Applies to prod directly: Req 39 says the operations work is not affected by the lawyer approval.

### Acceptance criteria
- [ ] Backend error alerts exist for dev and prod, ignoring non-callable browser requests such as `GET` on callable URLs, and emailing derodian@gmail.com and admin@sookoon.space.
- [ ] A scheduled billing check runs outside Google Cloud, with a read-only service account, and alerts on failure.
- [ ] One alert is confirmed as actually reaching both inboxes.
- [ ] The list in `docs/ops/backups-and-alerts.md` is updated.
- [ ] Manual results for scenarios O-01, O-02 are recorded. A scenario shared with another Work Item is finished when all of its parts are.

### Covers
- User Stories: 29
- Requirements: 69-70
- Testing Strategy: 6
- Scenarios: O-01, O-02
- Interview Ledger: L13

### Blocked by
None - ready to start

## #94 Stage 1.10: Live sign-in check

Source: https://github.com/sookoonspace/crewpoint/issues/94 · Parent: #44

### What to build
Run a live check of Google and Apple sign-in on real devices or simulators, including linking. This needs a person.

### Required context
- `docs/account-linking-behavior.md`, `docs/google-sign-in-web-setup.md`, and `docs/apple-sign-in-web-setup.md`.
- Live checks are deliberate, use throwaway data, and are never run on prod (L12).

### Acceptance criteria
- [ ] Google and Apple sign-in are checked live on real devices or simulators.
- [ ] Linking to a participant through a verified email is checked live.
- [ ] Results are recorded as manual results for L-01 and L-02 in the acceptance report.
- [ ] Manual results for scenarios L-01, L-02 are recorded. A scenario shared with another Work Item is finished when all of its parts are.

### Covers
- Requirements: 71
- Testing Strategy: 6
- Scenarios: L-01, L-02
- Interview Ledger: L12

### Blocked by
- #78 Stage 1.6: Account linking and deletion of participant data

## #95 Stage 1 exit: Stage 1 exit verification

Source: https://github.com/sookoonspace/crewpoint/issues/95 · Parent: #44

### What to build
Confirm Stage 1's exit criteria: every scenario is proven, and all five event types can be set up with no code differences.

### Required context
- The stage finishes when its exit criteria pass, without cutting anything (L4, L5).
- H-06's fee and receipts wording arrives in Stage 2. Stage 1 proves combined roles, own-group access, and that no other money is visible, and the report says so.

### Acceptance criteria
- [ ] Every scenario has a passing test, or a recorded manual result where a person is needed: A-01, A-02, A-05, B-04, B-05, B-10, B-14, H-01, H-02, H-05, H-06, H-07, J-05, J-06, L-01, L-02, O-01, O-02, O-03, S-01, S-02, S-07, S-08, X-01, X-02, X-03, X-05, X-06, Z-01, Z-04, GE-01, GE-02, GE-03, GE-04, GE-05, GE-06, GE-07, GE-08, GE-09, PA-01, PA-05, WE-07, WE-08, WE-10, GAP-CON-01, GAP-ANY-33, GAP-CRK-29, GAP-CON-30, GAP-ANY-31, GAP-WED-32, GAP-WED-12, GAP-WED-14, FND-01, FND-02, FND-03, FND-04, FND-05, FND-06, FND-07, FND-08, FND-09, FND-10, FND-11, FND-12.
- [ ] All scenarios above pass in the acceptance suite, and the guardrail runs in CI.
- [ ] A party, wedding, cricket, golf and convention event can each be set up from a template on a real phone, on web, and in the fixtures, with no code differences between them.
- [ ] Every role is proven against every restricted path.
- [ ] The 400-person fixture meets its baseline, and the 2,000-person tier is measured.
- [ ] `docs/testing/CONVENTION_TEST_REPORT_v3.md` is updated as scenarios turn green, with VENDOR rows marked as platform requirements.
- [ ] `CLAUDE.md` matches what was built.
- [ ] `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` all pass.

### Covers
- Requirements: 79-81
- Testing Strategy: 6, 7
- Interview Ledger: L4, L5

### Blocked by
- #46 Stage 1.1: Glossary and naming guardrail
- #47 Stage 1.1: Backlog and gap triage
- #48 Stage 1.1: Backend tests in CI and general acceptance suite
- #49 Stage 1.2: Server-validated expenses
- #50 Stage 1.2: Server-written settlements and notices
- #51 Stage 1.2: createEvent callable and no added strangers
- #52 Stage 1.2: Urgent message limits and message size
- #53 Stage 1.2: Task permissions
- #54 Stage 1.2: memberLimit and safe joins
- #55 Stage 1.2: CSV formula neutralising
- #56 Stage 1.2: Complete deletion
- #57 Stage 1.2: Departed members and dispute window
- #58 Stage 1.2: Administration limits
- #59 Stage 1.3: Event configuration and settings screen
- #60 Stage 1.3: Status lifecycle
- #61 Stage 1.3: Label resolver
- #62 Stage 1.3: Modules and event hub
- #63 Stage 1.3: Event time zones
- #64 Stage 1.4: Minimum app version
- #65 Stage 1.4: Permissions, presets, member documents and migration script
- #66 Stage 1.4: Cutover to permissions
- #67 Stage 1.4: Role screens and invite carrying a role
- #68 Stage 1.4: Crews and task crew
- #69 Stage 1.4: Co-owners and ownership transfer
- #70 Stage 1.4: Vendor scope and role matrix
- #71 Stage 1.5: Move budgetEstimate and payment handles
- #72 Stage 1.5: Expense access setting
- #73 Stage 1.5: No money leaks elsewhere
- #74 Stage 1.5: Privacy policy update
- #75 Stage 1.6: Participants, groups and roster
- #76 Stage 1.6: Custom fields and categories
- #77 Stage 1.6: Roster import
- #78 Stage 1.6: Account linking and deletion of participant data
- #79 Stage 1.6: Invite link, QR and /join/:code
- #80 Stage 1.6: Member picker and screens at scale
- #81 Stage 1.7: Sessions and venues
- #82 Stage 1.7: Attendance policies and personal agenda
- #83 Stage 1.7: Server-calculated counts
- #84 Stage 1.7: Count export and freeze
- #85 Stage 1.8: Chat paging and mirror fixes
- #86 Stage 1.8: Chat summary for the inbox
- #87 Stage 1.8: Expense and task mirrors apply only changes
- #88 Stage 1.8: Load fixture, baselines, costs and large pushes
- #89 Stage 1.9: System templates and picker
- #90 Stage 1.9: Follow-up setup and save as template
- #91 Stage 1.10: Restore rehearsal
- #92 Stage 1.10: Crash reporting
- #93 Stage 1.10: Backend alerts and outside billing check
- #94 Stage 1.10: Live sign-in check
