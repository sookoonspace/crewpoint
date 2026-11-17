#!/usr/bin/env python3
"""Builds docs/testing/CONVENTION_TEST_REPORT_v3.md from the scenario records.

Usage: generate_report.py <flutter-json-results> <jest-json-results>

test_acceptance/fixtures/scenarios.json is the record: each scenario's status
and gap are kept there by hand as work lands. This script reads it, checks it
against the real acceptance results, and refuses to write a report whose
statuses the results contradict. It never changes scenarios.json.

    flutter test test_acceptance/ --reporter json > flutter.json
    (cd functions && firebase emulators:exec --project demo-crewpoint \\
      --only firestore,auth \\
      "npx jest --runInBand --config jest.acceptance.config.js --json --outputFile=../jest.json")
    python3 test_acceptance/generate_report.py flutter.json jest.json
"""
import json
import os
import re
import subprocess
import sys
from collections import Counter, OrderedDict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_finished import ids_in, read_flutter, read_jest  # noqa: E402

DOC = 'docs/testing/CREWPOINT_CONVENTION_TEST_v3.md'
RECORD = 'test_acceptance/fixtures/scenarios.json'
FINISHED = 'test_acceptance/finished_scenarios.json'
OUT = 'docs/testing/CONVENTION_TEST_REPORT_v3.md'
RUN_DATE = 'Nov 17, 2026'

PS, PA, FA, NB, PL, NR = 'PASS', 'PARTIAL', 'FAIL', 'NOT BUILT', 'PLATFORM', 'NOT RUN'
ST = [PS, PA, FA, NB, PL, NR]

doc = open(DOC, encoding='utf-8').read()
titles = OrderedDict()
for m in re.finditer(r'^- \*\*([A-Z]-\d\d)\*\* (.+)$', doc, re.M):
    titles[m[1]] = m[2]
for m in re.finditer(r'^\| \*\*(N-\d\d)\*\* \| ([^|]+) \|', doc, re.M):
    titles[m[1]] = m[2].strip()

record = OrderedDict((s['id'], s) for s in json.load(open(RECORD, encoding='utf-8')))
finished = set(json.load(open(FINISHED, encoding='utf-8'))['finished'])
assert list(record) == list(titles), 'scenarios.json and the test spec list different scenarios'
unknown = {s['status'] for s in record.values()} - set(ST)
assert not unknown, f'unknown statuses: {unknown}'

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
    return {'A': 'P1', 'X': 'P1', 'J': 'P2', 'V': 'P2', 'R': 'P2', 'K': 'P3'}.get(i[0], 'P0')


# The later stage that owns an open scenario, from ai_specs/event-platform-plan.md.
STAGE_BY_PREFIX = {'B': 2, 'C': 2, 'D': 2, 'N': 3, 'J': 5, 'V': 5, 'R': 5, 'K': 6}
STAGE_BY_ID = {
    'A-03': 3, 'A-04': 2, 'H-03': 6, 'H-04': 6, 'X-04': 2, 'S-03': 3, 'S-04': 5, 'S-05': 5,
    'S-06': 5, 'U-03': 3, 'O-04': 3, 'O-05': 7, 'O-07': 7, 'Z-03': 2, 'Z-05': 3, 'Z-06': 2,
    'Z-07': 6,
}


def stage(i, row):
    if row['status'] == PS:
        return '·'
    m = re.search(r'Stage (\d)', row['gap'])
    n = int(m[1]) if m else STAGE_BY_ID.get(i, STAGE_BY_PREFIX.get(i[0]))
    return f'Stage {n}' if n else '·'


# --- real results ---
flutter, f_errors = read_flutter(sys.argv[1])
jest, j_errors = read_jest(sys.argv[2])
assert not f_errors and not j_errors, f_errors + j_errors
summary = {}
for item in flutter + jest:
    name, passed = item[0], item[1]
    if len(item) > 2 and item[2]:
        continue  # skipped: a registered gap, not a result
    for i in ids_in(name):
        if i in record:
            ok, bad = summary.get(i, (0, 0))
            summary[i] = (ok + passed, bad + (not passed))

