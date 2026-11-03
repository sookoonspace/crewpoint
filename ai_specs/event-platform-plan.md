# CrewPoint Event Platform: Plan

**As of:** Nov 3, 2026. **Replaces:** the convention-only plan.

CrewPoint is a general platform for events of any type and size: conventions, sports (cricket, golf and others), weddings and parties. An organizer sets each event up the way they want. **The Derod Gaam Convention is one event on the platform and its first large real-world test, not the product.**

## How to read this plan

- **Depth over dates.** Stages finish when their exit criteria pass. The only targets are Stage 1 at the end of November and the convention itself on Jul 16, 2027.
- **Nothing is skipped.** Every requirement from every source is assigned to exactly one stage, and a script checks that (see Coverage).
- **Stages run in dependency order.** If a stage runs long, later stages move. Nothing gets dropped to catch up.

## 1. Product principles

These apply to every feature and every review.

1. **General core, specific setup.** The app knows about groups, sessions and rules. It does not know about families, meals, tee times or mehndi. Those come from configuration.
2. **Rules are data.** Fees, attendance, reminders, quiet hours and check-in policy are settings on the event, each with a sensible default. If a behaviour would differ between two organizers, it is a setting.
3. **Templates are starting points.** A template is only a bundle of settings. An organizer can change anything after choosing one, and can save their own.
4. **Small stays simple.** A birthday party must be creatable in under a minute, with no setup screens. Modules stay hidden until turned on.
5. **People are not accounts.** A guest, child or player can exist without a login. Accounts attach to people when they want one.
6. **Permissions, not job titles.** Code checks permissions like `money.read`, never `isFinance`. Organizers can create their own roles.
7. **Server enforces everything.** The UI only hides things. Rules and functions decide.
8. **Words are the organizer's.** "Family", "Team" and "Foursome" are labels on one concept, in any language.

**Guardrail:** a CI test fails if event-specific words (`family`, `meal`, `derod`, `wedding`, `cricket`, `tee`) appear in `lib/` or `functions/src/` outside template data.

## 2. Shared vocabulary

Code uses the first column only. These go in a new `GLOSSARY.md`, which the ACT workflow reads.

| Concept | Meaning | Convention | Cricket | Golf | Wedding | Party |
|---|---|---|---|---|---|---|
| **Event** | The whole occasion | Convention | Tournament | Outing | Wedding | Party |
| **Organizer** | Who owns it: a person or organization | Nonprofit | Club | Club | Couple | Host |
| **Member** | A login with a role in this event | Committee | Director, captain | Pro, marshal | Planner, vendor | Co-host |
| **Participant** | A person attending, login optional | Attendee | Player | Golfer | Guest | Guest |
| **Group** | People handled together | Family | Team | Foursome | Guest party | Household |
| **Category** | A pricing or eligibility class | Adult, kid | Player, reserve | Member, guest | Adult, child | Adult, child |
| **Session** | Anything on the schedule | Meal, program | Match | Tee time, round | Mehndi, ceremony | The party |
| **Crew** | A working sub-team | Food team | Ground staff | Rules committee | Catering | Helpers |
| **Registration** | A group's sign-up | Registration | Team entry | Entry | RSVP | RSVP |
| **Custom field** | Organizer-defined question | Diet, T-shirt | Batting role | Handicap | Meal choice, side | Bringing what? |
| **Pass** | Token that proves entry | Family QR | Team QR | Player QR | Guest QR | Usually off |
| **Charge / Payment** | What is owed and paid | Family fee | Team fee | Entry, cart | Usually off | Usually off |
| **Contribution** | Money or goods offered | Sponsorship | Sponsor | Hole sponsor | Gift | Potluck dish |
| **Goal** | What contributions fund | Dinner, $7,000 | Trophy | Hole 7 | Honeymoon fund | Dessert |
| **Update** | Live change to everyone | Lunch moved | Rain delay | Frost delay | Venue change | Time change |
| **Incident** | Reported problem | Lost child | Injury | Lightning | Vendor late | Rarely |
| **Audience** | A saved set of recipients | Jain diet | Team A | Group 3 | Bride's side | Everyone |

