#!/usr/bin/env python3
"""Builds scenarios.json and docs/testing/CONVENTION_TEST_REPORT_v3.md.

Usage: generate_report.py <flutter-json-results> <jest-json-results>
Statuses are assessed by hand below, then checked against the real test results:
the script refuses to write a status that the results contradict.
"""
import json
import re
import sys
from collections import Counter, OrderedDict

DOC = 'docs/testing/CREWPOINT_CONVENTION_TEST_v3.md'
OUT = 'docs/testing/CONVENTION_TEST_REPORT_v3.md'
doc = open(DOC, encoding='utf-8').read()

titles = OrderedDict()
for m in re.finditer(r'^- \*\*([A-Z]-\d\d)\*\* (.+)$', doc, re.M):
    titles[m[1]] = m[2]
for m in re.finditer(r'^\| \*\*(N-\d\d)\*\* \| ([^|]+) \|', doc, re.M):
    titles[m[1]] = m[2].strip()

P = {}
for raw, pri in [
    ('H-05 H-06 Z-01 Z-02 Z-03 Z-04 Z-05 Z-06 D-15 O-01 O-03 O-04 A-03 C-06', 'P0'),
    ('H-01 H-02 H-03 H-04 H-07 O-02 O-05 S-01 S-02 S-08 U-01 U-02 U-03 U-04 N-16 N-17 N-18 N-19 N-20', 'P1'),
    ('S-03 S-04 S-05 S-06 S-07 O-06 O-07 O-08 U-05 N-07 N-08 N-09 N-10 N-11 N-12 N-13 N-14 N-21 N-22 N-23 N-00', 'P2'),
    ('Z-07', 'P3'),
]:
    for i in raw.split():
        P[i] = pri


def priority(i):
    if i in P:
        return P[i]
    return {'A': 'P1', 'X': 'P1', 'J': 'P2', 'V': 'P2', 'R': 'P2', 'K': 'P3'}.get(i[0], 'P0 (tool choice)')


NB, VN, NR = 'NOT BUILT', 'VENDOR', 'NOT RUN'
PA, FA, PS = 'PARTIAL', 'FAIL', 'PASS'
A = {}


def put(ids, status, gap, effort='', evidence=''):
    for i in ids.split():
        A[i] = (status, gap, effort, evidence)


TOOL = 'Requirement for the bought tool. Not testable until one is chosen.'
put(' '.join(f'B-{n:02}' for n in (1, 2, 3, 6, 7, 8, 9, 11, 12, 13, 15)), VN, TOOL)
put(' '.join(f'C-{n:02}' for n in range(1, 21)), VN, TOOL)
put(' '.join(f'D-{n:02}' for n in range(1, 16)), VN, TOOL)
put('L-03 L-04 L-05 L-06 L-07', VN, TOOL + ' CrewPoint has no phone or email one-time code.', '', '`grep` for signInWithPhoneNumber, signInWithEmailLink: no hits')
put('N-01 N-02 N-03 N-04 N-05 N-06 N-15', VN, TOOL + ' CrewPoint has no email sending.')
put('X-07 Z-03 Z-06', VN, TOOL)