problems = []
for i, row in record.items():
    s = row['status']
    ok, bad = summary.get(i, (0, 0))
    if row['tested'] != (i in summary):
        problems.append(f'{i}: tested is {row["tested"]}, but results {"exist" if i in summary else "do not"}')
    if s == PS and bad:
        problems.append(f'{i}: PASS with {bad} failing tests')
    if s == FA and not bad:
        problems.append(f'{i}: FAIL with no failing test')
    if s in (NB, PL) and ok:
        problems.append(f'{i}: {s} with {ok} passing tests')
    if i in finished and s != PS:
        problems.append(f'{i}: finished in CI but recorded as {s}')
assert not problems, '\n'.join(problems)

total_ok = sum(v[0] for v in summary.values())
total_bad = sum(v[1] for v in summary.values())
overall = Counter(r['status'] for r in record.values())
sha = subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], capture_output=True, text=True).stdout.strip()

SEC = OrderedDict([
    ('A', 'Event setup'), ('L', 'Login'), ('B', 'Registration'), ('C', 'Fees and payments'),
    ('D', 'Sponsorships'), ('H', 'Committee'), ('V', 'Volunteers'), ('J', 'Event days'),
    ('K', 'After the event'), ('X', 'Tool integration'), ('S', 'Scale'), ('R', 'Safety'),
    ('Z', 'Privacy'), ('O', 'Operations'), ('U', 'Accessibility'), ('N', 'Notifications'),
])
counts = {k: Counter(r['status'] for i, r in record.items() if i[0] == k) for k in SEC}


def cell(s):
    return s.replace('|', '\\|').replace('\n', ' ')


