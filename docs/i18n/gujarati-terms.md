# Gujarati spelling list

The approved Gujarati spellings for CrewPoint (Spec #233 Req 59a). The data lives in [`gujarati_terms.json`](gujarati_terms.json); this page shows the same list. Edit the JSON, then update this table to match. A test fails if they differ.

**Status: draft.** Every spelling below waits for the owner's native-speaker review on the release checklist (Req 59b). Corrections from that review go into the list, so they're checked from then on.

For a reviewer, [`gujarati-review.pdf`](gujarati-review.pdf) prints this list together with every translated screen string and email, with space to tick or correct each line. Rebuild it after any change with `python3 scripts/gujarati_review_pdf.py` (needs Google Chrome).

## What CI checks

`test/i18n/gujarati_spelling_test.dart` fails when:

- **A known wrong spelling appears** anywhere checked: the Gujarati ARB file, templates, labels, email templates, seed data and fixtures. For example, ડેરોડ instead of દેરોદ (A-03).
- **A Gujarati string spells a listed term another way.** It compares each English string with its Gujarati translation (in the ARB files and the email templates):
  - `exact` terms: when the English is exactly the term, the Gujarati must be the approved spelling.
  - `word` terms: when the English contains the term as a word, the Gujarati must contain the approved spelling.

There's no reliable automatic Gujarati spell checker, so the list catches only the words on it. The native-speaker review catches everything else.

## Adding a term

Add an entry to `gujarati_terms.json` with:
- `group`: the section of this page it belongs to;
- `en`: the English term;
- `gu`: the approved Gujarati spelling;
- `wrong`: known wrong spellings;
- `match`: `exact` or `word`.

Then add the same row to the table below.

## The list

| Group | English | Approved Gujarati | Known wrong | Match |
|---|---|---|---|---|
| Actions and screens | Register | નોંધણી કરો | — | exact |
| Actions and screens | Registration | નોંધણી | — | exact |
| Actions and screens | Submit | સબમિટ કરો | — | exact |
| Actions and screens | Save | સાચવો | — | exact |
| Actions and screens | Cancel | રદ કરો | — | exact |
| Actions and screens | Edit | ફેરફાર કરો | — | exact |
| Actions and screens | Back | પાછા | — | exact |
| Actions and screens | Next | આગળ | — | exact |
| Actions and screens | Review | સમીક્ષા | — | exact |
| Actions and screens | Confirm | ખાતરી કરો | — | exact |
| Actions and screens | Sign in | સાઇન ઇન કરો | — | exact |
| Actions and screens | Language | ભાષા | — | exact |
| Statuses | Draft | ડ્રાફ્ટ | — | exact |
| Statuses | Submitted | સબમિટ થયું | — | exact |
| Statuses | Pending review | સમીક્ષા બાકી | — | exact |
| Statuses | Waitlisted | રાહ યાદીમાં | — | exact |
| Statuses | Cancelled | રદ થયું | — | exact |
| Answers | Yes | હા | — | exact |
| Answers | No | ના | — | exact |
| Answers | Maybe | કદાચ | — | exact |
| Days | Monday | સોમવાર | — | exact |
| Days | Tuesday | મંગળવાર | — | exact |
| Days | Wednesday | બુધવાર | — | exact |
| Days | Thursday | ગુરુવાર | — | exact |
| Days | Friday | શુક્રવાર | — | exact |
| Days | Saturday | શનિવાર | — | exact |
| Days | Sunday | રવિવાર | — | exact |
| Months | January | જાન્યુઆરી | — | exact |
| Months | February | ફેબ્રુઆરી | — | exact |
| Months | March | માર્ચ | — | exact |
| Months | April | એપ્રિલ | — | exact |
| Months | May | મે | — | exact |
| Months | June | જૂન | — | exact |
| Months | July | જુલાઈ | — | exact |
| Months | August | ઑગસ્ટ | — | exact |
| Months | September | સપ્ટેમ્બર | — | exact |
| Months | October | ઑક્ટોબર | — | exact |
| Months | November | નવેમ્બર | — | exact |
| Months | December | ડિસેમ્બર | — | exact |
| Glossary terms | Event | કાર્યક્રમ | — | exact |
| Glossary terms | Organizer | આયોજક | — | exact |
| Glossary terms | Member | સભ્ય | — | exact |
| Glossary terms | Participant | સહભાગી | — | exact |
| Glossary terms | Group | જૂથ | — | exact |
| Glossary terms | Category | શ્રેણી | — | exact |
| Glossary terms | Session | સત્ર | — | exact |
| Glossary terms | Crew | ટીમ | — | exact |
| Glossary terms | Custom field | પ્રશ્ન | — | exact |
| Glossary terms | Pass | પાસ | — | exact |
| Glossary terms | Charge | ચાર્જ | — | exact |
| Glossary terms | Payment | ચુકવણી | — | exact |
| Glossary terms | Contribution | યોગદાન | — | exact |
| Glossary terms | Goal | લક્ષ્ય | — | exact |
| Glossary terms | Update | અપડેટ | — | exact |
| Glossary terms | Incident | ઘટના | — | exact |
| Glossary terms | Audience | પ્રાપ્તકર્તાઓ | — | exact |
| Glossary terms | Waitlist | રાહ યાદી | — | exact |
| Glossary terms | Personal link | વ્યક્તિગત લિંક | — | exact |
| Glossary terms | Linked adult | જોડાયેલ પુખ્ત | — | exact |
| Glossary terms | Event page | કાર્યક્રમ પેજ | — | exact |
| Glossary terms | Waiver | સંમતિપત્ર | — | exact |
| Convention's own names | Derod | દેરોદ | ડેરોડ | word |
| Convention's own names | Gaam | ગામ | — | word |