put('A-01', PA, 'Title and dates are stored. There is no event time zone or venue field.', 'S', '`A-01` tests in app_capability_test.dart')
put('A-02', NB, 'No schedule or session model.', 'M')
put('A-03', PA, 'Spelling guard added and passing, but the app has no Gujarati content to guard.', 'L', '`A-03` tests')
put('A-04', NB, 'No donation item model in CrewPoint. Depends on the tool.', 'M')
put('A-05', NB, 'No maps or directions entries.', 'S')
put('L-01 L-02', NR, 'Implemented with unit tests, but real Google and Apple sign-in needs a person on a device.', '', 'test/app/features/auth, firebase_auth')
put('B-04 B-05', NB, 'No attendee data. Needs the roster import plus count logic.', 'M')
put('B-10 B-14', NB, 'No registration or per-meal export, and no freeze.', 'M')
put('H-01', NB, 'No sub-teams. Only owner, admin and member exist.', 'M')
put('H-02', PA, 'Owner, due date, status and overdue filter work. No sub-team on tasks.', 'S', '`H-02` test, lib/app/features/tasks/application/tasks_filter.dart')
put('H-03', NB, 'No vendor model, contracts or deadlines.', 'M')
put('H-04', NB, 'Only a display-only `budgetEstimate` per task, readable by every member. No budget lines or actuals.', 'M')
put('H-05', PA, 'Outsiders are blocked, and members cannot change event settings. But every member can read all expenses and task budgets, and any signed-in user can read anyone\'s payment handles. Needs finance, committee and volunteer roles enforced in firestore.rules.', 'L', '`H-05` tests (3 pass, 4 fail)')
put('H-06', NB, 'No scoped roles exist.', 'M')
put('H-07', FA, 'Removed members can still edit their old expenses and assigned tasks, and can rejoin with the same code for 24 hours.', 'S', '`H-07` tests (3 fail), firestore.rules, removeEventMember.ts')
put('V-01 V-02 V-03 V-04', NB, 'No shifts, scanner, counter or issue reports.', 'L')
put('J-01 J-02 J-03 J-04 J-05 J-06 J-07 J-08 J-10 J-11 J-12 J-13 J-14 J-15 J-16', NB, 'No check-in, QR, agenda, live schedule or directory. Offline covers reads only.', 'L')
put('J-09', NB, 'English only. No Gujarati strings, and no language setting in the app.', 'L', '`J-09` test')
put('K-01 K-02', NB, 'No reconciliation or sponsor messaging.', 'M')
put('K-03', PA, 'Expense CSV is complete, but cells starting with `=` are not neutralised, the PDF stops at 200 expenses, and there is no full export.', 'M', '`K-03` tests (1 pass, 2 fail)')
put('X-01 X-02 X-03 X-04 X-05 X-06', NB, 'No import path. This is the new work created by buying registration.', 'L')
put('S-01', FA, 'joinEvent stops at 50 members, and invite codes expire after 24 hours.', 'S', '`S-01` tests, functions/src/events/joinEvent.ts:6')
put('S-02', NB, 'No import path to measure.', 'M', '`S-02` test')
put('S-03', PA, 'A 400-person send took about 2 s on the local emulator with a mock transport, inside the 30 s limit. Every recipient gets the same text, so a personal agenda is not possible yet. Production timing not measured.', 'M', '`S-03` tests (1 pass, 1 fail)')
put('S-04', PA, 'Delivery path handled 400 in about 2 s on the local emulator. There is no live-update feature using it, and real delivery time is not measured.', 'M', '`S-04` test')
put('S-05 S-06', NB, 'No check-in or meal counting to load.', 'L')
put('S-07', PA, 'The ledger is fast at 400 members. One new message with 5,000 in chat took about 53 s and 4,902 screen updates on a Mac.', 'M', '`S-07` tests (1 pass, 1 fail), chat_repository.dart')
put('S-08', PA, 'Rough estimate only, in section 2.1. Needs real traffic numbers.', 'S')
put('R-01 R-02 R-03 R-04 R-05 R-06', NB, 'No safety features or fields.', 'M')
put('Z-01', FA, 'The privacy policy says CrewPoint is for ages 13 and up and does not knowingly collect data from under-13s. This event registers children as young as 3. Needs a policy change and legal review.', 'M', 'assets/legal/privacy-policy.md:94')
put('Z-02 Z-07', NB, 'No consent record or retention rule for event data.', 'S')
put('Z-04', PA, 'The policy covers EU/UK rights and deletion exists, but the user ID stays in expense splits and tasks, and personal subcollections survive. Canada is not mentioned.', 'M', '`Z-04` tests (2 fail), deleteUserAccount.ts')
put('Z-05', NB, 'No email or SMS, so no unsubscribe.', 'S')
put('O-01', NR, 'All projects lost billing until Nov 2, 2026. Budget alerts could not be checked: this login has no access to the billing account.', 'S', 'gcloud billing budgets: permission denied')
put('O-02', NB, 'No crash reporting or analytics packages, and no alert policies on dev or prod.', 'S', 'pubspec.yaml; Cloud Monitoring API: 0 policies')
put('O-03', NB, 'No backup schedules on dev or prod, and point-in-time recovery is off. Data loss today would be permanent.', 'S', 'gcloud firestore backups schedules list: 0; databases describe: PITR disabled')
put('O-04', NB, 'No email sending or domain setup in the repo.', 'S')
put('O-05 O-07', NR, 'Needs store console access or a visit to the venue.')
put('O-06 O-08', NB, 'No release freeze or on-call plan.', 'S')
put('U-01', PA, 'The dashboard is fine at 200% text. Other screens are untested, and family and volunteer screens do not exist.', 'M', '`U-01` test')
put('U-02', PA, 'Dashboard tap targets are labelled and sized. Other screens are untested.', 'M', '`U-02` test')
put('U-03', FA, 'Gujarati is lost from PDF reports: Latin text extracts, Gujarati does not. Phone, web and email rendering are untested. Also see issue #29.', 'S', '`U-03` tests (1 pass, 1 fail)')
put('U-04', PA, 'The current palette is checked by existing tests. New screens are not built.', 'S', 'test/app/core/constants/app_colors_contrast_test.dart')
put('U-05', NR, 'Needs a real session with an older user, once the screens exist.')
put('N-00', PS, 'Push goes only through a mocked transport on the emulator. Email has no transport at all yet.', '', '`N-00` test')
put('N-07 N-12 N-13 N-17 N-19 N-20 N-22 N-23', NB, 'No email, segments, scheduled messages, history or de-duplication.', 'L')
put('N-08', PA, 'A daily digest exists, but it is opt-in, fires at 9:00am, and summarises tasks rather than an agenda.', 'M', '`N-08` test, onDigestSummary.ts:14')
put('N-09', NB, 'Reminders exist for tasks only. Quiet hours also use the profile time zone, so F5\'s 6:45pm reminder would be dropped.', 'M', '`N-09` test')
put('N-10', PA, 'The quiet-hours window is right for each time zone, but a blocked message is dropped rather than sent at 7:00am.', 'M', '`N-10` tests (1 pass, 1 fail), suppress.ts')
put('N-11', PA, 'Urgent chat bypasses quiet hours, which is the path a live update could use. There is no schedule-change message or email.', 'M', '`N-11` test')
put('N-14', PA, 'Urgent chat exists, but a muted event blocks it, so a lost-child alert can be missed. No issue categories.', 'S', '`N-14` test')
put('N-16', PA, 'Per-category opt-out works for push. No email categories.', 'S', '`N-16` test')
put('N-18', PA, 'Dead tokens are removed. Failures are not logged anywhere staff can see, and there is no email fallback.', 'M', '`N-18` tests (1 pass, 1 fail)')
put('N-21', PA, 'Per-recipient language lookup exists, with English templates only.', 'M', '`N-21` test')