o = []
w = o.append
w('# Derod Gaam Convention 2027: Test Report (v3)\n')
w(f'**Test spec:** [`CREWPOINT_CONVENTION_TEST_v3.md`](CREWPOINT_CONVENTION_TEST_v3.md) · **Run:** {RUN_DATE}, at the end of Stage 1, on `main` at `{sha}` · **First run:** Nov 3, 2026\n')
w(f'**Result: Stage 1, the platform foundation, is complete, but CrewPoint cannot run this event yet.** Registration and payments arrive in Stage 2, email and Gujarati in Stage 3, and event-day check-in in Stage 5. Of {len(titles)} scenarios, {overall[PS]} pass, {overall[PA]} are partial, {overall[FA]} fails, {overall[NB]} are not built, {overall[PL]} are platform requirements for later stages, and {overall[NR]} need a person or outside access. On Nov 3, 2 passed.\n')
w('**What Stage 1 changed for this event:**\n')
w('- **Permissions:** twelve preset roles plus custom ones, checked in the rules and on the server, with money kept from everyone who should not see it (H-01, H-05, H-06, H-07).')
w('- **People:** attendees and groups, children included, with custom fields, private details and age bands, a roster import with re-import and cancellations, and accounts linked to their own records by verified email (X-01…X-06, Z-01, PA-05).')
w('- **Schedule:** sessions and venues, attendance policies and a personal agenda that works offline (A-01, A-02, A-05, J-05, J-06).')
w('- **Counts:** headcounts and per-session counts on the server, with CSV export and frozen counts for suppliers (B-04, B-05, B-10, B-14).')
w('- **Scale and safety net:** no 50-member cap, long-lived invites, paged chat, measured load at 400 and 2,000 people, rehearsed restores, crash reporting, backend error alerts and an outside billing check (S-01, S-02, S-07, S-08, O-01…O-03).\n')
w('**Most urgent now:**\n')
w('1. **Get the privacy policy approved by a lawyer.** Stage 1 runs only on dev until then, and prod still has the code from before Stage 1 (Req 39).')
w('2. **Choose how registration opens.** Building it is Stage 2. A bought tool, brought in through the roster import, is the stopgap if registration must open first (L6).')
w('3. **Finish the live check on dev:** setting up each event type from its template on a real phone and on web (#95).')
w('4. **Set up an email domain** before Stage 3 needs it (O-04).\n')
w('**How far to trust this:**\n')
w(f'- {total_ok + total_bad} acceptance tests ran against the real app and backend code: {total_ok} passed and {total_bad} failed. A failure is a planned gap for a later stage unless the scenario is on the finished list, which CI protects.')
w('- The tests run on emulators with mocked push, and no message was sent. Live checks were made on dev, with throwaway data: the Stage 1 rollout, Google and Apple sign-in and linking (L-01, L-02), crash reporting on iOS, Android and web (O-02), both alert emails reaching both inboxes (O-01, O-02), and a restore (O-03).')
w('- Timings come from a Mac and local emulators ([load baselines](load-baselines.md)). Expect phones to be slower, and real delivery times are unmeasured.')
w('- NOT BUILT comes from reading and searching the code. Those scenarios are registered as skipped tests, with the reason.\n')
w('## 1. Inventory\n')
w('| Area | Today |\n|---|---|')
for a, b in [
    ('Stack', 'Flutter 3.47 (iOS, Android, web), Firebase Auth, Firestore, Storage, Messaging, 52 Cloud Functions on Node 22, Drift on mobile'),
    ('Templates', 'Blank, Party, Wedding, Cricket tournament, Golf outing and Convention, plus templates saved from an event. The same code serves every type'),
    ('Data models', 'Events with modules, labels, statuses and time zones; roles, crews and member documents; attendees and groups with custom fields and private details; sessions and venues; counts and frozen counts; tasks, expenses and chat. **No** registration, payment, pass, sponsor, vendor, shift or check-in model'),
    ('Auth', 'Google, Apple, email and password, with accounts linked to attendee records by verified email. **No** phone or email one-time code'),
    ('Roles', 'Twelve presets and custom roles from a permission catalogue, co-owners and ownership transfer, crews, and own-group access for a group\'s adults'),
    ('Payments', 'None processed. Settle-up records payments between members and opens Venmo or Cash App links; it cannot collect fees'),
    ('Notifications', 'Push only, with per-category preferences, event mute and dead-token cleanup, reading recipients in batches up to 5,000. Quiet hours still **drop** messages. No email, SMS, scheduled messages, segments or delivery log'),
    ('Scheduled jobs', 'Task reminders, the digest, event status changes, counts every 5 minutes and import cleanup'),
    ('Offline', 'Schedule, agenda, tasks and chat read from the device copy, showing when they were last updated. Firestore queues writes, but nothing covers check-in rules or conflicts'),
    ('Languages', 'English only. Labels are renameable per event, and the string layer is ready for Gujarati'),
    ('Limits', 'An optional member limit per event; invites last until the event starts or up to 400 days; the expense PDF stops at 200 expenses'),
    ('Operations', 'Daily backups with a rehearsed restore, point-in-time recovery, uptime and backend error alerts, an hourly billing check outside Google Cloud, and crash reporting (dev)'),
    ('Tests', '1,574 Flutter tests and 1,265 backend tests pass, plus the acceptance suites. Every preset role is checked against every restricted path'),
]:
    w(f'| {a} | {b} |')
w('\n## 2. Scorecard\n')
w('PLATFORM marks what the first run expected a bought tool to do. CrewPoint now builds these itself, in the stage shown in section 3 (L6).\n')
w('| Section | ' + ' | '.join(ST) + ' | Total |\n|---|' + '---:|' * (len(ST) + 1))
for k, name in SEC.items():
    c = counts[k]
    w(f'| {k}: {name} | ' + ' | '.join(str(c[s]) if c[s] else '·' for s in ST) + f' | {sum(c.values())} |')