## 3. Modules

The core is always on. An organizer switches modules on per event, and each template has defaults.

| Module | Does | Convention | Cricket | Golf | Wedding | Party |
|---|---|:-:|:-:|:-:|:-:|:-:|
| **Core:** event, members, roles | Always on | ● | ● | ● | ● | ● |
| Tasks | Work tracking | ● | ● | ● | ● | ○ |
| Chat | Conversation, with crew and group channels | ● | ● | ○ | ● | ● |
| Shared expenses | Today's split-and-settle, for small groups | ○ | ○ | ○ | ● | ● |
| Participants and groups | Roster, custom fields, import | ● | ● | ● | ● | ● |
| Schedule | Sessions, agenda, attendance, counts | ● | ● | ● | ● | ○ |
| Registration and RSVP | Forms and links, no install needed | ● | ● | ● | ● | ● |
| Collections | Charges, payments, refunds, receipts | ● | ● | ● | ○ | ○ |
| Contributions | Sponsors, donations, gifts, sign-ups | ● | ● | ● | ● | ○ |
| Competition | Fixtures, brackets, pairings, scores | ○ | ● | ● | ○ | ○ |
| Seating | Tables and assignments | ○ | ○ | ○ | ● | ○ |
| Check-in | Passes, scanner, offline | ● | ○ | ● | ○ | ○ |
| Volunteers | Shifts, counters | ● | ○ | ○ | ○ | ○ |
| Incidents | Reports and alerts | ● | ● | ● | ○ | ○ |
| Directory | Opt-in "who's here" | ● | ○ | ○ | ○ | ○ |
| Vendors and budget | Organizer finance | ● | ○ | ○ | ● | ○ |

● on by default, ○ available.

The two money modules stay separate on purpose. **Shared expenses** is friends splitting costs. **Collections** is an organizer charging attendees. Today's ledger and its "split among all members" rule cannot serve a 400-person event, and should not try to.

## 4. Data model

```text
organizers/{id}                 person or organization: legal name, tax ID, payout account
templates/{id}                  system and organizer-saved settings bundles

events/{id}                     title, organizerId, timeZone, venues, currency, languages,
                                status (draft | published | live | ended | archived),
                                modules, labels, settings, capacity
  members/{uid}                 roleIds, crewIds, permissions (denormalised), participantId
  roles/{id}                    name, permissions[]
  crews/{id}                    name, memberUids
  groups/{id}                   name, contactParticipantId, source
  participants/{id}             name, groupId, categoryId, userId?, language, custom field values
    private/{doc}               birth date, medical notes, contact details (separately permissioned)
  fields/{id}                   custom field definitions, who can see them
  sessions/{id}                 title, start, end, venueId, type, capacity, eligibility rules
    attendance/{participantId}  in, out, or waitlist
  registrations/{id}            groupId, status, answers, submittedBy
  passes/{id}                   token only, groupId, revokedAt
  checkins/{id}                 participantIds, by, at, deviceId (conflict-safe)
  charges/{id} payments/{id}    money, readable only with money permissions
  goals/{id} contributions/{id}
  vendors/{id} budgetLines/{id}
  reminders/{id}                rule: trigger, audience, repeat, stopWhen, channels
  outbox/{id}                   scheduled message per recipient: sendAt, status, language
  deliveries/{id}               what was sent, when, channel, result
  incidents/{id} updates/{id} audit/{id}
  tasks/ messages/ expenses/    existing, kept
```

**Key decisions, with reasons:**

- **Replace `memberIds` and `adminIds` arrays with the `members` subcollection.** At large sizes, every join rewrites the event document and wakes everyone listening to it. "My events" becomes a collection-group query. The arrays are used in 23 app files and 10 functions, so this is a real change, but **prod has 1 account today. It will never be cheaper.**
- **Money lives in its own documents.** Firestore rules cannot hide single fields, so `budgetEstimate` moves off tasks, and payment handles move out of the public profile.
- **Permissions are copied onto the member document** when a role changes, so each rule check costs one read and stays well under the per-request limit.
- **Every new mirrored collection follows the existing pattern:** Firestore write, Drift mirror, `kIsWeb` fork, and a schema migration with a test. Mirrors save only what changed, fixing the chat slowdown.
- **Very large collections are never loaded whole.** Rosters and counts use pagination and server-side aggregates.