missing = [i for i in titles if i not in A]
extra = [i for i in A if i not in titles]
assert not missing and not extra, (missing, extra)

# --- real results ---
res = {}
def note(i, ok):
    res.setdefault(i, []).append(ok)

for line in open(sys.argv[1]):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if not isinstance(e, dict):
        continue
    if e.get('type') == 'testStart':
        res.setdefault('_names', {})[e['test']['id']] = e['test']['name']
    if e.get('type') == 'testDone' and not e.get('hidden'):
        name = res['_names'][e['testID']]
        m = re.findall(r'\b([A-Z]-\d\d) ', name)
        if m:
            note(m[-1], e['result'] == 'success')
res.pop('_names')
for t in json.load(open(sys.argv[2]))['testResults']:
    for a in t['assertionResults']:
        note(a['title'][:4], a['status'] == 'passed')

summary = {k: (sum(v), len(v) - sum(v)) for k, v in res.items()}
for i, (ok, bad) in summary.items():
    s = A[i][0]
    if s == PS:
        assert bad == 0, i
    if s == FA:
        assert i in ('U-03', 'S-01', 'H-07') and bad > 0, i
    if s == PA:
        assert ok > 0 or i in ('N-21', 'N-14', 'N-08', 'Z-04'), (i, ok, bad)
    if s == NB:
        assert ok == 0, i
assert A['U-01'][0] == PA and summary['U-01'] == (1, 0)
total_ok = sum(v[0] for v in summary.values())
total_bad = sum(v[1] for v in summary.values())

json.dump(
    [
        dict(id=i, title=titles[i], status=A[i][0], gap=A[i][1], tested=i in res)
        for i in titles
    ],
    open('test_convention/fixtures/scenarios.json', 'w', encoding='utf-8'),
    ensure_ascii=False,
    indent=1,
)

SEC = OrderedDict([
    ('A', 'Event setup'), ('L', 'Login'), ('B', 'Registration'), ('C', 'Fees and payments'),
    ('D', 'Sponsorships'), ('H', 'Committee'), ('V', 'Volunteers'), ('J', 'Event days'),
    ('K', 'After the event'), ('X', 'Tool integration'), ('S', 'Scale'), ('R', 'Safety'),
    ('Z', 'Privacy'), ('O', 'Operations'), ('U', 'Accessibility'), ('N', 'Notifications'),
])
ST = [PS, PA, FA, NB, VN, NR]
counts = {k: Counter(A[i][0] for i in titles if i[0] == k) for k in SEC}
overall = Counter(A[i][0] for i in titles)