w('| **Total** | ' + ' | '.join(f'**{overall[s]}**' for s in ST) + f' | **{len(titles)}** |')
w('\n### 2.1 Cost (S-08)\n')
w('Measured on emulators rather than modelled: a count run reads about 1.3 documents per person, a roster page 51, and a push 2 per recipient. Chat now loads 50 messages at a time and stores only what changed, which removed the first run\'s worst case of 10 million reads a day. Costs and the monthly estimate are in [load baselines](load-baselines.md).\n')
w('## 3. Results\n')
w('| ID | Scenario | Status | Evidence | Gap | Next | Needed by |\n|---|---|---|---|---|---|---|')
for i, t in titles.items():
    row = record[i]
    if i in summary:
        ok, bad = summary[i]
        ev = f'`{i}` tests ({ok} pass' + (f', {bad} fail)' if bad else ')')
    elif row['status'] == PS:
        ev = 'Manual, recorded'
    else:
        ev = '·'
    t2 = t if len(t) < 90 else t[:87].rsplit(' ', 1)[0] + '…'
    w(f'| {i} | {cell(t2)} | {row["status"]} | {cell(ev)} | {cell(row["gap"])} | {stage(i, row)} | {priority(i)} |')
w('\n## 4. Priorities by the real calendar\n')
w('**P0: before announcing registration (Nov–Dec 2026)**\n')
w('- **Legal:** lawyer approval of the privacy policy, then Stage 1 to prod (Z-01, Z-04), the nonprofit\'s legal name, EIN and receipt wording (D-15, Z-06), and the waiver (Z-03).')
w('- **Registration route:** Stage 2, or a bought tool brought in through the roster import (L6). Either way, the fee rules come first: hybrid family fee (C-01), per-person meal choices and arrival times (B-01, B-03).')
w('- **Email domain** (O-04).\n')
w('**P1: sponsorship and hotel push (Jan–Jun 2027)**\n')
w('- Stage 2: registration, payments, receipts, contributions and one-time code sign-in (B, C, D, L-03…L-07).')
w('- Stage 3: email, scheduled messages that wait out quiet hours, Gujarati and Unicode PDFs (N, J-09, A-03, U-03).')
w('- App store approval (O-05), and accessibility on every screen (U-01…U-04).\n')
w('**P2: final week and event days (Jul 2027)**\n')
w('- Stage 5: passes, check-in, offline writes, volunteers, live updates and safety (J, V, R, S-05, S-06).')
w('- Rehearse at scale (S-03, S-04) before the Jul 9 release freeze (O-06), and name who is on call (O-08).\n')
w('**P3: after the event**\n')
w('- Stage 6: reconciliation, vendors, budget lines, full export and data retention (K, H-03, H-04, Z-07).\n')
w('## 5. Top gaps\n')
for n, (title, body) in enumerate([
    ('No registration or payments', 'Families cannot register or pay in CrewPoint until Stage 2. Until then, a bought tool and the roster import, which is built and tested, are the route (B, C, D, X-04).'),
    ('Prod is still on the code from before Stage 1', 'Every Stage 1 change waits for the lawyer\'s approval of the privacy policy, and runs only on dev (Req 39).'),
    ('No email', 'Web-only families depend on it. It needs an authenticated domain, unsubscribe and bounce handling (N, O-04, Z-05). Stage 3.'),
    ('No Gujarati', 'Strings, a language setting, translated templates and a PDF font that supports Gujarati, with a human translator (A-03, J-09, U-03, N-21). Stage 3.'),
    ('Messages are dropped, not delayed, and mute blocks urgent alerts', 'Quiet hours drop a message instead of sending it at 7:00am, and a muted event blocks a lost-child alert (N-10, N-14). Stage 3\'s scheduled queue must fix both.'),
    ('No event-day flow', 'Passes, a scanner, the limited name search, offline writes with a clear conflict rule, volunteers and live updates (J, V). This is the largest single build, in Stage 5.'),
    ('No safety features', 'Incident reports, medical and allergy flags, and lost-child handling (R). Stage 5.'),
    ('The expense PDF stops at 200 expenses', 'The CSV is complete, but the PDF is not, and there is no full export (K-03). Stage 6.'),
], 1):
    w(f'{n}. **{title}.** {body}')
