# Stage 1: Platform foundation

> Local copy of [GitHub issue #44](https://github.com/sookoonspace/crewpoint/issues/44), which is the source of truth for ACT workflow.

## Problem

CrewPoint works for small groups splitting tasks and costs, but its model assumes one shape of event. Roles are fixed to owner, admin and member. Everyone in an event must have a login. Every member can read all money. Membership lives in arrays on the event document and stops at 50 people. Words such as Budget and the `EventType` enum are built in, and there is no schedule, group, or attendee data at all.

The owner is taking CrewPoint to any event type and size: conventions, sports (cricket, golf and others), weddings and parties. [L1] Testing against a 400-person convention (`docs/testing/CONVENTION_TEST_REPORT_v3.md`) also found security and data bugs that later work must not build on.

Full context: `ai_specs/event-platform-plan.md`.

## Proposed Outcome

An organizer of any event type can create an event from a template, choose its words, modules and roles, add people with or without accounts, build a schedule, and see accurate counts, with permissions enforced on the server. A party, wedding, cricket, golf and convention event all run on the same code, differing only in data.

## User Stories

1. As a party host, I create an event on my phone in under a minute with no setup screens, so a small event stays simple.
2. As an organizer, I start from a template (Blank, Party, Wedding, Cricket tournament, Golf outing, Convention), then change anything, so I am not locked into its choices.
3. As an organizer, I save my configured event as my own template, so I can reuse it.
4. As an organizer, I rename concepts such as Group and Session, so the app uses my event's words.
5. As an organizer, I turn modules on and off, so people only see what my event uses.
6. As an organizer, I set the time zone, venues, currency and languages, so times and details are correct.
7. As an organizer, I move an event through draft, published, live, ended and archived, so people see and change only what is appropriate.
8. As an owner, I assign built-in roles or create custom ones, so people get exactly the access they need.
9. As an owner, I add a co-owner and can transfer ownership and get it back, so a couple or partners can share an event and hand it over.
10. As an owner, I invite someone directly into a role, so they do not need promoting after joining.
11. As an organizer, I create crews and assign members, so work is divided by sub-team.
12. As a vendor, sponsor or observer, I see only what my role allows, so others' information stays private.
13. As a person with several roles, I get the combination of those permissions scoped correctly, so as a crew member I see my own group's money but no one else's.
14. As an organizer, I add participants who have no account, including children, so everyone attending is counted.
15. As an organizer, I put participants into groups, so a family, team or foursome is handled together.
16. As an organizer, I add custom fields and choose who can see them, so I can collect a diet, handicap or meal choice.
17. As an organizer, I import a roster from CSV, map its columns, see a validation report, and re-import safely, so I can bring in large lists without duplicates.
18. As a participant, I sign in and get linked to my own record safely, so I see my own schedule and never another person's.
19. As an organizer, I share one invite link and QR code with many people, carrying a role and an expiry I choose, so seating a large group does not mean sending codes by hand.
20. As an organizer, I build a schedule of sessions over several days and venues, and edit times, so the plan can change.
21. As a participant, I see my personal agenda and what is happening now and next, so I know where to be.
22. As an organizer, I set arrival and departure, opt-outs and per-session invitations, so attendance is right without editing each person.
23. As an organizer, I see counts per session by any custom field and export them, so I can give a caterer exact numbers.
24. As an organizer, I lock counts on a date and see later changes as a list, so suppliers get a stable number.
25. As a member, I keep using tasks, chat and shared expenses smoothly at large sizes.
26. As a member of an event, I trust that amounts, notices and membership cannot be forged by other members.
27. As a removed or departed person's former group, I can still settle outstanding money.
28. As someone deleting my account, I am truly removed, as the privacy policy says.
29. As the operator, I learn of outages, can restore data, and see crashes, so problems do not go unnoticed.

## Requirements

Scenario IDs refer to `docs/testing/CREWPOINT_CONVENTION_TEST_v3.md` (A–Z, N) and `ai_specs/event-platform-plan.md` (GE, PA, WE, SP, FND, GAP). Each slice ships working software in this order. [L4]

### 1.1 Vocabulary and guardrails

1. Add `GLOSSARY.md` with a one-line definition of each term, and the convention, cricket, golf, wedding and party examples from the plan. Code uses only: Event, Organizer, Member, Participant, Group, Category, Session, Crew, Registration, Custom field, Pass, Charge, Payment, Contribution, Goal, Update, Incident, Audience. Update the architecture, RBAC and data-model sections of `CLAUDE.md` as each slice lands. [L2]
2. Guardrail test (GE-05): CI fails if the words `family`, `meal`, `derod`, `wedding`, `cricket`, `golf` or `tee` appear as whole words in identifiers or user-facing strings in `lib/` or `functions/src/`, outside the template data in Req 62. It ignores comments, Riverpod's `.family`, and `fontFamily`, which account for the 27 lines that match today. Any other exception is listed explicitly. [L2]
3. Triage `ai_specs/todo.md` and refresh `docs/guide/GAPS.md`, recording `GAP-ANY-09`, `-25`, `-26`, `-27` and `-35` as built after checking each against the code.
4. Run `npm test` for functions under the emulators in CI, and trigger that job on `firestore.rules`, `storage.rules` and `firestore.indexes.json` as well as `functions/**`.
5. Rename `test_convention/` and `functions/test_convention/` to `test_acceptance/`, updating `generate_report.py` and `jest.convention.config.js`, with one fixture per template. The convention fixture and its expected values stay as they are. Add party, wedding, cricket and golf fixtures.
5a. CI runs a list of finished scenario IDs from the acceptance suite, and fails if any of them goes red. Unfinished scenarios stay outside this list, so a planned gap does not block work.

### 1.2 Security and data fixes

Each fix keeps working for current members, and has a regression test written first.

6. **Money writes (FND-01).** Expense create and edit move to a callable, because Firestore rules cannot loop over splits. It rejects non-positive or non-finite amounts, amounts over a configured maximum, splits whose total differs from the amount by more than 0.01 per split, and payers or split users who are not members. Rules deny direct client expense writes. Existing stored records stay readable, including negative payment splits. [L17]
6a. **Expenses need a connection.** Without one, the expense form keeps what was entered, explains that it needs a connection, and offers retry. This is a deliberate exception to writing straight to Firestore, and applies only to money. [L17]
7. **Settlements (FND-01, FND-02).** A new `recordSettlement` callable writes the payment and its chat notice together. Clients can no longer create payment expenses directly. This also fixes the notice retry that rules deny today.
8. **Notices (FND-02).** Rules reject any client message with a `kind` field. `settlement` and `settlement_disputed` are written only by the server.
9. **Strangers (FND-03).** Events are created only through the `createEvent` callable in Req 63a, with the caller as Owner. Nobody can be listed as a member without their own action through the join flow or a permitted role assignment.
10. **Urgent messages (FND-04).** Sending needs `chat.urgent`. Beyond a configurable rate per sender per event (default 5 per hour), the message is still saved but sends no urgent push, and the sender is told. Message text is limited to 4,000 characters in rules and UI.
11. **Task permissions (FND-05).** UI and rules match: `tasks.manage` and a task's creator may edit it; an assignee may change only status and checklist. Clients cannot write `done`, `completedAt` or `completedBy` directly, so `markTaskComplete` stays the only path. A second completion does not overwrite the first `completedBy`.
12. **Member limit (FND-06).** `memberLimit` caps how many people can log in to an event. It is optional, and off by default. Joining uses a transaction on `memberCount`, so simultaneous joins cannot exceed it. A test runs 8 joins at one place remaining and must admit exactly 1. [L18]
13. **CSV exports (FND-07).** Cells that begin with `=`, `+`, `-`, `@`, tab or carriage return are neutralised in every export.
14. **Deletion (FND-08, Z-04).** Account deletion removes `chatReads` and `eventMutes`. In shared records it replaces the user ID in expense splits, `involvedUids`, `createdBy` and `completedBy` with one anonymous ID per person per event, so a ledger still balances and two deleted people are never merged. Event deletion also removes checklists, new subcollections, and members' per-event personal documents.
14a. **Deletion and new data.** Deleting an account removes that person's member documents and their own `private` documents. Their participant record is unlinked and anonymised: it stays as an unnamed entry keeping only age band, status, group and choice answers, so counts do not change. In an event that has not ended, the unnamed entry also keeps a one-way scrambled match key of the email and import ID, readable only by the server, so a new account with the same verified email links back to it and a re-import refills it instead of counting the person twice. A past event keeps anonymous counts only, with no key. Children entered by that person in a group they are a linked adult of are deleted with them, unless another linked adult remains in the group; imported records and children they entered for other groups stay. (Decided in #78.)
14b. **Owner deleting their account.** Ownership passes automatically to a Co-owner, or else the longest-standing Admin, or else the longest-standing member. This is the one exception to the confirmation in Req 30. An event with no other members is deleted.
15. **Departed members (FND-09).** Debts stay visible, labelled by the existing "(no longer in event)" name. Anyone with `money.record` can record a settlement on a departed person's behalf, and leaving shows a warning if the person has an outstanding balance. Leaving is not blocked.
16. **Disputes (FND-10).** `settings.disputeWindowDays` (default 30) limits disputes, enforced in `disputeSettlement`. The dispute option explains when the window has closed.
17. **Administration (FND-12).** Removing a member needs `members.manage`. Only an Owner or Co-owner can remove someone with `members.manage`, and owners can only leave after transferring ownership. Currency cannot change once an event has any expense or charge.

### 1.3 Event configuration

18. Events gain `organizerId`, `timeZone`, `venues`, `currency`, `languages`, `status`, `modules`, `labels`, `settings`, `capacity` and `memberLimit`, with defaults so a new event needs only a title. (A-01, GE-07)
18a. A personal organizer is created automatically for each user on first event creation. Organization details such as legal name and tax ID arrive in Stage 2. `creatorId` stays as a read-only record of who created the event, and no permission check uses it.
18b. `capacity` is how many people can attend, with or without an account. Stage 1 stores it and shows the count against it. Enforcement and waitlists arrive with registration in Stage 2. [L18]
19. Status values are exactly `draft`, `published`, `live`, `ended`, `archived`, and they mean:
    - **`draft`:** the status of a new event. Visible only to `event.manage`. Nobody can join. An event with plain members cannot go back to it. [L23]
    - **`published`:** visible to members and open to joining. An organizer moves an event here.
    - **`live`:** set automatically from the start time, in the event's time zone. An organizer can also set it by hand.
    - **`ended`:** set automatically after the end time, or by hand. **Settlements, expenses and chat stay open**, and everything else is read-only except to `event.manage`. [L20]
    - **`archived`:** set by hand, and read-only for everyone. `event.manage` can restore it.

    Events without dates stay in their current status until changed by hand. The migration maps `active` to `ended` if the end date has passed, or else `published`, and `archived` stays `archived`. Automatic changes run on a schedule with a clock seam. (GE-08)
20. A label resolver returns an event's label, or the default for a concept, with singular and plural, used by screens, exports and message text. Changing a label changes it everywhere with no restart. Label defaults live in one shared data file, read by both the app and the backend, so the two cannot drift apart. (GE-01)
21. Replace `EventType` with `templateId`. The current values map to `blank`, keeping their names as display text only.
22. Turning a module off hides its screens and entry points, and its server paths reject writes. Its data is kept, and comes back when turned on. The global Tasks, Chat and Budget tabs leave out that event's data for that module. (GE-02)
23. All dates display in the event's time zone, with the zone shown where a viewer's device differs. Session times are stored in UTC along with the event's zone, and date-only events stay on the chosen calendar date in every zone. Times stay correct across daylight-saving changes. This needs the `timezone` package and its web data, added with the exact resolved version as the caret floor. (GE-07)
24. Anyone signed in may create events. [L8] Messages and payments can later be limited until an organizer is verified; Stage 1 adds an `organizer.verified` flag, which the urgent rate limit reads, with no verification flow yet.

### 1.4 Members, roles and permissions

25. Replace the `memberIds` and `adminIds` arrays with `events/{id}/members/{uid}`, holding `uid`, `roleIds`, `crewIds`, `permissions`, `participantId` and `joinedAt`. "My events" uses a collection-group query. [L9]
26. Provide this permission catalogue: `event.manage`, `event.transfer`, `members.manage`, `roles.manage`, `schedule.edit`, `updates.send`, `participants.read`, `participants.edit`, `participants.readPrivate`, `participants.import`, `group.readOwn`, `group.editOwn`, `registrations.manage`, `money.read`, `money.record`, `money.refund`, `money.dueAtDoor`, `budget.read`, `budget.edit`, `expenses.readAll`, `contributions.manage`, `tasks.manage`, `chat.send`, `chat.urgent`, `messages.send`, `checkin.scan`, `checkin.lookup`, `counts.read`, `incidents.report`, `incidents.receive`, `reports.export`, `competition.manage`, `scores.enter`. Stage 1 enforces those whose features exist, and later stages use the rest.

26a. Built-in presets hold exactly these permissions. Organizers may edit presets per event and add custom roles. (H-01, H-05, GE-03, GAP-CRK-29, GAP-CON-30)

| Preset | Permissions |
|---|---|
| **Owner** | All |
| **Co-owner** | All except `event.transfer` |
| **Admin** | All except `event.transfer` and `roles.manage` |
| **Finance** | `money.read`, `money.record`, `money.refund`, `budget.read`, `budget.edit`, `expenses.readAll`, `contributions.manage`, `participants.read`, `counts.read`, `reports.export`, `chat.send` |
| **Crew lead** | `tasks.manage`, `schedule.edit`, `updates.send`, `participants.read`, `participants.edit`, `money.dueAtDoor`, `counts.read`, `chat.send`, `chat.urgent`, `messages.send`, `incidents.report`, `incidents.receive` |
| **Crew member** | `updates.send`, `participants.read`, `money.dueAtDoor`, `counts.read`, `chat.send`, `incidents.report`, `incidents.receive` |
| **Volunteer** | `checkin.scan`, `checkin.lookup`, `money.dueAtDoor`, `incidents.report`, `chat.send` |
| **Scorer** | `scores.enter`, `chat.send` |
| **Vendor** | None beyond Req 32 |
| **Sponsor** | `chat.send` |
| **Participant** | `chat.send` |
| **Observer** | None: read-only access to the event and published schedule |

26b. Every preset includes `group.readOwn`, and every member can read the event and its published schedule. `group.editOwn` is granted to a group's contact and to linked adults in that group. Own-group checks use group IDs copied onto the member document, to stay within the rules read limit. `money.dueAtDoor` means seeing, and recording a payment for, only the one group being handled.
27. A callable recalculates `permissions` on the member document whenever a role or assignment changes. Clients cannot write it. Rules check one permission with one member-document read.
28. Every Firestore path, callable and trigger uses permissions instead of `creatorId`, `adminIds` or job titles. UI gating reads the same permissions and updates live if a role changes while a screen is open.
29. Permissions combine across roles and are scoped. Holding several roles grants the union, and own-group access applies regardless of role. (H-06)
30. Co-owners and transfer: an event has one Owner and any number of Co-owners. Ownership can be transferred, needs confirmation by the new owner, and can be returned the same way. An event always has an Owner. (WE-07, WE-10, GAP-WED-32, GAP-ANY-31)
31. An event has one active invite, which carries a role applied on join. Removing someone with permission revokes write access on all paths, and existing behaviour from PR #40 is retained, including rotating the code. Leaving warns when it would leave at most one person holding `members.manage`, naming them, so there is always a backup; it never blocks leaving. (GAP-ANY-33, H-07) [L19]
32. Vendors see only tasks assigned to them, and their own payments or documents. (WE-08) Observers see only the event and its published schedule: no tasks, money or chat. Reading chat needs `chat.send`, so neither has chat unless the Owner adds it to their role. Expenses open to them only through `money.read` or the access setting in Req 38: "Everyone in the event" leaves them out unless the admin turns on "Also show Observers and Vendors", and they can be picked under "Selected roles and people", so an organizer can share final financials when they choose. [Decided 2026-11-08]
33. Screens: Roles, Role editor, Member detail, Crews, and Transfer ownership, each with loading, empty, error and permission-denied states.
34. **Migration.** An idempotent admin script with a dry-run mode converts each event, preserving everyone's access and old data, including status, `involvedUids`, and `budgetEstimate`. Order on each project:
    1. Confirm a fresh backup.
    2. Run the dry run, then the migration, keeping the old arrays.
    3. Deploy functions and rules together.
    4. Release the app and raise the minimum version.
    5. Run a verification script comparing every event's old arrays with its new members.
    6. Remove the old arrays in a separate step, after a stable period.

    Run on dev, then stg. **Prod waits for the lawyer approval in Req 39.** Rollback, before step 6, is redeploying the previous rules and functions and lowering the minimum version, because the arrays are still there. [L9] [L16]
34a. **Minimum app version.** The app reads a public `config/app` document at startup, using `package_info_plus` behind a new seam. Below the minimum, it shows a full-screen upgrade message, with a store link on mobile and a reload on web. If the document cannot be read, the app continues normally.
35. A role matrix test proves every role against every restricted path, on the server and in the UI. Committee-style roles cannot read any money field through the API. (H-05)

### 1.5 Money and privacy separation

36. `budgetEstimate` moves off tasks to a document that needs `budget.read`. Existing values are migrated. Tasks show it only to those with permission.
37. Payment handles move out of the public profile. They are visible only to people who share an event with that person, through a callable or a per-event projection. Removing the broad read on `users/{uid}` must not break names in chat, tasks and budget. (H-05)
38. **Expense access is an event setting that event admins control.** [L15] Anyone with `event.manage` (Owner, Co-owner and Admin by default) chooses one of these in Event settings:
    - **Everyone in the event:** all members except Observers and Vendors can read all expenses. A switch, "Also show Observers and Vendors", off by default, includes them too. [Decided 2026-11-08]
    - **Only people involved:** members read only expenses they paid for or are part of.
    - **Selected roles and people:** the admin picks any roles and individual members, who can read all expenses.

    In every option, the payer and people in a split can read that expense, and holders of `money.read` can read all expenses. (H-05)
38a. Template defaults: **Everyone** for Party, Wedding and Blank, **Selected roles and people** with nobody selected for Convention, so that only people holding `money.read` have full access, and **Only people involved** for Cricket tournament and Golf outing. The admin can change this at any time. [L15]
38b. The setting is enforced on the server, takes effect immediately for open screens, and each change is recorded with who made it and when. Only reading is affected: this does not grant adding, editing or deleting.
38c. Someone with limited access still sees their own balance and who to pay, without seeing other people's expenses. A callable returns that person's balance, calculated from all of the event's expenses on the server. Totals and exports show only what that person may read. [L15]
38e. **Queries follow access.** A member with `expenses.readAll` reads the whole collection. Anyone else reads with `involvedUids array-contains uid`, because rules deny a list query unless every possible result is allowed. Both the mirror and the web stream choose the query by access, and reset when access changes. [L15]
38f. **Money must not leak elsewhere.** Expense pushes go only to people who may read that expense, and leave out the amount otherwise. Settlement notices in chat leave out the amount unless the access option is Everyone. The global Budget tab, reports and exports all follow the same access. A test covers each of these paths. [L15]
38d. The setting screen has loading, error and saved states. The selected list shows roles and people by name, and warns before narrowing access, naming how many people will lose it. Choosing nobody is allowed, since permission holders keep access.
39. Update `assets/legal/privacy-policy.md` for children and for Canada, and regenerate hosted pages. **TODO before prod:** a lawyer must approve this policy before the platform work in this spec moves to prod, including the migration in Req 34. Development and testing on dev and stg carry on without waiting, and the operations work in 1.10 is not affected. Tracked in `ai_specs/todo.md`. [L16] (Z-01, Z-04)

### 1.6 Participants and groups

40. Add `participants`, `groups`, `fields` and per-participant `private` documents. Participants may have no account. Children are created only by someone with `participants.edit` or by a linked adult in their group. (PA-05, Z-01)
41. Custom fields support at least text, number, date, single choice, multiple choice and yes/no, plus required, per-participant or per-group, and a visibility level. Private fields are stored in `private`. Reports show age bands rather than birth dates unless a viewer has `participants.readPrivate`. (GE-04, GAP-WED-14, Z-01)
42. Categories are defined per event, and can be derived by a rule such as age on a date. Convention boundary: age 17 on event start is a child and age 18 an adult.
43. Roster screens page, search and filter by group, category and field, and stay usable at 5,000 people. Non-permitted members cannot browse the roster. [L7]
43a. **Screens built on the old member arrays.** Task assignment and expense splitting use a searchable, paged member picker. Event tiles use `memberCount`. Names load only for people on screen, replacing `usersByIdProvider`'s whole-list load. Equal splits need choosing who is included once an event passes 50 members, instead of defaulting to everyone.
44. **Import.** CSV upload with column mapping, a dry-run validation report, and row-level errors that do not stop good rows. Re-import matches on a mapped external ID, or else on normalised group plus name, and never duplicates. Manual edits to unmapped fields are kept. (X-01, X-02, X-06, S-02)
44a. **Where import runs.** The file uploads to a new `events/{id}/imports/` Storage path, readable and writable only with `participants.import`. A function parses and validates it, and tracks progress in an `imports/{id}` job document, so the job can be left and reopened. The uploaded file is deleted when the job finishes, and after 7 days at the latest. File picking goes through a new seam.
45. Rows missing from a re-import are listed for review. Confirming marks those groups as cancelled and removes them from counts, keeping the record. (X-03)
46. **Account linking.** Link when a signed-in user's **verified** email matches a participant, with `emailVerified` required, since verification is not enforced today. Never link on name alone. Only adult records count: exactly one adult with that email links automatically, while two or more adults, or only children, is ambiguous and goes to an organizer. Children are never linked to an account. (Decided in #78.) Linking creates a member with the Participant role, unless they already are one, and grants access only to that person's own group. Phone matching and personal links arrive in Stage 2. (X-05, L-01, L-02)
47. **Invite link and QR.** One shareable link and QR code per event, carrying a role, with an expiry the organizer sets. Rotating replaces the old link. On web, `/join/:code` opens the join flow, and signed-out users return there after signing in. On a phone, a scanned QR opens this web flow. Per-group, single-use and personal links, and opening links directly in the app, arrive in Stage 2. (GAP-CON-01) [L19]

### 1.7 Schedule and counts

48. `sessions` hold title, start, end, venue, type (free text with suggestions), tags, capacity and eligibility. Schedules span several days, with day and venue grouping. Placeholder times can be flagged as "to be confirmed". (A-02, GAP-WED-12)
49. Venues hold address, map link and directions, and locations may be "to be announced". (A-01, A-02, A-05)
50. Participants have optional arrival and departure times. Attendance uses an event policy:
    - **`arrivalToDeparture`** (default for Convention): sessions within a person's arrival and departure.
    - **`invitedOnly`** (default for Wedding): sessions a person or their group was invited to.
    - **`everyone`** (default for Party): all sessions.
    - **`bySession`:** each person chooses sessions, and nothing is assumed.

    Only exceptions are stored, as per-person opt-outs and invitations, and attendance is otherwise worked out from the policy. (J-06)
51. Personal agenda and now-and-next screens use the viewer's own record, with a fixture proving that someone arriving later sees nothing earlier, opted-out sessions are hidden, and sessions are limited to those invited. (J-05, J-06)
52. Counts per session and per event, by category and by any custom field, are calculated by a function and stored in a `stats` document with a last-updated time, recalculated after changes, so devices never need the whole roster. The screen shows when counts were last updated. (B-04, B-05, GE-04)
52a. **Convention values required in Stage 1.** With F1–F7 loaded and F8 cancelled through re-import, and with F10 absent because merging is Stage 2, the fixture must produce: 7 groups, 16 adults, 10 children, 26 people; 18, 2 and 6 by diet; 7 kids activity sign-ups; and the full §4 per-meal table for M1–M8. The before-merge, walk-in and post-event rows of §4 belong to Stages 2 and 5.
53. Export counts and rosters to CSV, with permissions enforced and any private fields excluded by default. (B-10)
54. Freeze: an authorised user locks counts on a date. Later changes appear as a list of differences, and the frozen numbers remain available. (B-14)

### 1.8 Scale foundations

55. Replace the fixed 50-member limit with `memberLimit`, where no value means unlimited. Design for 5,000 people and test at 2,000. [L7] [L18] (S-01)
56. The invite has an organizer-set expiry, so it can last a whole registration period. The default stays 24 hours on Blank and Party, and lasts until the event starts on other templates. [L19]
57. Chat loads the most recent 50 messages, with older pages on demand. Mirrors apply only changed documents through `docChanges`, and all older messages remain reachable when online. Offline, the most recent cached messages are shown, with a note that older ones need a connection. One new message with 5,000 in history settles in under 2 seconds in the same Mac test that measures about 53 seconds today. (S-07, FND-11)
57a. Each event keeps a server-maintained chat summary with the latest message and a message count. The global inbox uses this, plus `chatReads`, for previews and unread badges, instead of loading every event's messages. Urgent-unread status comes from the same summary.
58. Add a `kind` column to Drift chat messages and carry it through, so settlement and dispute bubbles work on mobile. Deleted messages disappear from the mirror. (FND-11)
59. Expense and task mirrors also apply only changes, and do not write once per row in a way that triggers a UI update per row.
60. A deterministic load fixture generates 108 groups and 400 people, and a 2,000-person tier. Record baselines: import of 400 under 2 minutes, a roster page under 1 second, counts under 2 seconds at 2,000. (S-02, GE-09)
61. Produce a measured cost estimate per tier, covering reads, writes and function runs. (S-08)
61a. Large push sends read recipients in batches, not one read per person, and must fit the function's time limit at 2,000 recipients, measured with a mocked transport. If this cannot hold at 5,000, the limit is recorded for Stage 3's message queue. (GE-09)

### 1.9 Templates

62. System templates are data only, in versioned JSON files under `assets/templates/`, also read by functions, so they need no separate seeding per environment. Blank, Party, Wedding, Cricket tournament, Golf outing, Convention. Each sets modules, labels, roles, fields, categories, attendance policy and settings. Events keep a copy of what they were created with, so a later template version never changes an existing event. (GE-06)
63. The first step of creation is a picker. Choosing Party or Blank with only a title and date creates the event in under a minute on a phone, with no further screens. (PA-01)
63a. A `createEvent` callable creates the event, owner member, roles and template data together, so a failed creation leaves nothing behind. It needs a connection. Without one, the form keeps what was entered, and explains and offers retry.
64. Other templates offer optional follow-up setup that can be skipped and completed later from Event settings.
65. Save-as-template copies configuration only, and never people, money or messages. Saved templates belong to the user who created them. (GE-06)
66. Fixtures prove each template creates correctly with no code differences. (GE-06)

### 1.10 Operations baseline

67. Rehearse a restore into a new database on dev, then document the result. (O-03)
68. Add crash reporting on iOS, Android and web, with no personal data in reports. (O-02)
69. Add backend error alerts for dev and prod, ignoring non-callable browser requests such as `GET` on callable URLs, and emailing derodian@gmail.com and admin@sookoon.space. [L13] (O-02)
70. Add a scheduled billing check that runs outside Google Cloud, with a read-only service account, and alerts on failure. Confirm that one alert actually reaches both inboxes. (O-01)
71. Run a live check of Google and Apple sign-in on real devices or simulators, including linking. This needs a person. (L-01, L-02)

### Task and crew requirements

72. Tasks gain optional `crewId`, shown and filterable when crews are in use, keeping owner, due date, status and the overdue filter. (H-02)

### User-visible states and boundaries

73. Every new screen has loading, empty, error and offline states, and retry where an action failed. Forms keep entered data on failure. Leaving a form with unsaved changes asks for confirmation.
74. Offline: a person's own group, agenda and sessions, and their tasks and chat, read from the local mirror on mobile, and show when they were last updated. Rosters stay online and paged, and are never fully mirrored, for size and privacy, so roster screens explain they need a connection. Offline check-in look-ups belong to Stage 5. Actions needing a callable (expenses, role changes, import, join, event creation) explain they need a connection and do not fail silently.
75. Slow network: long actions such as import show progress, can be left running on the server, and report results when reopened.
76. Concurrent edits: documents use last-write-wins with server timestamps. Membership, capacity and ownership use server transactions. If access is lost while on a screen, the app shows a clear message and returns to the event list.
77. Permission-denied responses are shown as understandable messages, and logged, never as raw errors.
78. All new screens work from 375 px to desktop using `ResponsiveShell`, `ContentMaxWidth` and `Breakpoints`, at 200% text, with semantic labels, 48 px targets and themed colours in light and dark mode. Strings go through `context.strings` and the label resolver. (GE-01)
78a. **Screens and routes,** under the existing `/dashboard/event/:eventId`: `settings` (with modules, labels, expense access, status and capacity), `roles`, `roles/:roleId`, `crews`, `transfer`, `people`, `people/:participantId`, `people/import`, `fields`, `schedule`, `schedule/:sessionId`, `agenda` and `counts`. `/dashboard/create` becomes the template picker. `/join/:code` is new, at the top level.
78b. **Event hub.** The event screen shows one entry per enabled module plus Agenda, in a list that scrolls at 375 px and a grid from 840 px. Settings is visible only to `event.manage`. Back returns to the event screen, cancel discards with the confirmation in Req 73, and a person who loses access goes to the event list as in Req 76.

### Scenario coverage

79. Every Stage 1 scenario has a passing test, or a recorded manual result where a person is needed: A-01, A-02, A-05, B-04, B-05, B-10, B-14, H-01, H-02, H-05, H-06, H-07, J-05, J-06, L-01, L-02, O-01, O-02, O-03, S-01, S-02, S-07, S-08, X-01, X-02, X-03, X-05, X-06, Z-01, Z-04, GE-01, GE-02, GE-03, GE-04, GE-05, GE-06, GE-07, GE-08, GE-09, PA-01, PA-05, WE-07, WE-08, WE-10, GAP-CON-01, GAP-ANY-33, GAP-CRK-29, GAP-CON-30, GAP-ANY-31, GAP-WED-32, GAP-WED-12, GAP-WED-14, FND-01, FND-02, FND-03, FND-04, FND-05, FND-06, FND-07, FND-08, FND-09, FND-10, FND-11, FND-12.

### Exit criteria

80. All scenarios above pass in the acceptance suite, and the guardrail runs in CI. [L5]
81. A party, wedding, cricket, golf and convention event can each be set up from a template on a real phone, on web, and in the fixtures, with no code differences between them.
82. Every role is proven against every restricted path.
83. The 400-person fixture meets its baseline, and the 2,000-person tier is measured.

## Technical Decisions

1. **General core.** Event-specific behaviour is settings or template data, never code. Rules are data. [L2] [L3]
2. **Members subcollection.** Replaces the arrays now, while prod has one account. These arrays appear in 23 app files and 10 functions. A "my events" query reads member documents across events, then the event documents. Event documents hold `memberCount`, not lists. [L9]
3. **Denormalised permissions.** One member-document read per rule check stays under the rules read limit. Only server code writes them.
4. **Money in separate documents.** Firestore rules cannot hide single fields.
4a. **Expense access in rules.** Rules cannot search a list of split objects, so expenses gain an `involvedUids` array, written by the expense callable in Req 6, and backfilled by the migration. The access setting is copied onto member documents as `expenses.readAll` by the same callable that recalculates `permissions`, including when a role or the setting changes. [L15] [L17]
5. **Follow existing patterns.** Hand-written Riverpod `Notifier` providers in `lib/app/core/providers.dart`, no `@riverpod`. Firestore writes, Drift mirror with `ref.onDispose` teardown, `kIsWeb` fork to raw streams for every new mirrored stream. New feature folders follow `data/domain/application/presentation`. Money writes and event creation are deliberate exceptions, going through callables. [L17]
6. **Drift.** Schema moves from v7 with explicit migration steps, and a `test/database/migration_vN_to_vN+1_test.dart` for each bump.
7. **Privileged actions are callables.** Role changes, transfers, joins, imports and settlements go through functions, listed in `functions/src/index.ts` and in the registry in `docs/cloud-functions-guide.md`.
8. **Counts on the server.** Rosters are paged, and counts are calculated by a function into a `stats` document, with attendance worked out from the policy plus stored exceptions, as in Req 50 and Req 52. Proven against the 2,000 tier.
9. **Registration is built, in Stage 2.** Stage 1's import and participant model must serve both native registration and external sources. [L6]
10. **New dependencies** need the exact resolved version as the caret floor. The `analyzer` and `sqlite3_flutter_libs` holds in `pubspec.yaml` stay.

## Testing Strategy

1. **TDD for logic and rules.** Domain logic, rules, callables and migrations are written test first, one behaviour at a time.
2. **Split:**
   - **Unit:** label resolver, permission union, category and age rules, attendance policies, count logic, CSV mapping and re-import matching, formula neutralising, template validation.
   - **Rules and backend (emulators):** every expense access option against every role, balances for limited members, the role matrix using the Req 26a table, money validation through the expense callable, forged writes, transactions, migration script (dry run and idempotency), deletion completeness, every new callable.
   - **Widget:** the expense access setting, every new screen's states, permission gating, label display, 200% text and semantics.
   - **Robot journeys (`test/journeys/`):** create from each template; party fast path; role assignment changing access live; import with errors and re-import; build schedule and view agenda; counts and export; transfer ownership and return it. Use `domain.feature.action` keys, and bounded pumps because mirrors keep emitting.
   - **Migration:** `test/database/` for every Drift bump, and a seeded old-shape fixture for the Firestore script.
   - **Acceptance (`test_acceptance/`):** one fixture per template, plus scenario IDs. Red means a product gap until that slice lands, and each Stage 1 ID must be green at exit.
3. **Seams:** Riverpod overrides on existing seams (`IAuthService`, `IUserRepository`, `IFcmGateway`, `IChatService`, `IFileExporter`, `IDeviceTimezone`, `AppLifecycleSource`), `Clock` for all time logic, `fake_cloud_firestore`, `NativeDatabase.memory()`, mocked `firebase-admin/messaging`. New platform calls such as CSV file picking, QR rendering and crash reporting get a new interface and provider. Add a clock seam to any backend code that schedules or compares time.
4. **Safety:** no `Firebase.initializeApp()` in tests. No real push, email, or payments. Automated tests use emulators only, because `crewpoint-dev` holds the owner's real data. [L12] Migration runs on real projects only as a deliberate manual step.
5. **Load:** the generated fixture, with timings recorded in the report. Local timings are baselines rather than production promises.
6. **Manual:** real phones and web for exit criterion 81, plus sign-in, restore rehearsal and alert delivery.
7. **Gates:** `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build`, `npm test`.

## Out of Scope

Later stages in `ai_specs/event-platform-plan.md` own these, and nothing is dropped:

- **Stage 2:** registration forms, public event pages, RSVP links, one-time code sign-in, pricing rules, payments, refunds, receipts, contributions, duplicate detection and group merging.
- **Stage 3:** email, scheduled messages and reminders, audiences, Gujarati and the language setting, Unicode PDF fonts, web push.
- **Stage 4:** competition, seating, agenda grid, Kanban, recurring tasks, dependencies, attachments.
- **Stage 5:** passes, check-in, offline writes, volunteers, live updates, incidents, safety, directory.
- **Stage 6:** vendors, budget lines, reconciliation, branded and scheduled reports, full export.
- **Stage 7–8:** store releases, pilots, chat reactions and search, multi-currency, receipt scanning.

## Open Questions

Each has a default the work can start from.

1. What does "verified organizer" require? Stage 1 only adds the flag. [L8]
2. Is 30 days the right default dispute window, and 5 urgent messages per hour the right rate limit? Both are settings.
3. Who is the lawyer reviewing the privacy policy? The owner will arrange this before prod, so it does not block development. [L10] [L16]
4. Which crash reporter? Sentry covers web as well as mobile, and Crashlytics does not cover web. Default: Sentry, decided in the work item.
5. ~~Should a Vendor's view also cover crew chat?~~ **Decided 2026-11-07:** no, unless the Owner adds `chat.send` to their role. Observers likewise. See Req 32.
6. Are the baselines in requirement 60 acceptable at 2,000 people on a real device? Revisit after measurement.

## Follow-Ups

- Review pace after slice 1.4, which is the biggest unknown. [L5]
- Update `docs/testing/CONVENTION_TEST_REPORT_v3.md` as scenarios turn green, and mark VENDOR rows as platform requirements. [L6]
- Add email and phone code sign-in as a scenario for Stage 2's spec, along with per-group, single-use and personal invite links, and opening links directly in the app. [L19]

## Notes

- Where this spec differs from `ai_specs/event-platform-plan.md`, this spec wins for Stage 1, including `memberLimit` and the single invite link.
- Requirements are ordered so each slice leaves the app stable and shippable. Target is the end of November, and the stage finishes when its exit criteria pass, without cutting anything. [L4] [L5]
- The convention remains the fixed real-world date: 350–400 people on Jul 16–19, 2027, hosted by a registered nonprofit. [L11] Its decision that unpaid check-in is allowed and notifies finance is a setting saved on that event, delivered in Stage 5. [L14]

## Interview Ledger

<details>
<summary>Show Interview Ledger</summary>

### L1

Status: current

Question: Is CrewPoint being built for the convention?

Answer: No. It covers conventions, sports (cricket, golf and others), weddings and parties, big to small. The convention is one type of event.

Decision: Build a general event platform, with the convention as its first large real-world test.

### L2

Status: current

Question: How should concepts be named?

Answer: Naming and rules should be general.

Decision: Code uses general terms, and event-specific words live only in template data, enforced by a guardrail.

### L3

Status: current

Question: How much should organizers control?

Answer: Leave room for event organizers to set it up the way they want.

Decision: Fees, attendance, reminders, roles, labels and modules are per-event settings.

### L4

Status: current

Question: What is the timing of the first stage?

Answer: A first stage by the end of the month, without skipping anything.

Decision: Target Nov 30, 2026, with slices in dependency order and no cuts.

Negative Requirements:
- Do not skip requirements to hit the date.

### L5

Status: current

Question: How firm is the timeline?

Answer: See how it goes, don't force the timeline. In-depth planning is most important.

Decision: Stages finish when exit criteria pass. The cut list and fixed gates were removed.

### L6

Status: current

Question: Does "buy registration" still stand now the product is general?

Recommended Answer:
- Build registration into the platform in Stage 2.
- Keep the Stage 1 roster import so the convention can use a bought tool as a stopgap.

Answer: Accepted.

Decision: Build in Stage 2, and keep import source-agnostic.

Answer History:
- Initial answer: buy for the convention launch.
- Final answer: build into the platform once the product became general.

### L7

Status: current

Question: How big is "big"?

Recommended Answer: Design for 5,000 people and test at 2,000.

Answer: Accepted.

Decision: Stage 1 designs for 5,000 people, and measures at 400 and 2,000.

### L8

Status: current

Question: Who can create events?

Recommended Answer: Anyone who signs up, with limits on sending messages and taking payments until verified.

Answer: Accepted.

Decision: Open creation, with verification limits added as sending and payments arrive.

### L9

Status: current

Question: Should member arrays be replaced now?

Recommended Answer: Yes, while prod has 1 account.

Answer: Accepted.

Decision: Migrate `memberIds` and `adminIds` to a `members` subcollection in Stage 1.

### L10

Status: current

Question: What does the privacy policy need?

Answer: Found in testing: it says CrewPoint is for ages 13 and up, while events register young children. The owner accepted that counsel review comes before real data.

Decision: Update the policy in Stage 1. The approval's timing is set by L16.

### L11

Status: current

Question: What are the convention's size and host?

Answer: 350–400 people, hosted by a registered nonprofit.

Decision: Used as the 400-person baseline. Nonprofit wording arrives with receipts in Stage 2.

### L12

Status: current

Question: Where can tests run?

Answer: Earlier live checks and the convention spec established that automated tests run on emulators, with mocked transports. Dev holds the owner's real data.

Decision: No automated test writes to a real project. Live checks are deliberate, use throwaway data, and are never run on prod.

### L13

Status: current

Question: Who receives alerts?

Answer: derodian@gmail.com and admin@sookoon.space, with a $5 monthly budget for now.

Decision: Backend error alerts and the billing check notify both addresses.

### L14

Status: current

Question: Can a family with a balance check in?

Answer: Yes, allowed, and notify the finance team.

Decision: Stored as the convention's event setting, and delivered in Stage 5.

### L15

Status: current

Question: Can an event admin choose who can read expenses?

Answer: Yes, an event admin selects who can read expenses.

Decision: Expense access is an event setting with Everyone, Only people involved, or Selected roles and people. Template values are only defaults.

Constraints:
- Payers and people in a split can always read that expense.
- People with limited access still see their own balance and who to pay.

### L16

Status: current

Question: When does the lawyer need to approve the privacy policy?

Answer: Keep a TODO for lawyer approval. It gets done before moving to prod.

Decision: Tracked as a TODO that must be finished before moving to prod. It does not block development.

### L17

Status: current

Question: Should money writes need a connection, since rules cannot check that splits add up?

Recommended Answer: Yes. Expenses need a connection, and the app keeps the form filled in with a clear message and a retry. The alternative was saving offline and having the server check afterwards.

Answer: 1A, accepted.

Decision: Expense create and edit go through a callable, and need a connection.

Reason: This is the only option that really stops forged amounts.

### L18

Status: current

Question: Are logins and seats separate limits?

Recommended Answer: Yes. `memberLimit` is how many people can log in, optional and off by default. `capacity` is how many can attend, with or without an account.

Answer: Yes.

Decision: Keep two settings. Stage 1 stores `capacity` and shows the count against it, and Stage 2 enforces it.

### L19

Status: current

Question: Do invite options belong in Stage 1 or Stage 2?

Recommended Answer: Stage 1 gets one shareable link and QR per event, carrying a role, with an expiry the organizer sets. Per-group, single-use and personal links wait for Stage 2.

Answer: 3A, accepted.

Decision: One active invite per event in Stage 1. A convention cannot send individual invites until Stage 2.

### L20

Status: current

Question: What should still work after an event ends?

Recommended Answer: Settlements, expenses and chat stay open, and everything else is read-only except to `event.manage`.

Answer: Accepted, along with the other review recommendations.

Decision: `ended` events keep settlements, expenses and chat open.

Reason: People log final costs and settle up after an event.

### L21

Status: current

Question: Items in slice 1.2 name permissions that do not exist until slice 1.4. What should they check until then?

Recommended Answer: Treat those permissions as owner or admin until the cutover in #66, then move each check to the named permission.

Answer: Accepted.

Decision: Interim owner-or-admin checks until #66. Plain members lose urgent sending at #52, which matches the Participant preset in Req 26a.

### L22

Status: current

Question: What can existing members do after migration, given that the Participant preset holds only `chat.send` and no permission covers creating tasks or adding expenses?

Recommended Answer: Creator becomes Owner, admins become Admin, and everyone else becomes Participant. Adding your own expense and creating tasks stay open to every member except Observer and Vendor.

Answer: Accepted.

Decision: Use this migration mapping, and keep these two actions open to every member except Observer and Vendor.

Reason: Req 34 preserves everyone's access.

### L23

Status: current

Question: What status does a new event start in?

Recommended Answer: Published, so it can be shared straight away.

Answer: Draft.

Decision: New events start as `draft`. After creating one, the organizer is offered "Publish and invite", and a draft's event screen offers Publish in place of inviting. An event with plain members cannot go back to draft.

Reason: Nothing is visible to others until the organizer chooses to publish. The event itself is still created with no further screens (Req 63).

</details>