def cell(s):
    return s.replace('|', '\\|').replace('\n', ' ')


o = []
w = o.append
w('# Derod Gaam Convention 2027: Test Report (v3)\n')
w(f'**Test spec:** [`CREWPOINT_CONVENTION_TEST_v3.md`](CREWPOINT_CONVENTION_TEST_v3.md) · **Run:** Nov 3, 2026 · **Branch:** `test/derod-convention-v2`, cut from `main` at `3d83407`\n')
w(f'**Result: CrewPoint is not ready for this event, and most of the event-specific product does not exist yet.** Of {len(titles)} scenarios, {overall[PS]} passes, {overall[PA]} are partial, {overall[FA]} fail, {overall[NB]} are not built, {overall[VN]} belong to the tool you are buying, and {overall[NR]} need a person or outside access. The task, budget-split, chat and push foundations are sound, but they need permissions, Gujarati, email and an import path before they can serve this event.\n')
w('**Most urgent, because they apply before any real data arrives:**\n')
w('1. Choose the registration tool. The requirements in section 4 narrow the field quickly.')
w('2. Change the privacy policy. It says CrewPoint is not for under-13s, and this event registers 3-year-olds.')
w('3. Fix permissions. Every member can read all money today, which breaks your committee and volunteer rules.')
w('4. Turn on backups and billing alerts. There are no backup schedules on dev or prod, and no alert policies.\n')
w('**How far to trust this:**\n')
w(f'- {total_ok + total_bad} tests ran against the real app code and backend code: {total_ok} passed and {total_bad} failed. A failure here is a finding, and these tests sit outside CI so they don\'t block normal work.')
w('- Everything ran on emulators, with mocked push. Nothing touched `crewpoint-dev` or production, and no real message was sent.')
w('- Timings come from a Mac and a local emulator. Expect phones to be slower, and real delivery times are unmeasured.')
w('- NOT BUILT comes from reading and searching the code. Those scenarios are registered as skipped tests, with the reason.')
w('- The settlement fix in PR #39 is not on this branch. It does not affect any result here.\n')
w('## 1. Inventory\n')
w('| Area | Today |\n|---|---|')
for a, b in [
    ('Stack', 'Flutter 3.47 (iOS, Android, web), Firebase Auth, Firestore, Storage, Messaging, 15 Cloud Functions on Node 22, Drift on mobile'),
    ('Data models', 'Events, tasks with checklists, expenses with splits, chat messages, users. **No** family, attendee, schedule, sponsor, vendor, shift or check-in model'),
    ('Auth', 'Google, Apple, email and password. **No** phone or email one-time code'),
    ('Roles', 'Owner, admin and member only, enforced in rules and functions. No finance, committee, volunteer or family roles'),
    ('Payments', 'None processed. Settle-up records payments between members and opens Venmo or Cash App links; it cannot collect fees'),
    ('Notifications', 'Push only, with 7 categories, per-category preferences, event mute, dead-token cleanup and English templates. Quiet hours **drop** messages. No email, SMS, scheduled messages, segments, delivery log or history'),
    ('Scheduling', 'Two jobs: task due reminders every 15 minutes and an hourly digest check. Neither takes an injectable clock'),
    ('Offline', 'Reads work on mobile through the Drift copy. Firestore queues writes, but nothing covers check-in rules or conflicts'),
    ('Languages', 'English only. The string layer is designed for more, but no Gujarati exists'),
    ('Limits', '50 members per event, invite codes last 24 hours, one invite code per event, PDF reports stop at 200 expenses'),
    ('Existing tests', '862 Flutter tests passing and 4 skipped on `main`, and 155 backend tests passing. One flaky timing test was seen once under load'),
]:
    w(f'| {a} | {b} |')
w('\n## 2. Scorecard\n')
w('| Section | ' + ' | '.join(ST) + ' | Total |\n|---|' + '---:|' * (len(ST) + 1))
for k, name in SEC.items():
    c = counts[k]
    w(f'| {k}: {name} | ' + ' | '.join(str(c[s]) if c[s] else '·' for s in ST) + f' | {sum(c.values())} |')