w('\n## 6. Testability gaps\n')
for g in [
    '**No clock seam in the push and scheduled jobs.** `sendCategorizedPush`, `onTaskDueScheduled` and `onDigestSummary` call `new Date()` directly, so the N-10 test fakes `Date` in Jest. Stage 3\'s scheduled messages should take a clock, as counts already do.',
    '**No email or SMS transport to mock.** N-00 can only prove safety for push.',
    '**Pushes have no recipient-level result.** `sendCategorizedPush` returns only counts, so recipient assertions inspect the mock.',
    '**Real delivery.** APNs and FCM delivery need real devices.',
    '**Not checked: store listings and the venue network** (O-05, O-07).',
]:
    w(f'- {g}')
w('\n## 7. Assumptions\n')
w('| Assumption | What the app does now | Recommendation |\n|---|---|---|')
for a, b, c in [
    ('A 1-adult family pays $300', 'No fee logic. Stage 2', 'Confirm'),
    ('Age is computed on Jul 16, 2027', 'Age bands come from the private birth date, on the event\'s first day', 'Keep'),
    ('Registration is built, with a bought tool as a stopgap (L6)', 'The roster import is ready for a tool\'s export', 'Decide by December'),
    ('Sign-in with Google, then email code, is one account (L-06)', 'No email code yet. Stage 2', 'Keep'),
    ('Bhajan Prasad accepts any amount before one is set', 'Not built', 'Keep'),
    ('Pledged-but-unpaid sponsors appear on the thank-you list', 'Not built', 'Confirm: consider listing only after receipt'),
    ('F5\'s pre-event nights get the group rate', 'Outside the app', 'Ask the hotel'),
    ('Volunteers can search by family name if QR fails', 'Not built. Stage 5', 'Keep, with logging'),
    ('Duplicate who already paid goes to finance', 'Not built', 'Keep'),
    ('Walk-ins past capacity need admin override', 'Capacity is a setting, compared with the counts', 'Confirm the real hall limit with the hotel'),
    ('Paid families are not re-billed after a fee change', 'Not built', 'Keep'),
    ('Pay-at-check-in families get no unpaid reminder', 'Not built', 'Keep, with one reminder in N-07'),
    ('Web-only users get no session reminders', 'No email at all', 'Keep; email every 15 minutes would be noise'),
    ('Quiet hours are 9:00pm–7:00am, deferred not dropped', 'User-set window; **drops** messages', 'Keep; requires a build'),
    ('Event time applies to quiet hours Jul 16–19', 'Events have a time zone, but quiet hours use the profile\'s', 'Keep; requires a build'),
    ('Pledge reminders stop at event start', 'Not built', 'Confirm'),
    ('Event-day messages reach each family member with a login', 'Not built', 'Keep'),
    ('Shift reminders the day before at 6:00pm, and 30 minutes before', 'Not built', 'Keep'),
    ('Opted-out families still get receipts and live changes', 'Per-category opt-out exists for push', 'Keep, and have counsel check it against email rules'),
    ('Lost-child alerts re-send after 2 minutes with no acknowledgement', 'Not built', 'Confirm with whoever runs safety'),
]:
    w(f'| {a} | {b} | {c} |')
w('\n**Owner input still needed:** nonprofit legal name and EIN, refund policy (C-13), who absorbs card fees (C-20), waiver text (Z-03), whether to adopt SMS for emergencies (N-14).\n')
w('## How to re-run\n')
w('Keep each scenario\'s status and gap in `test_acceptance/fixtures/scenarios.json` as work lands, then:\n')
w('```bash\nflutter test test_acceptance/ --reporter json > flutter.json\n(cd functions && firebase emulators:exec --project demo-crewpoint --only firestore,auth \\\n  "npx jest --runInBand --config jest.acceptance.config.js --json --outputFile=../jest.json")\npython3 test_acceptance/generate_report.py flutter.json jest.json\n```')
open(OUT, 'w', encoding='utf-8').write('\n'.join(o) + '\n')
print(f'wrote {OUT}: {dict(overall)}; {total_ok} passed, {total_bad} failed')
