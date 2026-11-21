---
type: Interview Ledger
parent: stage-2a-registration-spec.md
---

## Records

### L1

Status: current

Question: Should Stage 2 be one Spec, or three Specs built in order?

Recommended Answer:
- Three Specs, each with its own interview, in order: 2A Registration, 2B Collections, 2C Contributions.
- Decisions D5 (business model), D6 (payment provider) and D7's refund and tax defaults belong to 2B; waivers (D7, D10) come up in 2A.
- Stage 2's exit criterion is checked after 2C.

Answer: Yes, break it up.

Decision: This Spec covers 2A Registration only. Money (charges, payments, refunds, receipts) is 2B; contributions and sponsorships are 2C. The convention test review added a raffle slice after 2B (see L2).

### L2

Status: current

Question: May the owner's rewritten convention test become a merged v4, so nothing is lost and no ID changes meaning?

Answer: Yes.

Decision: `docs/testing/CREWPOINT_CONVENTION_TEST_v4.md` (PR #232) is the convention's acceptance test. Scenario IDs are permanent. The platform plan assigns registration choices (W-01), waivers at sign-up (W-05) and cancelled-everywhere (B-16) to Stage 2; budget lines and the sponsorship list (BG), raffle (RF) and in-kind (D-16) also go to Stage 2 but belong to later slices.

### L3

Status: current

Question: When does the convention need registration open?

Answer: Real registration opens in February 2027, inside CrewPoint. Dates in the test are test values. Before then, the complete app should be tested on dev and on smaller real events of other types. The convention is the first large real-world pilot; the owner is involved and it doubles as promotion.

Decision: 2A (and the rest of Stage 2) must be built and tested on dev by about late January 2027. No interim stopgap (interest forms, bought tool) is planned for December.

### L4

Status: current

Question: What is a Registration in CrewPoint, and how does it relate to groups and participants?

Recommended Answer:
- A Registration is one group's own sign-up: contact, status, submitted and changed times, form answers. It owns exactly one Group; its people are Participants immediately.
- Someone alone is a group of one; group words are hidden when the form asks for one person.
- RSVP, entry and team entry are labels for a Registration with a short form, not separate code.
- Statuses: `draft` (not counted, contact only), `submitted` (counted, default), `waitlisted` (not counted), `cancelled` (kept, excluded everywhere), `pending` (only when "Review sign-ups before they count" is on; off by default).
- People added by hand or import have no registration; the organizer can send a "complete your registration" link that attaches one.
- No money in 2A; the fee estimate comes with 2B.

Answer: yes

Decision: As recommended. GLOSSARY.md's Registration entry was refined to match.

### L5

Status: current

Question: Does submitting a registration need an account?

Recommended Answer:
- Open sign-up: the public link shows the event page with no sign-in; Register asks for email or phone and a one-time sign-in (or Google/Apple), no password. That creates the account used to return, pay later and see the same group in the app.
- Personal RSVP links: no account. The link identifies the group; a guest who later signs in with the same email or phone is linked by Stage 1 linking rules.
- Each event chooses "Anyone with the link can register" or "Invited groups only"; templates set the default (open: Convention, Cricket, Golf; invited: Wedding, Party; invited with a link: Blank).
- A personal link can be turned off and only opens its one group.

Answer: Yes. The event setup and organizer decide; team entries for cricket and players for golf must work.

Decision: Account requirement is an event setting with template defaults. Cricket team entries (a captain registers a team with its players) and golf entries (a player alone or a foursome) are registrations of a group.

### L6

Status: current

Question: What is a registration form made of?

Recommended Answer:
- Questions are the event's custom fields, grouped into named, ordered sections. No separate form-designer screen.
- Built-in blocks the organizer switches on: People (name, birth date or age only, category worked out), Stay (arrival and departure per person), Session choices (by-sign-up sessions per person; two sessions at the same time make an either/or), Waivers, Contact (email and phone, private).
- Conditions, one level only: show a question only to a category, or only when another answer equals a value.
- A rich-text after-registration note seen only by registered groups (hotel link and code), replaced after a set date.
- Not in 2A: prices on questions or add-ons (2B), file uploads.

Answer: Yes. The convention has always used Google Forms, and mailed paper forms before that.

Decision: As recommended, with a usability bar: registering must feel at least as easy as a Google Form (one link, no app, save as you go, a review page, a confirmation).

### L7

Status: current

Question: How do waivers and consents work?

Recommended Answer:
- A waiver is organizer-written, versioned text with a title, an "applies to" (everyone, a category, or people signed up for a session) and whether it is required to register.
- Acceptance is per person and immutable: who accepted (contact, or guardian for a minor), when, which version, for self or as guardian. A text change makes a new version; existing acceptances show as an earlier version and the organizer chooses whether to ask again.
- Photo and video consent is a built-in yes/no per person, default unanswered; guardians answer for children; the photographer role sees only who said no.
- Email and SMS consent for announcements is asked once, separate from essential messages.
- A required-to-register waiver blocks submitting; otherwise the person goes on a "missing waiver" list (boarding checks are Stage 5).
- Waiver text is owner input; the fixture uses placeholder text.

Answer: yes

Decision: As recommended.

### L8

Status: current

Question: For email, is a sign-in link acceptable instead of a typed code?

Recommended Answer:
- Email uses Firebase's email sign-in link with CrewPoint's own wording; a different device asks for the email once. L-04 becomes "email sign-in link".
- Phone uses Firebase's SMS code, with SMS regions limited to the US, Canada and the UK; organizers can add countries later.
- Google and Apple stay; the same email by any method is one account (L-06).
- Typed email codes can come in Stage 3 if the link confuses people; U-05 is the real test.

Answer: yes

Decision: As recommended. Rejected alternative: bringing our own email codes into 2A.

### L9

Status: current

Question: How do capacity, the waitlist, the deadline and later edits behave?

Recommended Answer:
- Capacity counts people (submitted and pending), using the event's existing capacity.
- Over capacity, the whole group is waitlisted with its position; a group is never split.
- A freed place is offered to the first waitlisted group that fits, for 72 hours (a setting), then to the next.
- The deadline is a date and time in the event's zone. After it the link says "Registration is closed" with the organizer's contact line; families can still view their registration, accept waivers and update contact details; other changes go through the committee.
- Before the deadline the contact and invited adults edit freely; every change is logged (who, when, field, before, after) and visible to `registrations.manage`.
- `registrations.manage` can add, edit or cancel at any time; going over capacity needs a confirmed warning.
- Not in 2A: waitlist offers with payment deadlines (2B).

Answer: looks good

Decision: As recommended.

### L10

Status: current

Question: How are duplicates found and merged?

Recommended Answer:
- Checked on submit, quietly: a person matches when name (ignoring case, spacing and accents) and birth date match someone in the event, or name matches and the contact email or phone matches. The registration still goes in, flagged; the submitter never sees the other family.
- Never merged automatically. `registrations.manage` reviews a "Possible duplicates" list side by side and chooses the group to keep and which people are the same.
- Merging moves unmatched people into the kept group, keeps matched people once (filling blanks), marks the other registration cancelled (merged into the kept one), updates counts, logs it, and removes the duplicate contact's access unless they are an adult in the kept group.
- "Not a duplicate" clears the flag for that pair for good.
- A duplicate who already paid goes on a finance list in 2B; in 2A the merge only notes it.

Answer: yes

Decision: As recommended.

### L11

Status: current

Question: Should 2A include basic transactional email?

Recommended Answer:
- Yes: an email provider on an authenticated sending domain (SPF, DKIM, DMARC), a server-written outbox, a sending function and a delivery log.
- Sent at once only: registration confirmation (who and what, with a link back), family invite, waitlist place offer, the RSVP reminder and closing reminder, and waiver missing. English and Gujarati (see L13).
- Tests use a mock transport.
- Stage 3 keeps scheduled reminders and rules, audiences, the rest of Gujarati, history screens, de-duplication and push-to-email fallback.
- The provider is chosen in the Spec (leaning Resend or Postmark); the sending domain is owner input.

Answer: yes, put basic email in 2A

Decision: Basic transactional email is part of 2A. Rejected alternative: running Stage 3 email before February instead.

### L12

Status: current

Question: How does the contact invite family members, and what can they do?

Recommended Answer:
- The contact invites by email or phone from their registration; the invitee signs in and becomes a linked adult of that group.
- A linked adult can do everything the contact can on that group, including waivers for themselves and the children, and sees no other family.
- Only adults (18+) in the group can be invited; an invite works only for the email or phone it was sent to; children never get accounts this way.
- The contact can remove a linked adult and hand the contact role to another; a group always has one contact.
- Invites expire after 14 days and can be resent.
- Paying and pledging by family members are decided in 2B and 2C.

Answer: yes

Decision: As recommended.

### L13

Status: current

Question: Should Gujarati for the registration flow come in 2A?

Recommended Answer:
- Yes, for the registration path: the ARB pipeline behind `context.strings`, a per-person language choice on the event page before sign-in (remembered on the account), Gujarati for the event page, sign-in, form, review, confirmation and "my registration", the 2A emails, and the event's own words in both languages (organizers enter the Gujarati), plus a Gujarati-capable font on web and in PDFs.
- The rest of the app stays for Stage 3.
- A human translator checks the Gujarati before February, spelling દેરોદ, never ડેરોડ; a test fails on ડેરોડ.

Answer: yes, let's try it

Decision: As recommended. Who translates is still open.

### L14

Status: current

Question: Does registration run inside the existing Flutter web app, and how fast must it be?

Recommended Answer:
- Same Flutter app, new public routes: `/e/:eventSlug` (event page and open sign-up), `/r/:token` (personal RSVP link), `/e/:eventSlug/registration` ("my registration").
- On a mid-range phone with throttled 4G, the event page shows content within 4 s and the form is usable within 6 s, measured with Chrome throttling and recorded. If Flutter misses it, a light HTML loading screen may show the event's title, dates and place first.
- Browsers: iOS Safari 16+, Chrome on Android, desktop Chrome, Safari, Edge, Firefox.
- Same quality floor as the app: 200% text, screen-reader labels, 48 px tap targets, dark mode.
- Organizers choose the slug; a flyer QR opens the same page.

Answer: yes, same app

Decision: As recommended. Rejected alternative: a separate plain web form.

### L15

Status: current

Question: For an RSVP-style event, how do yes, no, maybe and plus-ones work?

Recommended Answer:
- The personal link lists the group's invited guests by name; each is Yes, No or Maybe, with any questions; one person may answer for the party.
- Yes counts like a submitted registration; Maybe is shown separately and is not in meal or session counts; No stays on the list as declined and is excluded elsewhere; answers can change until the deadline.
- The organizer sets how many extra guests each party may bring (default 0); extras are added by name or as "Guest of <name>" and count like invited guests.
- In 2A a manual "Remind those who haven't answered" sends email; scheduled reminders are Stage 3.

Answer: yes

Decision: As recommended.

### L16

Status: current

Question: What does the organizer see and use to manage registrations?

Recommended Answer:
- A Registration entry on the event home for `registrations.manage`: counts by status, capacity used, deadline, the public link and QR (copy, share), and shortcuts.
- Lists are filters on People: by status, Possible duplicates, Missing waiver, Not answered (RSVP), and the waitlist in queue order with "Offer a place"; rows show status as a tag.
- A group's detail adds registration status and history, contact and linked adults, waiver acceptances per person, and actions: approve (review on), waitlist, cancel, reinstate, merge, resend confirmation, send a "complete your registration" link.
- Setup is in Event settings → Registration: open or invited, capacity, deadline, review, plus-ones, sections and field order, built-in blocks, waivers, after-registration note, slug. Fields keep their Fields screen.
- The roster export adds status, contact, submitted date and waivers.

Answer: yes

Decision: As recommended.

### L17

Status: current

Question: Does registering make someone a member of the event?

Recommended Answer:
- Yes: the contact and every linked adult become members with the event's "role for people who register" (Participant by default; templates may pick another, such as Player).
- Existing members keep their roles and gain the registration role.
- Cancelling or being merged away removes the registration role; they stay a member only if they hold another role.
- Registration opens only on a published or live event; on a draft the link says "Not open yet".
- Personal RSVP links create no member until the guest signs in and is linked. Children never become members.

Answer: yes

Decision: As recommended.

### L18

Status: current

Question: What happens when the connection drops while a family fills in or submits the form?

Recommended Answer:
- Answers are kept on the device as they are typed (browser storage on web) and cleared once submitted.
- The draft is saved to the server when connected, after a few seconds idle and when moving between sections; "Saved" or "Not saved yet: no connection" shows at the top.
- Submitting needs a connection; offline, Submit explains that answers are kept and to submit when back online. A submission is never queued offline.
- A double tap or a retry after a timeout creates one registration.
- If the event fills while they type, submitting says they are on the waitlist and their position.

Answer: yes

Decision: As recommended.

### L19

Status: current

Question: Defaults stated before the checkpoint: invite controls, permissions and testing.

Recommended Answer:
- Several member invite links per event, each with its own role, expiry and optional single use (GAP-ANY-02, GAP-ANY-03).
- `registrations.manage` covers seeing and handling registrations.
- Email, SMS and sign-in sit behind fakes so tests never send anything; rules and functions are tested on the emulators; robot journeys cover a family registering, an RSVP and a merge.

Answer: Accepted without change (the owner continued the interview).

Decision: As recommended.

### L20

Status: current

Question: (Refinement, Finding 1) How do registration status and RSVP answers reach counts, meals, sessions, exports and capacity, and can organizers see who hasn't finished?

Recommended Answer:
- Registration status, and the RSVP answer for RSVP events, are mirrored onto the group and its people.
- Confirmed counts are submitted registrations, RSVP Yes and organizer-added people; meals, exports, sessions, agendas and capacity use them.
- Not-yet-confirmed counts sit alongside, in groups and people: drafts, pending, waitlisted, Maybe and not answered. They show on the Registration summary, linking to follow-up lists, and as a line on Counts.
- Pending counts toward capacity but not meals. Cancelled and RSVP No count nowhere.

Answer: "could we show count of both complete registrations and pending so people in charge can follow up?" then "yes, keep that"

Decision: As recommended, with not-yet-confirmed counts shown for follow-up.

### L21

Status: current

Question: (Refinement, Finding 2) How are the public event page and personal RSVP links kept safe without sign-in?

Recommended Answer:
- The event page and RSVP-link callables accept visitors who aren't signed in and return only what each needs.
- Firebase App Check is required on them.
- Rate limits: about 60 event-page opens a minute per address and about 30 RSVP saves an hour per link; beyond that, "Please try again in a few minutes".
- Link tokens are random with at least 128 bits; a wrong or turned-off token shows "This invitation is no longer valid", revealing nothing about the event.
- Events are reached only by slug; event IDs are never exposed; draft events show "Not open yet" without details.
- Tests cover a missing, wrong and turned-off token, and the rate limit.

Answer: yes

Decision: As recommended.

### L22

Status: current

Question: (Refinement, Finding 3) How do personal RSVP links reach guests?

Recommended Answer:
- `registrations.manage` creates a link for one group, or "Create links for all invited groups"; existing links are kept.
- An invitation email (event name, date, a button to the link) goes to one group or to all with an email not yet sent, through the outbox.
- Each group offers copy, the share sheet and a QR code.
- A CSV export of group name, contact and link.
- Each invited group shows Not sent, Sent, Opened or Answered, filterable on the Registration summary.
- Sending SMS from CrewPoint is out of scope for 2A.

Answer: yes

Decision: As recommended.

### L23

Status: current

Question: (Refinement, Finding 4) How does the router treat the public routes?

Recommended Answer:
- `/e/:eventSlug` and `/r/:token` are top-level, need no sign-in and skip onboarding.
- `/e/:eventSlug/registration` asks for sign-in only when the event requires an account, using the light sign-in, then returns to the form.
- `?from=` also accepts `/e/` and `/r/` paths; anything else is still refused.
- Onboarding shows the next time the person opens the app normally.
- Signed-in users open these links directly.
- Router tests for each route signed out, new and signed in, and a refused `from=`.

Answer: yes

Decision: As recommended.

### L24

Status: current

Question: (Refinement, Finding 5) How does phone sign-in link people, and how are phone invites delivered without SMS sending?

Recommended Answer:
- Phone numbers are stored in E.164 in the contact's private details from the form, imports and organizer edits.
- `linkMyParticipants` also matches a verified phone number, under the same Stage 1 rules.
- `participantKeys` also keeps an HMAC key of the phone.
- Inviting an adult by phone creates the invite link, which the contact sends from their own phone through the share sheet; signing in with that number's code accepts it. Email invites still send email.
- Sign-in codes are still sent by Firebase, limited to the US, Canada and the UK.
- Shared linking cases add phone, mixed and badly formatted numbers.

Answer: yes

Decision: As recommended.

### L25

Status: current

Question: (Refinement, Finding 6) How do email sign-in links work on mobile now that Firebase Dynamic Links are gone?

Recommended Answer:
- Links open the web app on the flavor's Hosting domain, finish sign-in and return to where the person started.
- App Links and Universal Links are set up on that domain per flavor, so installed apps open them.
- On another device: "Confirm your email to finish signing in", with the email field and Continue; a different address shows "This link was sent to a different email".
- An expired or used link shows "This sign-in link has expired or was already used" with Send a new link.
- Phone code and Google or Apple stay on the same screen.
- Manual checks on iPhone and Android, with and without the app, and on a second device.

Answer: yes

Decision: As recommended.

### L26

Status: current

Question: (Refinement, Finding 7) How does the server enforce capacity safely?

Recommended Answer:
- `registrationTally/current` holds places used, the next waitlist number and open offers.
- Every capacity-changing action updates it in the same transaction.
- The public page receives only whether places remain.
- Adding people to a submitted group with no room is refused with a message to contact the organizer; organizers can override after the warning.
- Lowering capacity below places used removes nobody and shows how far over the event is.
- A nightly recount corrects any drift and logs it.
- An emulator test races two submits for the last places.

Answer: yes

Decision: As recommended.

### L27

Status: current

Question: (Refinement, Finding 8) Who reads photo consent, and how is it kept apart from other private details?

Recommended Answer:
- New permission `photoConsent.read`; Owner, Co-owner and Admin hold it, and organizers can grant it. The Convention template adds a "Photographer" role with only it and basic read.
- The server keeps `photoConsent/current` (server-written, readable only with `photoConsent.read`): each person's name, group name and age band, marked No or Not answered.
- A "Photo consent" screen with "Said no" and "Not answered yet" sections, name search and a note to treat Not answered as no.
- The answer stays in private details; Counts show Yes, No and Not answered totals.
- Rules, role matrix and list-update tests.

Answer: yes

Decision: As recommended.

### L28

Status: current

Question: (Refinement, Finding 9) How is the speed target measured, and is the HTML first view required?

Recommended Answer:
- Chrome DevTools "Fast 4G" with 4x CPU slowdown, first visit with empty cache, release web build on the dev Hosting site, median of 5 runs.
- "Content" means the title, dates and place are visible; "usable" means Register can be tapped and the first field typed in.
- One real mid-range Android check over mobile data.
- `/e/:eventSlug` returns a small server-rendered page (title, dates, place, Register, link-preview tags with the cover photo) while the app loads behind it, built from the start.
- Results recorded in `docs/testing/load-baselines.md`; a manual check, not a CI gate.
- If the form misses 6 seconds, the owner decides the remedy.

Answer: yes

Decision: As recommended.

### L29

Status: current

Question: (Refinement, Finding 10) How are waitlist offers held, accepted, declined and expired?

Recommended Answer:
- An offer holds its places in the tally; several offers can be open at once.
- The offer email's "Accept my place" opens "my registration", which shows "A place is available for your group until {date and time}" with Accept and No thanks.
- No thanks, after a confirm, leaves the waitlist and offers the places onward at once.
- A scheduled function every 15 minutes expires late offers, moves the places on and emails "Your offer has expired"; the group goes to the end of the queue.
- A skipped larger group keeps its position.
- Organizers see open offers with expiry and can withdraw or extend them.
- No automatic offers after the deadline.
- Allocator cases, injected clock, and an emulator test of acceptance racing expiry.

Answer: yes

Decision: As recommended.

### L30

Status: current

Question: (Refinement, Finding 11) Which Test Seams do drafts, incoming links, connectivity, sharing and App Check need?

Recommended Answer:
- `IDraftStore` (save, load, clear per event and person; memory fake).
- `IIncomingLinkSource` (stream of opened links, including the launch link; fake pushes links).
- Existing `IConnectivity` for Submit and the saved indicator.
- `IShareSheet` (share text and a link; fake records shares).
- App Check started only in `main`; tests and emulator runs skip it.
- New packages carry their exact resolved version.

Answer: yes

Decision: As recommended.

### L31

Status: current

Question: (Refinement, Finding 12) Gujarati in PDFs, font loading, and checking Gujarati spelling before release.

Recommended Answer:
- Gujarati covers web and app in 2A; Gujarati PDFs move to 2B with receipts.
- The Gujarati font downloads only when Gujarati is chosen or is the event's default language.
- An approved spelling list (`docs/i18n/gujarati-terms.md` with a data file) of English term, approved Gujarati and known wrong spellings, starting with the registration path, the glossary terms and the convention's names.
- CI fails on a known wrong spelling in ARB, templates, labels, email templates, seed data or fixtures, and on a listed term spelled another way.
- A release checklist (`docs/release/registration-release-checklist.md`) with a native-speaker sign-off from a generated sheet of new and changed Gujarati strings beside their English; corrections join the list. English strings get cspell in CI. The checklist gathers the other manual checks.

Answer: "yes, possible to get a language spelling list to make sure all is correctly spelled and have a it in checklist before releasing?" then "me for the Gujarati review"

Decision: As recommended; the owner is the Gujarati reviewer.

### L32

Status: current

Question: (Refinement, Finding 13) Which new terms join `GLOSSARY.md`?

Recommended Answer:
- Waiver, Waitlist, Personal link, Linked adult and Event page, with short definitions.
- A Waiver row in the event-type table: Waiver, Player waiver, Liability release, Usually off, Usually off.
- Registration mode stays a setting name.

Answer: yes to the glossary

Decision: As recommended.

### L33

Status: current

Question: (Refinement, Finding 14) What does the open sending-domain question block, and what do dev and staging do with email?

Recommended Answer:
- The domain question blocks only turning on real delivery; everything else is built and tested against the mock.
- Dev and staging send only to an allowed list in a server setting; others are logged "Not sent: not on the dev allowed list". Only prod sends to everyone.
- The domain is needed by early January to warm it up before February.

Answer: yes

Decision: As recommended.