w('| **Total** | ' + ' | '.join(f'**{overall[s]}**' for s in ST) + f' | **{len(titles)}** |')
w('\n### 2.1 Cost estimate (S-08)\n')
w('A rough, worst-case model, not a measurement. Chat loads the whole history, so 400 people opening a 5,000-message chat 5 times a day could mean up to **10 million Firestore reads a day**, or low single-digit dollars a day at list prices as I recall them (check current pricing). Offline caching should reduce this. Cost is not the main risk; the 53-second slowdown per message is. Limiting chat history fixes both. SMS would be the largest variable cost if you adopt it, especially for UK numbers.\n')
w('## 3. Results\n')
w('| ID | Scenario | Status | Evidence | Gap | Effort | Needed by |\n|---|---|---|---|---|---|---|')
for i, t in titles.items():
    s, gap, eff, ev = A[i]
    if i in summary:
        ok, bad = summary[i]
        ev = ev or f'`{i}` test'
    t2 = t if len(t) < 90 else t[:87].rsplit(' ', 1)[0] + '…'
    w(f'| {i} | {cell(t2)} | {s} | {cell(ev)} | {cell(gap)} | {eff or "·"} | {priority(i)} |')
w('\n## 4. Priorities by the real calendar\n')
w('**P0: before announcing registration (Nov–Dec 2026)**\n')
w('- **Choose the tool.** Check these first, because they are hardest to find: hybrid family fee (C-01), per-person meal choices and arrival times (B-01, B-03), Gujarati forms and emails (B-09, N-01), Zelle pending and offline payments (C-03, C-04), full data export (X-01), and sponsorship items with shared funding (D-02).')
w('- **Privacy and legal:** Z-01, Z-03, Z-04, Z-05 and Z-06, including the nonprofit\'s legal name, EIN and receipt wording (D-15).')
w('- **Permissions:** H-05 and H-06, before committee members and real data arrive.')
w('- **Resilience:** O-01 billing alerts, O-03 backups, O-04 email domain.\n')
w('**P1: sponsorship and hotel push (Jan–Jun 2027)**\n')
w('- Roster import (X), schedule and venue (A), sub-teams, vendors and budget (H), the 50-member cap (S-01), and app store approval (O-05).')
w('- Accessibility (U-01…U-04) and notification controls (N-16…N-20).\n')
w('**P2: final week and event days (Jul 2027)**\n')
w('- QR check-in, offline sync, meal counter, agenda and live updates (J, V), safety (R), and scale rehearsal (S-03…S-07).')
w('- Event-week messages in both languages, by push and email (N-07…N-14, N-21…N-23). Rehearse before the Jul 9 release freeze (O-06).\n')
w('**P3: after the event**\n')
w('- Reconciliation, sponsor thank-yous, export, and data retention (K, Z-07).\n')
w('## 5. Top 10 gaps\n')
for n, (title, body) in enumerate([
    ('No event data in CrewPoint', 'Build a roster import from the tool\'s export into new family and attendee models (X-01…X-06). Everything on event days depends on it. Decide the export format once the tool is chosen.'),
    ('Permissions do not match your roles', 'Add finance, committee, volunteer and family roles. Move money into documents only finance and admins can read, since Firestore rules cannot hide single fields. Add a test per role (H-05, H-06).'),
    ('Privacy policy excludes this event\'s children', 'Update the policy with counsel, add parental entry, and show age bands rather than birth dates (Z-01).'),
    ('No Gujarati', 'Add the Gujarati strings through the existing string layer, a language setting, translated templates and a PDF font that supports Gujarati. Use a human translator and keep the spelling check (A-03, J-09, N-21, U-03).'),
    ('No email', 'Add an email provider with an authenticated domain, unsubscribe and bounce handling. Web-only families depend on it (N-07, N-22, O-04).'),
    ('No check-in or offline event-day flow', 'Build family QR tokens, a scanner, the limited name search, an offline queue with a clear conflict rule, and a printed fallback (J, V). This is the largest single build, so prototype it early and test it at the hotel.'),
    ('Scale limits', 'Replace the 50-member cap, and load chat in pages while saving only what changed. That one change removes the 53-second slowdown and most of the read cost (S-01, S-07).'),
    ('Messages are dropped, not delayed, and cannot be scheduled', 'Add a scheduled message queue that holds quiet-hours messages until 7:00am, uses event time during the event, and supports per-person content. Emergency alerts should ignore event mute (N-09, N-10, N-14, S-03).'),
    ('Removed members keep access', 'Check current membership in the rules for expenses, tasks and messages, and rotate or block invite codes on removal. A small, high-value fix (H-07).'),
    ('No safety net', 'Turn on scheduled backups, billing alerts and crash reporting, and name an on-call person. Small tasks, and yesterday\'s billing outage shows why they matter (O-01…O-03, O-08).'),
], 1):
    w(f'{n}. **{title}.** {body}')