### Permission catalogue (first version)

`event.manage` · `event.transfer` · `members.manage` · `roles.manage` · `schedule.edit` · `updates.send` · `participants.read` · `participants.edit` · `participants.readPrivate` · `participants.import` · `registrations.manage` · `money.read` · `money.record` · `money.refund` · `money.dueAtDoor` · `budget.read` · `budget.edit` · `contributions.manage` · `tasks.manage` · `chat.send` · `chat.urgent` · `messages.send` · `checkin.scan` · `checkin.lookup` · `counts.read` · `incidents.report` · `incidents.receive` · `reports.export` · `competition.manage` · `scores.enter`

**Built-in role presets** (organizers can edit or add): Owner, Co-owner, Admin, Finance, Crew lead, Crew member, Volunteer, Scorer, Vendor, Sponsor, Participant, Observer.

### Rules as data: examples

| Rule | Convention | Cricket | Golf | Wedding |
|---|---|---|---|---|
| **Fee** | Per group $300, includes 2 adults and all kids, +$150 per extra adult | Per team flat | Per person, plus optional cart | None |
| **Category** | Kid: under 18 on event start | Player, reserve | Member, guest | Child: under 12 |
| **Attendance** | Everyone in between arrival and departure, may opt out | By team fixture | By tee time | Invited per session |
| **Reminders** | Monthly, then weekly, stop when paid | Before each match | Before tee time | RSVP deadline |
| **Quiet hours** | 9pm–7am, event time during the event | Off on match day | Off on event day | Couple decides |
| **Unpaid check-in** | Allowed, notify finance | Blocked or allowed | Allowed | Not applicable |

Owner decisions on the convention (such as "unpaid check-in allowed, notify finance") become **settings saved in that event**, not code.

## 5. Stages

Each stage is split by the ACT workflow into one Spec with Work Items as GitHub Issues. Each stage also has a real test: its scenarios become passing tests in the acceptance suite.

---

### Stage 1: Platform foundation. Target: end of November

**Outcome:** an organizer of any event type can create an event from a template, choose its words, modules and roles, add people with or without accounts, build a schedule, and see accurate counts, with permissions enforced on the server.

The slices are in dependency order, and each one ships working software.

**1.1 Vocabulary and guardrails.** `GLOSSARY.md`, the guardrail test, and triage of `ai_specs/todo.md` and `docs/guide/GAPS.md` against the code. Add functions tests and rules to CI, since they run only locally today. Rename the convention suite to a general `test_acceptance/` with one fixture per template.

**1.2 Fix known security and data bugs.** Local testing found these, and later work must not build on them:
- Server validation for money writes: amounts, split totals, payer.
- Block forged notices, and restrict `kind` on messages to the server.
- Stop anyone adding a stranger as a member of their event.
- Rate limit urgent messages, and cap message size.
- Align task edit permissions between UI and rules.
- Make the member cap safe against simultaneous joins.
- Neutralise formula cells in CSV exports.
- Complete deletion: account deletion leaves the user ID in shared records, and event deletion leaves checklists and personal documents behind.
- Handle debts of departed members.
- Add a time limit to disputes, as an event setting.
- Decide whether admins may remove other admins, as a role permission.

**1.3 Event configuration.** Status lifecycle, time zone, venues, currency, language list, `modules`, `labels`, `settings`. Label resolver in the string layer. Replace the `EventType` enum with templates. The event screen shows only enabled modules.

**1.4 Members, roles and permissions.** The largest slice. `members` subcollection, role presets, custom roles, crews, migration from the arrays, new rules, updated callables and triggers, role management screens. Ownership transfer, co-owners, Observer and Vendor scopes, invite-as-role, people holding several roles. Includes the role matrix test for every role and restricted path.

