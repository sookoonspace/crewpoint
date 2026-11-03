# CrewPoint: Where We Stand

> Local copy of the [online document](https://claude.ai/artifact/AKVKtWQNpg4f3Z6RY1mVkY), exported Nov 3, 2026.

Nov 3, 2026 · @Derodian

## Summary

CrewPoint works today for small groups running tasks, chat and shared costs. It is becoming a general event platform for conventions, sports, weddings and parties of any size, and most of what that requires is still to be built.

The plan tracks **241 requirements across eight stages**, and a script checks that each one sits in exactly one stage. Stage 1 is specified and ready to be broken into work, with a target of the end of November. Stages finish when their tests pass, not on a date.

The Derod Gaam Convention (Jul 16–19, 2027, 350–400 people) is the platform's first large real-world test. Against its 157 test scenarios, the app today scores:

| Result | Scenarios | Meaning |
| --- | --- | --- |
| Pass | 2 | Works as the event needs |
| Partial | 22 | Something exists, but not enough |
| Fail | 3 | The 50-member cap, under-13s against the privacy policy, Gujarati lost in PDFs |
| Not built | 64 | Nothing exists yet |
| Registration and payments | 61 | Marked for a bought tool when tested. Now planned as Stage 2 of the platform |
| Needs a person or outside access | 5 | Such as real sign-in, app stores and the venue network |

## What we have today

The app runs on iOS, Android and web, across three environments (dev, stg and prod). Prod has 1 account, so no real users are on it yet.

| Area | What works |
| --- | --- |
| Accounts | Google, Apple, and email and password sign-in. Profile, and account deletion |
| Events | Create, edit, delete. One invite code per event. Owner, admin and member roles, with promote, demote and remove |
| Tasks | Assignee, due date, status, priority, checklists, filter, sort, group, duplicate, overdue view, PDF report |
| Chat | Real-time messages per event, urgent messages, inbox with unread badges |
| Shared expenses | Equal splits, donations, receipts, balances, settle-up links for Venmo and Cash App, disputes, CSV and PDF exports |
| Notifications | Push by category, with preferences, quiet hours, per-event mute, task reminders and a daily digest |
| Everyday use | Light and dark themes, phone-to-desktop layouts, reading offline on mobile. English only |

### Fixed or added in this work

| What | Status |
| --- | --- |
| Settling a debt corrupted balances | Merged (PR #39). Reaches users with the next app build |
| Removed members kept write access and could rejoin | Merged and live on dev, stg and prod (PR #40) |
| Daily backups, kept 14 days | On for dev, stg and prod. No restore tried yet |
| Point-in-time recovery | On for dev and prod |
| Outage alerts by email | On for dev and prod. Delivery not yet confirmed |
| $5 monthly budget alert | On, covering all three projects, alongside your existing $15 one |
| Convention test suite and report | Merged (PR #42) |
| Platform plan | Merged (PR #43) |

Automated tests stood at 865 Flutter tests (plus 4 skipped) and 169 backend tests passing, when last run on the merged code.

### Known problems in what we have

Stage 1 fixes all of these:

- Every member can read all expenses, and any signed-in user can read anyone's payment handles.
- Members can enter unrealistic amounts, forge settlement notices, and list a stranger as a member of their event.
- Mobile chat loses settlement notices' type, which makes disputes unreachable on phones. Deleted messages also stay visible, and only the latest 200 messages can be seen.
- One new message in a 5,000-message chat took about 53 seconds to process in testing.
- Account deletion leaves the user ID in shared records.

## What Stage 1 covers

Stage 1 lets an organizer of any event type create an event from a template, choose its words, modules and roles, add people with or without accounts, build a schedule, and see accurate counts. It covers 64 of the 241 requirements, and the full spec is [issue #44](https://github.com/sookoonspace/crewpoint/issues/44).

The slices run in dependency order, and each one ships working software.

| Slice | What it delivers |
| --- | --- |
| 1.1 Vocabulary and guardrails | One shared set of general terms, a CI check that blocks event-specific words in code, backend tests in CI, and a corrected gap list |
| 1.2 Security and data fixes | Server checks on money, no forged notices, no adding strangers, urgent message limits, consistent task permissions, safe joins, complete deletion, and handling for departed members' debts |
| 1.3 Event settings | Status from draft to archived, time zone, venues, currency, languages, switchable modules, and organizer-chosen labels |
| 1.4 Members and roles | 12 built-in roles, custom roles, crews, co-owners, ownership transfer, and the move to a new membership structure. This is the largest slice |
| 1.5 Money and privacy | Admins choose who can read expenses. Payment handles visible only to people sharing an event. Updated privacy policy |
| 1.6 Participants and groups | People without accounts, groups, custom fields, CSV import with safe re-import, and one invite link and QR per event |
| 1.7 Schedule and counts | Multi-day sessions, venues, attendance rules, personal agenda, now and next, counts by any field, CSV export, and count locking |
| 1.8 Scale foundations | No more 50-member cap, paged chat, mobile chat fixes, inbox summaries, large push sends, and measured baselines. Designed for 5,000 people and tested at 2,000 |
| 1.9 Templates | Blank, Party, Wedding, Cricket tournament, Golf outing and Convention. A party can be created in under a minute. Save your own |
| 1.10 Operations | Restore rehearsal, crash reporting, backend error alerts, a billing check from outside Google Cloud, and a live sign-in check |

**Stage 1 is finished when:**

- Every one of its scenarios passes.
- Party, wedding, cricket, golf and convention events can each be set up on a real phone and on web, with no code differences between them.
- Every role is proven against every restricted path.
- The 400-person test meets its targets, and the 2,000-person test is measured.

**End of November:** Stage 1 is roughly 9–12 weeks of work at a normal pace for one developer, though working with Claude may go faster. Slices 1.1–1.5 are the realistic expectation by Nov 30, with the rest depending on pace. Nothing gets cut to fit, and pace gets reviewed after slice 1.4.

**Stage 1 does not reach prod yet.** That waits for a lawyer to approve the privacy policy. The operations work in slice 1.10 is the exception.

## What comes next

Seven more stages follow Stage 1, each starting once what it depends on is ready. If one runs long, later stages move, and nothing is dropped. Five further requirements are gaps already built, which need only a record correction.

| Stage | What it delivers | Requirements |
| --- | --- | --- |
| 1. Platform foundation | Described above | 64 |
| 2. Registration and collections | Sign-up forms and RSVP links with no install, one-time code sign-in, fee rules, card and offline payments, refunds, receipts, sponsors and gifts, and more invite types | 67 |
| 3. Communications and languages | Email, scheduled messages and reminders, audiences, delivery history, Gujarati and other languages, Unicode PDFs, web push | 31 |
| 4. Competition and planning | Fixtures, brackets, tee times, handicaps, results and standings, seating charts, agenda grid, Kanban, recurring tasks, task attachments | 18 |
| 5. Event day | QR check-in, offline scanning, volunteers and shifts, live updates, incidents and emergency alerts, allergies and guardian sign-in, directory, printed fallback | 28 |
| 6. Organizer finance and wrap-up | Vendors, budgets, expense categories, unequal splits, reconciliation, full export, scheduled and branded reports, retention rules | 11 |
| 7. Launch readiness | App store releases, accessibility everywhere, load tests, pilots of growing size, and the convention dress rehearsal | 8 |
| 8. Extended features | Chat reactions, editing and search, read receipts, multi-currency, receipt scanning, payment reconciliation, background sync | 9 |

**Immediate next step:** run `act-create-issues-flutter #44` in a new session, which breaks Stage 1 into work items. Building starts from those.

## What is not covered yet

These sit outside the eight stages today. Some need a decision, and some aren't software at all.

### Not assigned to any stage

These come from the existing backlog and open issues. Slice 1.1 triages the backlog, and that's when each gets a stage or a clear no.

- End-to-end encrypted chat. The privacy policy states messages are not end-to-end encrypted.
- Live location tracking, which is only a placeholder in the code.
- Right-to-left language support, such as Arabic or Urdu.
- Using your own domain on the sign-in popup, in place of the firebaseapp.com address.
- Receipt images embedded in PDF reports.
- India's data protection rules, and automatic deletion of anonymised records.
- Raising Android's compile version (issue #25), which is held back by a dependency.
- Moving past the held `analyzer` and `sqlite3` versions, and evaluating Riverpod code generation (issue #24).

### Sports and event types not yet defined

- Cricket and golf are the only sports with planned formats. Others wait on decision D9 below.
- Ball-by-ball or hole-by-hole live scoring depends on decision D8. The current plan has results and standings.
- The new sports, wedding and party scenarios are my proposals, to confirm when each stage is specified.

### Not tested yet

- A live test with two accounts on real devices was started and paused, and hasn't been completed.
- Real Google and Apple sign-in, real push delivery on devices, and alert emails reaching your inboxes.
- Storage rules for files and receipts.
- A backup restore.
- Performance on real phones and production networks. Timings so far come from a Mac and a local emulator.

### Not software, but the event still needs it

- **People:** an owner for each stage, a family support contact, and volunteers with training.
- **Translation:** a native Gujarati speaker to review everything before release.
- **Hotel:** the group rate on early nights, cutoff handling, and the real hall capacity.
- **Money:** nonprofit bank access, who confirms Zelle, and card fees. In the test data, fees alone don't cover costs, so sponsorship targets matter.
- **Communications:** when to announce, remind and close registration, and how to reach families without smartphones.
- **On the day:** printed rosters and QR backups, scanner phones, chargers, a hotspot, and a plan for network, app or key-person failure.

### Main risks

- **Stage 1's size:** slice 1.4 changes rules, 10 backend functions and 23 app files, and it's the biggest unknown.
- **Lawyer timing:** approval doesn't block development, but it can delay any prod release.
- **Convention dates:** Jul 16, 2027 is fixed, while stages aren't. Registration in Stage 2 must be ready in time, or the roster import allows a bought tool as a stopgap.
- **Scale:** performance at 2,000 people on real devices stays unknown until slice 1.8.

## Decisions

The main direction is settled, and the remaining decisions don't block Stage 1.

### Made so far

| Decision | Outcome |
| --- | --- |
| What the product is | A general event platform, with names and rules that organizers can configure |
| Timeline | Don't force it. First stage targeted for the end of November, skipping nothing |
| Registration and payments | Built into the platform in Stage 2 |
| Size | Designed for 5,000 people, tested at 2,000 |
| Who can create events | Anyone who signs up, with limits until verified |
| Membership structure | Replaced now, while prod has 1 account |
| Expenses | Event admins choose who can read them. Adding one needs a connection |
| Limits | Logins and seats are separate settings |
| Invites | One link and QR per event in Stage 1. Individual invites in Stage 2 |
| After an event ends | Settlements, expenses and chat stay open |
| Alerts | $5 monthly budget, sent to derodian@gmail.com and admin@sookoon.space |

### Still needed from you

- [ ] Arrange a lawyer to approve the privacy policy before anything moves to prod.
- [ ] Review the 12 role presets and the rule for children's records in [issue #44](https://github.com/sookoonspace/crewpoint/issues/44).
- [ ] Before Stage 2: how the platform makes money (D5), the payment provider, with Stripe Connect recommended (D6), and launch countries plus refund, waiver and tax defaults (D7).
- [ ] Before Stage 4: live scoring or results only (D8), and which other sports need formats (D9).
- [ ] For the convention: nonprofit legal name and EIN, refund policy, who absorbs card fees, waiver text, SMS for emergencies, and the 21 assumptions in the test report (D10).
- [ ] Name who is building this, and for how many hours a week.

### Where the details live

- Stage 1 spec: [issue #44](https://github.com/sookoonspace/crewpoint/issues/44), with a local copy at `ai_specs/stage-1-platform-foundation-spec.md`
- Full plan: `ai_specs/event-platform-plan.md`
- Convention test report: `docs/testing/CONVENTION_TEST_REPORT_v3.md`
- Backups and alerts: `docs/ops/backups-and-alerts.md`
- Required before prod: `ai_specs/todo.md`