w('\n## 6. Testability gaps\n')
for g in [
    '**No clock seam in the backend.** `sendCategorizedPush` and the scheduled jobs call `new Date()` directly. The N-10 test works around it by faking only `Date` in Jest. Anything that schedules messages should take a clock.',
    '**No email or SMS transport to mock.** N-00 can only prove safety for push.',
    '**Scheduled jobs have no recipient-level result.** `sendCategorizedPush` returns only counts, and skipped messages are not recorded, so recipient assertions must inspect the mock.',
    '**Real sign-in and real delivery.** Google and Apple sign-in, APNs and FCM delivery need real devices and accounts (L-01, L-02).',
    '**Not checked: Storage rules, store listings, billing budgets (no access), venue network.**',
    '**Live device testing was stopped at your request** before any test account was created. The Android and iOS builds succeeded, and the app launched on both. A manual two-account pass on dev is still worth doing for the features that exist.',
    '**Vendor scenarios** cannot run until a tool is chosen. Rerun them against the tool, using the same fixture.',
]:
    w(f'- {g}')
w('\n## 7. Assumptions\n')
w('| Assumption | What the app does now | Recommendation |\n|---|---|---|')
for a, b, c in [
    ('A 1-adult family pays $300', 'No fee logic. Tool requirement', 'Confirm'),
    ('Age is computed on Jul 16, 2027', 'No age data', 'Keep, and collect birth year or an under-18 flag if the tool allows, to hold less about children'),
    ('The buy/CrewPoint split in §1.1', 'New', 'Confirm, especially sponsorships'),
    ('Sign-in with Google, then email code, is one account (L-06)', 'Not built; depends on the tool', 'Keep'),
    ('Bhajan Prasad accepts any amount before one is set', 'Not built', 'Keep'),
    ('Pledged-but-unpaid sponsors appear on the thank-you list', 'Not built', 'Confirm: consider listing only after receipt'),
    ('F5\'s pre-event nights get the group rate', 'Outside the app', 'Ask the hotel'),
    ('Volunteers can search by family name if QR fails', 'Not built', 'Keep, with logging'),
    ('Duplicate who already paid goes to finance', 'Not built', 'Keep'),
    ('Walk-ins past capacity need admin override', 'Not built', 'Confirm the real hall limit with the hotel'),
    ('Paid families are not re-billed after a fee change', 'Not built', 'Keep'),
    ('Pay-at-check-in families get no unpaid reminder', 'Not built', 'Keep, with one reminder in N-07'),
    ('Web-only users get no session reminders', 'No email at all', 'Keep; email every 15 minutes would be noise'),
    ('Quiet hours are 9:00pm–7:00am, deferred not dropped', 'User-set window; **drops** messages', 'Keep; requires a build'),
    ('Event time applies to quiet hours Jul 16–19', 'Uses the profile time zone', 'Keep; requires a build'),
    ('Pledge reminders stop at event start', 'Not built', 'Confirm'),
    ('Event-day messages reach each family member with a login', 'Not built', 'Keep'),
    ('Shift reminders the day before at 6:00pm, and 30 minutes before', 'Not built', 'Keep'),
    ('Opted-out families still get receipts and live changes', 'Per-category opt-out exists for push', 'Keep, and have counsel check it against email rules'),
    ('Lost-child alerts re-send after 2 minutes with no acknowledgement', 'Not built', 'Confirm with whoever runs safety'),
    ('Registration is a bought tool even for per-meal data', 'New', 'If no tool handles per-meal choices, collect them in a follow-up form and import'),
]:
    w(f'| {a} | {b} | {c} |')
w('\n**Owner input still needed:** nonprofit legal name and EIN, refund policy (C-13), who absorbs card fees (C-20), waiver text (Z-03), whether to adopt SMS for emergencies (N-14).\n')
w('## How to re-run\n')
w('```bash\nflutter test test_convention/\ncd functions && npx firebase emulators:exec --only firestore,auth \\\n  "npx jest --runInBand --config jest.convention.config.js"\n```')
open(OUT, 'w', encoding='utf-8').write('\n'.join(o) + '\n')
print('wrote', OUT, 'scenarios', len(titles), dict(overall), 'tests pass/fail', total_ok, total_bad)