**1.5 Money and privacy separation.** Move `budgetEstimate` and payment handles. Handles visible only to people who share an event. Update the privacy policy for children and for Canada, with counsel review, because 1.6 can hold children's data.

**1.6 Participants and groups.** Accountless people, groups with configurable labels, categories, custom fields with visibility, private data split. Add by hand, or by a general CSV import with column mapping, a validation report and safe re-import. Link a signed-in account to a participant safely. Bulk invites.

**1.7 Schedule and counts.** Sessions, multi-day blocks, venues, editable times, map entries. Attendance from arrival and departure, opt-outs, and per-session invitations. Personal agenda and now-and-next. Counts by any custom field, with export.

**1.8 Scale foundations.** Remove the fixed 50-member cap, with a configurable capacity. Page chat and save only changes. Fix mobile chat: settlement type lost, deleted messages stay visible, only 200 messages reachable. Add a generated load fixture and baseline measurements for each tier.

**1.9 Templates.** Blank, Party, Wedding, Cricket tournament, Golf outing, Convention. A template picker with sensible defaults, and a fast path for small events. Save-as-template.

**1.10 Operations baseline.** Restore rehearsal, crash reporting, backend error alerts (filtering stray browser requests), outside billing check, live check of Google and Apple sign-in.

**Exit criteria:**
- All listed scenarios pass in the acceptance suite, and the guardrail is on in CI.
- A party, wedding, cricket, golf and convention event can each be set up from a template on a real phone, on web, and in the fixtures, with no code differences between them.
- Every role is proven against every restricted path.
- 400-person fixture meets its baseline.

**Covers:** A-01, A-02, A-05, B-04, B-05, B-10, B-14, H-01, H-02, H-05, H-06, H-07, J-05, J-06, L-01, L-02, O-01, O-02, O-03, S-01, S-02, S-07, S-08, X-01, X-02, X-03, X-05, X-06, Z-01, Z-04, GE-01, GE-02, GE-03, GE-04, GE-05, GE-06, GE-07, GE-08, GE-09, PA-01, PA-05, WE-07, WE-08, WE-10, GAP-CON-01, GAP-ANY-33, GAP-CRK-29, GAP-CON-30, GAP-ANY-31, GAP-WED-32, GAP-WED-12, GAP-WED-14, FND-01, FND-02, FND-03, FND-04, FND-05, FND-06, FND-07, FND-08, FND-09, FND-10, FND-11, FND-12

---

### Stage 2: Registration and collections

**Outcome:** anyone can sign up from a link with no install, and an organizer can charge, record and refund.

- **Form builder:** sections, custom fields, conditional questions, per-person and per-group answers, per-session choices.
- **Public event page and link,** with deadlines, capacity and waitlist. Duplicate detection and merging.
- **RSVP:** yes, no or maybe, plus-ones and per-session invites, via a personal link and no account.
- **Sign-in:** email and phone one-time codes in CrewPoint itself, account linking. Invite controls: per-group, per-role, single-use and expiring codes.
- **Pricing rule engine:** per group, per person, per category, included counts, add-ons, early-bird. All convention fee scenarios run as data.
- **Payments:** card payments with each organizer paid directly. Zelle pending and confirm, check, cash, pay at check-in. Partial payments, failures, double-submit safety, chargebacks.
- **Refunds and cancellations:** policy as settings, and changes after payment.
- **Receipts:** organizer name and tax ID, wording per organizer type, nonprofit donation wording.
- **Contributions:** goals, shared funding, tiers, pledge and pay later, public recognition opt-in, plus gifts and sign-up lists.
- **Consent:** waivers, photo consent, and SMS and email consent.

**Exit criteria:** every event type can run a real sign-up in test mode, and a real small event pilot runs on it end to end.

**Covers:** A-04, B-01, B-02, B-03, B-06, B-07, B-08, B-11, B-12, B-13, B-15, C-01…C-20, D-01…D-15, L-03…L-07, X-04, X-07, Z-02, Z-03, Z-06, WE-01, WE-02, WE-03, WE-04, WE-05, PA-02, PA-03, GAP-ANY-02, GAP-ANY-03, GAP-WED-13, GAP-WED-15

---

### Stage 3: Communications and languages

**Outcome:** the right message reaches the right person, at the right time, in their language.

- **Language:** finish moving strings to the string layer, ARB pipeline, per-user language setting. Gujarati first, with a human translator, and organizer-entered content in several languages. A Unicode PDF font, which also fixes issue #29.
- **Email:** provider, authenticated domain, unsubscribe, bounces, per-organizer sender name.
- **Message queue:** `reminders` rules create `outbox` items. Defer instead of drop, per-event quiet hours, event time during events, an injectable clock, per-person content, de-duplication rules by type.
- **Audiences:** by group, category, crew, custom field or session.
- **Reliability:** delivery log, fallback to email, history, edit or cancel before sending, fan-out that holds at large sizes.
- **Web push:** fix VAPID and the hardcoded service worker (issue #31).
- **Optional SMS,** per decision.

**Exit criteria:** all N scenarios pass with a mock transport under a fake clock. Real sends work on dev in both languages, and alerts reach both inboxes.

**Covers:** A-03, B-09, J-09, N-00, N-01, N-02, N-03, N-04, N-05, N-06, N-07, N-08, N-09, N-10, N-11, N-12, N-13, N-15, N-16, N-17, N-18, N-19, N-20, N-21, N-22, O-04, S-03, S-04, U-03, Z-05, GAP-ANY-28

---

### Stage 4: Competition, programme and planning

**Outcome:** sports events can run fixtures and results, and weddings can run seating and multi-session plans.

- **Competition:** formats as data (round robin, knockout, stroke play, match play), fixture generator, reschedule, result entry with a scorer permission, standings and leaderboards.
- **Cricket:** team entries with rosters and captains, match cards, rain delay handling, net run rate as a format rule.
- **Golf:** tee times, pairings, handicaps, hole sponsors, scorecards.
- **Viewing:** spectator and sponsor access, and team channels.
- **Seating:** tables, assignment, printable charts.
- **Planning:** agenda grid, Kanban, recurring tasks, dependencies, task attachments, task templates.

**Exit criteria:** a full cricket tournament and golf outing run through fixtures to final results in the acceptance suite and in a real pilot, and a wedding seating chart prints correctly.

**Covers:** SP-01, SP-02, SP-03, SP-04, SP-05, SP-06, SP-07, SP-08, SP-09, SP-10, WE-06, GAP-CRK-04, GAP-ANY-05, GAP-ANY-06, GAP-ANY-07, GAP-ANY-08, GAP-CRK-10, GAP-CON-11

---

### Stage 5: Event day

**Outcome:** an event of any size runs smoothly on the day, with or without network.

- **Prototype first:** scanner and offline sync on real phones at a real venue, before the full build.
- **Check-in:** pass tokens that hold no personal data, scanner, limited name look-up, partial arrival, walk-ins, cancelled pass rejection, policy settings for unpaid check-in with notifications.
- **Offline:** queue with a clear conflict rule, multi-device sync, long-lived device sign-in, revocation, offline writes generally.
- **Volunteers:** shifts, reminders, counters with any categories, not only diets.
- **Live updates:** permissioned schedule changes that reach everyone.
- **Incidents and safety:** configurable categories and routing, acknowledgement and re-alert, bypass of mute for emergencies. Allergies, emergency contacts, guardian sign-in and out.
- **Directory,** printed fallback rosters.

**Exit criteria:** check-in rush and counter load tests pass at each size tier, and two offline devices sync correctly, proven at a real venue.

**Covers:** J-01, J-02, J-03, J-04, J-07, J-08, J-10, J-11, J-12, J-13, J-14, J-15, J-16, N-14, N-23, R-01, R-02, R-03, R-04, R-05, R-06, S-05, S-06, V-01, V-02, V-03, V-04, GAP-ANY-34

---

### Stage 6: Organizer finance and after the event

**Outcome:** organizers can manage suppliers and budgets, close the books and hand over to next time.

- Vendors, contracts, deadlines, budget lines, expense categories.
- Unequal splits in Shared expenses.
- Reconciliation, bulk thank-yous, full export, branded reports, scheduled exports, attendance and completion reports.
- Retention rules, and duplicate-event for next year.

**Covers:** H-03, H-04, K-01, K-02, K-03, Z-07, GAP-ANY-18, GAP-WED-40, GAP-CON-37, GAP-ANY-38, GAP-ANY-39

---

### Stage 7: Launch readiness

**Outcome:** public release, and the convention rehearsed in full.

- App store releases, release freeze process, rollback, on-call plan, venue network tests.
- Accessibility on every screen, and sessions with older non-technical users.
- Load tests at each tier in a staging project.
- **Pilots of increasing size:** a party, then a wedding or club match, then a cricket or golf event.
- **Convention dress rehearsal** with real volunteers, before its Jul 9 freeze.

**Covers:** O-05, O-06, O-07, O-08, U-01, U-02, U-04, U-05

---

### Stage 8: Extended features

**Outcome:** requests from the guides that were not needed for launch. They stay on the plan, and can move earlier if a pilot shows demand.

- **Chat:** reactions, edit and delete for everyone, search, read receipts.
- **Money:** multi-currency display, per-expense currency, receipt scanning, payment reconciliation with providers.
- **Sync:** background refresh.

**Covers:** GAP-ANY-16, GAP-ANY-17, GAP-ANY-19, GAP-ANY-20, GAP-ANY-21, GAP-ANY-22, GAP-ANY-23, GAP-ANY-24, GAP-ANY-36

---

### Already built

`GAPS.md` lists these as missing, but they exist. Stage 1.1 refreshes that file.

**Covers:** GAP-ANY-09, GAP-ANY-25, GAP-ANY-26, GAP-ANY-27, GAP-ANY-35

## 6. New scenarios beyond the convention spec

The convention spec only proves one event type. These are proposed additions, to be confirmed in each stage's interview.

**General**
- **GE-01** An organizer renames Group, Session and other labels, and they change everywhere, including messages and exports.
- **GE-02** Turning a module off hides it and blocks its server paths, without losing data.
- **GE-03** An organizer creates a custom role, and it is enforced on the server.
- **GE-04** An organizer adds a custom field and can count, filter and export by it.
- **GE-05** Guardrail: no event-specific words in app or backend code outside templates.
- **GE-06** An event is created from each template with no code differences, and saved as a new template.
- **GE-07** Events in different currencies and time zones behave correctly side by side.
- **GE-08** Draft, published, live, ended and archived states control who sees and changes what.
- **GE-09** Size tiers: small, 400 and 2,000 people all meet response targets, with the design holding at 5,000.

**Parties**
- **PA-01** A host creates a party on a phone in under a minute, with no setup screens.
- **PA-02** A guest answers RSVP from a link, with no install or account.
- **PA-03** Guests sign up to bring items, and items cannot be double-claimed.
- **PA-05** Guests with no account appear in counts.

**Weddings**
- **WE-01** Guest list with plus-ones and guest parties.
- **WE-02** RSVP by personal link, with a deadline and reminder.
- **WE-03** Meal choice per guest, totalled for the caterer.
- **WE-04** Guests invited to some sessions only (mehndi but not ceremony), and they see only those.
- **WE-05** Guests grouped by side, with counts.
- **WE-06** Seating chart with table limits, exported for print.
- **WE-07** Two people co-own one event.
- **WE-08** A vendor sees only their own tasks and payments.
- **WE-10** Ownership transfers and can be returned.

**Sports**
- **SP-01** Round robin and knockout fixtures are generated from entered teams.
- **SP-02** Team entries with rosters, captains and team fees.
- **SP-03** A scorer enters results, and others cannot.
- **SP-04** Standings and tie-breaks follow the format's rules.
- **SP-05** A rain delay moves matches, and everyone affected is told.
- **SP-06** Golf tee times and pairings are generated and can be adjusted.
- **SP-07** Handicaps produce correct net scores and a leaderboard.
- **SP-08** Hole sponsors appear on the right holes.
- **SP-09** Spectators and sponsors get a view-only role.
- **SP-10** Each team has its own channel, and others cannot read it.

## 7. Findings kept from local testing

Not all of these appear in the convention spec. Stage 1.2 fixes them.

- **FND-01** Members can write unrealistic or inconsistent money values.
- **FND-02** Members can forge settlement notices.
- **FND-03** Anyone can list a stranger as a member of an event.
- **FND-04** Urgent messages have no rate limit, and messages have no size limit.
- **FND-05** Task permissions differ between UI and rules.
- **FND-06** Simultaneous joins exceed the member cap (57 at a cap of 50).
- **FND-07** CSV exports can carry spreadsheet formulas.
- **FND-08** Event deletion leaves checklists and personal documents behind.
- **FND-09** Departed members' debts cannot be settled.
- **FND-10** Settlements can be disputed with no time limit.
- **FND-11** Mobile chat loses settlement type and keeps deleted messages, so disputes are unreachable.
- **FND-12** Admins can remove other admins, and change the currency that should stay fixed.

## 8. Decisions

**Decided on Nov 3, 2026**

| # | Decision | Outcome |
|---|---|---|
| **D1** | Build or buy registration | **Build into the platform in Stage 2.** The earlier "buy" was for one convention. The Stage 1 roster import still lets the convention use a bought tool as a stopgap if Stage 2 is not ready when it must open. VENDOR scenarios in the convention spec are now platform requirements |
| **D2** | How big is "big" | **Design for 5,000 people, test at 2,000** |
| **D3** | Who can create events | **Anyone who signs up**, with limits on sending messages and taking payments until verified |
| **D4** | Migrate to `members` now | **Yes**, while prod has 1 account |

**Before Stage 2**

- **D5** How does the platform make money, if at all: free, subscription or a fee per ticket?
- **D6** Payment provider. Recommend Stripe Connect, so each organizer is paid directly and handles their own payout details. Confirm this suits nonprofits and non-US organizers.
- **D7** Refund, waiver and tax defaults, and which countries to launch in.

**Before Stage 4**

- **D8** Sports depth: results and standings only, or ball-by-ball and hole-by-hole live scoring? Recommend results and standings first.
- **D9** Which other sports need formats at launch?

**Convention inputs still open**

- **D10** Nonprofit legal name and EIN, refund policy, who absorbs card fees, waiver text, SMS for emergencies, and the 21 assumptions in the report.

## 9. How we work

1. Each stage: `act-interview-flutter`, then `act-create-spec-flutter`, then `act-refine-spec-flutter`, then `act-create-issues-flutter`, then `act-implement-flutter`.
2. Each slice is a vertical, tested, working change with its own PR. Test first, with robots, stable keys and seams, per `CLAUDE.md`.
3. Each stage ends by running its scenarios and updating the report. A stage is finished when its exit criteria pass, not on a date.
4. After each stage, review this plan and update it.

## 10. Stage 1 and the end of November

Stage 1 is deliberately complete, and it is large. Roughly, it is 9–12 weeks of work at a normal pace for one developer, though agent-assisted work may go faster. **By Nov 30 we should expect slices 1.1–1.5 done with confidence, with 1.6–1.10 depending on pace.** Because the slices are in dependency order, wherever we are on Nov 30 is stable and shippable. We then continue until the exit criteria pass, skipping nothing. We'll review this after 1.4, since that is the biggest unknown.

## Coverage

Every item from these sources must appear in exactly one stage:

- `docs/testing/CREWPOINT_CONVENTION_TEST_v3.md`: all scenarios
- `docs/guide/GAPS.md`: all gaps
- Sections 6 and 7 of this plan

```bash
python3 scripts/check_platform_plan.py
```
