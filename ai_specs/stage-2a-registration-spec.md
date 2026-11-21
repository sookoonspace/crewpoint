---
type: Spec
title: "Stage 2A: Registration"
---

## Problem

Stage 1 lets an organizer add people and groups by hand or by import, but nobody can sign themselves up. Every real event on the platform needs that first: a convention family registering seven people with their meals and stays, a cricket captain entering a team, a golfer entering alone or as a foursome, a wedding guest answering an RSVP. Today none of these can happen in CrewPoint, so organizers fall back on Google Forms (which the Derod Gaam convention has always used) or paper, and then retype or import the results.

Real registration for the convention opens in **February 2027**, inside CrewPoint, as the platform's first large real-world pilot, after smaller real events of other types have been run (L3). Its families include people who register only on the web, in Gujarati, without help (Savita, 74). Registration therefore also needs email and Gujarati earlier than the platform plan had them (L11, L13).

## Proposed Outcome

Anyone with an event's link can open a public event page with no install, and sign up their group through a form the organizer built from the event's own fields and a few built-in blocks: the people, their stays, their session choices, waivers and contact details. Invited guests answer an RSVP from a personal link with no account. The form saves as they go, survives a lost connection, and feels at least as easy as a Google Form (L6, L18).

Each sign-up is a **Registration**: one group's own record, with a status, its answers and a change log. Its people are Participants at once, so counts, agendas and the roster work as they do today (L4). Capacity, a waitlist, a deadline and an optional review step are event settings (L9). Likely duplicates are flagged for the committee to merge (L10). Contacts invite the other adults in their group (L12). Registering makes the contact and those adults members with the event's registration role (L17). Confirmations and the few messages registration needs go out by email (L11), and the registration path works fully in Gujarati (L13). Organizers manage it all from People and a Registration summary (L16).

Money is not part of 2A: charges, payments, refunds and receipts are 2B, and contributions are 2C (L1).

## User Stories

1. As someone invited to an open event, I want to open its link on any phone with no app, see what the event is, and register my whole group, so that signing up is as easy as a Google Form.
2. As a family contact, I want my answers kept if I close the page or lose signal, and to come back and finish or change them before the deadline, so that I never retype.
3. As a family contact, I want to sign in with my email, my phone or Google or Apple, with no password, so that I can come back from any device.
4. As a family contact, I want to invite my spouse to our registration, so that either of us can keep it up to date without seeing anyone else's family.
5. As a parent, I want to accept waivers and photo consent for my children, so that they can take part.
6. As a guest at a wedding or party, I want to answer yes, no or maybe from the link the couple sent me, with no account, and add my plus-one, so that answering takes a minute.
7. As a cricket captain, I want to enter my team with its players, so that the tournament knows who is coming. As a golfer, I want to enter alone or with my foursome.
8. As a Gujarati speaker, I want the event page, sign-in, form, emails and my registration in Gujarati, so that I can register without help.
9. As an organizer, I want to build the form from my event's questions, sections and built-in blocks, and decide whether sign-up is open or by invitation, so that every event type can register its own way.
10. As an organizer, I want capacity, a waitlist and a deadline enforced for me, so that the hall is never overbooked and late changes come through the committee.
11. As a committee member managing registrations, I want to see who has registered by status, who is on the waitlist, who is missing a waiver and who might be a duplicate, and act on each, so that the list stays clean.
12. As a committee member, I want every change to a registration logged, so that I can see who changed what.
13. As someone who registered, I want a confirmation email with what I registered and a link back to it, so that I know it worked.
14. As an organizer, I want the people who register to see the event in their app with the right role, so that agendas and later messages reach them.

## Requirements

### Registration, statuses and groups

1. A **Registration** is one group's own sign-up for one event: its group, contact, status, submitted and last-changed times, form answers and change log. It owns exactly one Group. Its people are written as Participants when the registration is first saved, so counts, agendas, filters and exports use them as they use any participant. [L4]
2. Someone signing up alone is a **group of one**. When the event's form asks for one person, the form and every screen the registrant sees hide group words. [L4]
3. RSVP, entry and team entry are the template's labels for a Registration with a shorter form (`event.words`, `functions/src/shared/label_defaults.json`), not separate concepts in code. [L4, L5]
4. Statuses and their effects [L4]:
   - `draft`: saved part-way; not counted; visible only to the group's contact and linked adults.
   - `submitted`: counted everywhere; the default once sent.
   - `pending`: used only when the event's "Review sign-ups before they count" setting is on (off by default); counted for capacity, not in other counts, until approved.
   - `waitlisted`: not counted; has a queue position.
   - `cancelled`: kept with its reason (by the group, by the committee, or merged into another registration) and excluded from every count, list, drawing and reminder (B-16).
4a. The server mirrors each registration's status, and on RSVP events each guest's answer, onto its group and people, so counts, filters and exports read them without reading registrations [L20]:
   - **Confirmed:** people in `submitted` registrations, RSVP Yes, and people the organizer added by hand or by import. Meal and session counts, agendas, exports and Counts use only these.
   - **Not yet confirmed:** drafts, `pending`, `waitlisted`, RSVP Maybe and not answered, each counted in groups and in people. They show on the Registration summary, each opening its follow-up list, and as one line on Counts.
   - `pending` counts toward capacity but not toward meals or sessions. `cancelled` and RSVP No count nowhere.
5. People the organizer added by hand or by import have no registration and stay as they are. `registrations.manage` can send such a group a "complete your registration" link, which attaches a registration to the existing group and people. [L4, L16]
6. A cricket team entry is a captain registering a group with its players; a golf entry is a player alone or a foursome. Templates set the words and form for each. [L5]
7. No money in 2A: the form, review page and emails show no fee. The fee estimate and payment come with 2B. [L1, L4]

### Entry, links and sign-in

8. Each event has a **registration mode** in its settings: "Anyone with the link can register" (open) or "Invited groups only" (invited). Template defaults: open for Convention, Cricket tournament and Golf outing; invited for Wedding and Party; invited, with personal links, for Blank. [L5]
9. Public routes in the existing Flutter app [L14]:
   - `/e/:eventSlug` — the event page and, for open events, Register.
   - `/r/:token` — a personal RSVP link for one invited group.
   - `/e/:eventSlug/registration` — "my registration" for a signed-in contact or linked adult.

   These routes sit outside the signed-in shell, like `/join/:code` [L23]:
   - `/e/:eventSlug` and `/r/:token` need no sign-in and skip onboarding, for signed-out, new and signed-in visitors alike.
   - Register and `/e/:eventSlug/registration` ask for sign-in only when the event requires an account, using the light sign-in (Requirement 12), not the onboarding slides, and return straight to the form.
   - `?from=` also accepts `/e/` and `/r/` paths; any other value is still refused.
   - Someone who signed in only to register sees onboarding the next time they open the app normally, never mid-registration.
10. The **event page** needs no sign-in and shows only public information: title, dates, time zone, venues, a description, what is included, the deadline and whether places remain. It never shows other participants, counts beyond "places remain" and "full: you'll join the waitlist", or money. [L5, L21]
11. The organizer chooses the event's **slug** (letters, numbers and hyphens, unique across CrewPoint), and the event page shows a QR code of its link for flyers. [L14]
12. **Open sign-up** requires a light account: Register asks for an email or phone number, or offers Google or Apple, with no password [L5, L8]:
    - **Email:** Firebase's email sign-in link, sent with CrewPoint's own wording [L25]:
      - The link opens the web app on the flavor's Hosting domain, finishes sign-in and returns to where the person started (the form or "my registration"). App Links (Android) and Universal Links (iOS) on that domain, set up per flavor, open the installed app instead; without the app, the web opens.
      - Opened on the same device, the person is signed in at once. On another device they see "Confirm your email to finish signing in" with the email field and Continue; a different address shows "This link was sent to a different email".
      - An expired or already-used link shows "This sign-in link has expired or was already used" with **Send a new link**.
      - Phone code and Google or Apple stay offered on the same screen.
    - **Phone:** Firebase's SMS code, sent by Firebase itself. SMS is limited to the US, Canada and the UK; organizers can ask for other countries later.
    - **Google and Apple** work as today.
    - The same email by any method is one account (L-06).
13. **Personal RSVP links** need no account. Each invited group gets one link token that opens only that group. `registrations.manage` can turn a link off or replace it at any time; a turned-off link shows that the invitation is no longer valid. A guest who later signs in with a verified email or verified phone matching the group's private contact details is linked to the group under the Stage 1 account-linking rules (#78) [L5, L24]:
    - Phone numbers are stored in international (E.164) form in the contact's private details, whether they come from the form, an import or an organizer's edit.
    - `linkMyParticipants` matches a verified phone number (Firebase sets it once the SMS code is entered) as it matches a verified email: exactly one adult record links; two or more, or only children, open a link request; never a child, never by name.
    - `participantKeys` also keeps an HMAC key of the phone, so a deleted account's number links back.
13a. **Public calls are protected** [L21]:
    - The event page and personal-link callables accept visitors who aren't signed in and return only what each needs: the event's public fields, or that one group's guests and answers.
    - Firebase App Check is required on them.
    - Rate limits: about 60 event-page opens a minute from one address and about 30 RSVP saves an hour per link. Beyond that the page shows "Please try again in a few minutes".
    - Link tokens are random with at least 128 bits. A missing, wrong or turned-off token shows "This invitation is no longer valid", which says nothing about whether the event exists.
    - Events are reached only by their slug; event IDs are never exposed, and a draft event shows "Not open yet" without details.
13b. **Getting personal links to guests** [L22]:
    - `registrations.manage` creates a link for one group from its detail, or "Create links for all invited groups" from the Registration summary. Groups that already have a link keep it.
    - For groups whose contact has an email, the organizer sends the invitation email to one group or to every group not yet sent one. It carries the event name, date and a button to the link, through the outbox.
    - Each group offers copy link, the share sheet (WhatsApp, Messages and so on) and a QR code.
    - A CSV export lists group name, contact and link, for mail merges or printed cards.
    - Each invited group shows **Not sent**, **Sent**, **Opened** or **Answered**, filterable on the Registration summary.
    - CrewPoint sends no SMS in 2A; texts go from the organizer's own phone.
14. Registration is open only on a `published` or `live` event, before its deadline. On a `draft` event the link shows "Not open yet"; on an `ended` or `archived` event it shows that registration has closed. [L9, L17]
15. **Member invite links** (GAP-ANY-02, GAP-ANY-03): an event can have several invite links for joining as a member, each with its own role, expiry and an optional single-use setting, replacing today's one active invite per event. Existing invites keep working. [L19]

### The form

16. The form is built from the event's **custom fields** (#76), grouped into named, ordered **sections** set by the organizer. Fields stay the single source of questions, so counts, filters, `filterTags` and exports keep working. There is no separate form-designer screen. [L6]
17. **Built-in blocks** the organizer switches on per event [L6]:
    - **People:** each person's name and birth date, or age only when the organizer prefers; the category is worked out as today (#76).
    - **Stay:** arrival and departure per person (Stage 1's `arrivalAt`, `departureAt`).
    - **Session choices:** sessions marked "by sign-up" appear as per-person choices (Stage 1's `signUps`). Two by-sign-up sessions at the same time are shown as one either/or choice, such as the park meal or the hotel lunch (W-01).
    - **Waivers** (Requirements 26–31).
    - **Contact:** the contact's email and phone, stored privately, the phone in E.164 form (Requirement 13).
18. **Conditions, one level only:** a question can be shown only to a category (for example, kids activities only for under-18s), or only when one other answer has a given value (for example, "Confirmation number" only when "Booked a room?" is Yes). A question's condition cannot depend on a question that itself has a condition. Hidden questions are never required and their answers are not saved. [L6]
19. **After-registration note:** rich text per event that only groups with a `submitted` registration see, such as the hotel booking link and code (B-07). The organizer can set a date after which it is replaced by a second note (B-15). [L6]
20. The form ends on a **review page** listing every person and answer, with Edit beside each section, then Submit, then a **confirmation** screen and email (Requirement 52). [L6]
21. Required questions, required waivers and the People block are checked on Submit, with errors beside the field and a count at the top, using the Person form's error pattern. [L6, L7]
22. Private answers and birth dates follow the Stage 1 private-details rules: the group's contact and linked adults read and write them, and the committee sees them only with `participants.readPrivate`. A parent enters children's details; only age bands appear in reports (Z-01). [L7]

### Drafts, connection loss and submitting

23. Answers are kept on the device as they are typed (browser storage on web, device storage in the app) and cleared when the registration is submitted. Closing the page or losing signal never loses them. [L18]
24. When connected, the draft is saved to the server after a few seconds without typing and on moving between sections. "Saved" or "Not saved yet: no connection" shows at the top of the form. [L18]
25. Submitting needs a connection. Offline, Submit explains: "You're offline. Your answers are kept; submit when you're back online." A submission is never queued to send later, because capacity, the waitlist and duplicate checks run on the server at that moment. A double tap or a retry after a timeout creates exactly one registration. If the event filled while they typed, the result says they are on the waitlist and gives their position. [L18]

### Waivers and consent

26. A **waiver** is organizer-written text with a title, a version, an "applies to" (everyone, a category, or people signed up for a given session) and whether accepting it is required to register. [L7]
27. Acceptance is recorded per person and never edited: who accepted (the contact or a linked adult, as the person or as guardian for a minor), when, and which version. Only the server writes acceptance records. [L7]
28. Changing a waiver's text makes a new version. Existing acceptances show as an earlier version, and the organizer chooses whether people must accept the new version. [L7]
29. A waiver required to register blocks Submit until accepted for everyone it applies to. Any other waiver can be accepted later; until then the person appears on the "Missing waiver" list (W-05, W-06; boarding checks are Stage 5). [L7]
30. **Photo and video consent** is a built-in yes/no per person, unanswered by default; a guardian answers for children. The answer lives in the person's private details (Z-02) [L7, L27]:
    - A new permission, `photoConsent.read`, held by Owner, Co-owner and Admin by default and grantable to any role. The Convention template adds a "Photographer" role holding only it and the basic read permissions; its name lives in template data.
    - The server keeps `photoConsent/current`, readable only with `photoConsent.read`, rebuilt whenever an answer changes. It holds only each person's name, group name and age band, marked **No** or **Not answered**, never a birth date, contact detail or other answer.
    - A **Photo consent** screen, with an event hub entry only for `photoConsent.read`, shows "Said no" and "Not answered yet" sections with a name search and a note to treat "Not answered" as no.
    - Counts show Yes, No and Not answered totals like any yes/no question.
31. **Contact consent** for announcements by email and by SMS is asked once per registration, separate from receipts, confirmations and essential messages, and stored for Stage 3 to honour. [L7]

### Capacity, waitlist, deadline and edits

32. Capacity counts **people** in `submitted` and `pending` registrations, plus places held by open offers (Requirement 34), against the event's existing `capacity`. [L9, L26, L29]
32a. Capacity is enforced through one tally per event (Technical Decision 1) [L26]:
    - Every action that changes places used updates the tally in the same transaction: submit, approve, cancel, reinstate, waitlist, offer, offer accepted or expired, merge, and people added or removed.
    - Two submissions for the last places get them in turn; the one that no longer fits is waitlisted.
    - The public page learns only whether places remain, never the number.
    - Adding people to a submitted group when there is no room is refused with "There's no room to add more people. Please contact the organizer.", and the group's existing places are kept. `registrations.manage` can still go over after the warning (Requirement 37).
    - Lowering capacity below places used removes nobody; it stops new places and shows the organizer how far over the event is.
    - A nightly recount from the registrations corrects any drift and logs the correction.
33. A submission that would exceed capacity puts the whole group on the waitlist; a group is never split. The contact sees "You're on the waitlist, number N". [L9]
34. When places free up, the first waitlisted group that fits is offered them by email and push, for **72 hours** (an event setting). `registrations.manage` can also offer a place by hand [L9, L29]:
    - An offer holds its places, so new submissions cannot take them. Several offers can be open at once.
    - The offer email's **Accept my place** opens "my registration" (signing in if needed), which shows "A place is available for your group until {date and time}" with **Accept** and **No thanks**. Times show in the event's time zone.
    - Accepting makes the registration `submitted` and sends the confirmation email.
    - **No thanks**, after a confirm, takes the group off the waitlist and offers the places onward at once.
    - A scheduled function every 15 minutes expires late offers, offers the places onward and emails the group "Your offer has expired". The group stays on the waitlist at the end of the queue.
    - A larger group skipped because it did not fit keeps its position for the next opening that fits.
    - Organizers see open offers with their expiry on the waitlist and can withdraw or extend one.
    - No automatic offers are made after the deadline; organizers can still offer by hand.
35. The **deadline** is a date and time in the event's time zone. After it, the link shows "Registration is closed" with the organizer's contact line; new submissions are refused; families can still view their registration, accept waivers and update contact details; other changes go through `registrations.manage` (B-13). [L9]
36. Before the deadline, the contact and linked adults edit their registration freely. Every change is logged with who, when, which field, and the value before and after, and `registrations.manage` can read the log (B-06). [L9]
37. `registrations.manage` can add, edit, approve, waitlist, cancel and reinstate registrations at any time, including after the deadline and at the door. Going over capacity shows a warning they must confirm (B-12). [L9, L16]

### Duplicates

38. On submit, the server checks each person against the event: a likely duplicate is someone whose normalised name (case, spacing and accents ignored) and birth date match, or whose normalised name matches and whose group's contact email or phone matches. A match flags the registration; it still goes in, and the submitter is never told about or shown the other group. [L10]
39. Nothing is merged automatically. `registrations.manage` sees a "Possible duplicates" list, opens the two groups side by side, chooses which group to keep and which people are the same, and merges. [L10]
40. A merge moves people not already present into the kept group, keeps matched people once (filling their blank answers from the duplicate), marks the other registration `cancelled` as merged into the kept one, updates counts at once, writes the merge to the change log, and removes the duplicate contact's access unless they are an adult in the kept group (B-11). [L10]
41. "Not a duplicate" clears the flag for that pair for good. [L10]
42. If a merged-away registration has a payment, the merge notes it for finance; handling it is 2B. [L10]

### Family members

43. The contact invites another adult in the group by email or phone from their registration. An email invite is emailed; a phone invite creates the invite link, which the contact sends from their own phone through the share sheet, since CrewPoint sends no SMS in 2A. The invitee signs in with that same email or phone (or a Google or Apple account with that email), and becomes a **linked adult** of the group (Stage 1's `adultUids`, `group.editOwn`). [L12, L24]
44. A linked adult can do everything the contact can on that group, including accepting waivers for themselves and for the group's children, and can see no other group (L-05). [L12]
45. Only adults (18+ on the event's first day) in the group can be invited. An invite works only for the email or phone it was sent to, expires after **14 days**, and can be resent. Children never get accounts this way. [L12]
46. The contact can remove a linked adult and hand the contact role to another linked adult. A group always has exactly one contact. [L12]

### RSVP

47. A personal link lists the group's invited guests by name. Each guest is **Yes**, **No** or **Maybe**, with any questions the form asks, and one person can answer for the whole party. Answers can change until the deadline. [L15]
48. Yes counts like a submitted registration. Maybe is shown separately (for example "42 coming, 6 maybe") and is not in meal or session counts. No stays on the guest list as declined and is left out of everything else. [L15]
49. The organizer sets how many **extra guests** each party may bring (0 by default, settable per group). A guest adds each one by name, or as "Guest of <name>" when the name is unknown, and extras count like invited guests (WE-01). [L15]
50. `registrations.manage` can send "Remind those who haven't answered" by email to parties with no answer (WE-02). Scheduled reminders are Stage 3. [L15]

### Email

51. 2A adds transactional email: one provider, an authenticated sending domain (SPF, DKIM, DMARC; O-04), a server-written outbox, a function that sends each message, and a delivery log with status per message. Clients never write the outbox. [L11]
51a. Dev and staging send only to an allowed list of addresses kept in a server setting; any other recipient is logged as "Not sent: not on the dev allowed list". Only prod sends to everyone. Real delivery is turned on only once the sending domain's SPF, DKIM and DMARC records are in place. [L33]
52. Messages sent at once in 2A [L11]:
    - registration confirmation, listing who and what was registered, with a link back to "my registration" (N-01);
    - family member invite (N-02);
    - personal RSVP invitation (Requirement 13b);
    - waitlist place offer;
    - "Remind those who haven't answered" (Requirement 50) and a closing reminder that `registrations.manage` sends by hand;
    - waiver missing, sent by hand from the Missing waiver list.
53. Each email goes in the recipient's language (Requirement 56), uses the event's words, and carries no money amounts. Email-only users (no app) receive every one of these (N-22). [L11, L13]
54. Push is sent alongside email where the recipient has the app, using the existing push path. [L11]

### Language

55. The app gains an ARB translation pipeline behind `context.strings`, with English and Gujarati, keeping today's `AppStrings` call sites. [L13]
56. A person chooses English or ગુજરાતી on the event page before signing in; the choice is remembered on their account and used for their emails. [L13]
57. Every screen and email on the registration path is translated: event page, sign-in, form, review, confirmation, "my registration", family invites, RSVP links and the 2A emails. Other screens remain English until Stage 3. [L13]
58. Organizers can enter the event's own words in both languages: labels, section names, field labels and options, waiver text and the after-registration note. Where Gujarati is missing, English shows. [L13]
59. Gujarati renders correctly on web and in the app, using a bundled font that covers Gujarati (U-03). The font downloads only when someone picks Gujarati or opens an event whose default language is Gujarati, so English visitors never download it. Gujarati in PDFs is 2B, with receipts. [L13, L31]
59a. An **approved Gujarati spelling list**, `docs/i18n/gujarati-terms.md` backed by a data file the tests read, gives each English term, its approved Gujarati spelling and known wrong spellings (for example દેરોદ approved, ડેરોડ wrong; A-03). It starts with the registration path's words (actions, statuses, Yes / No / Maybe, days and months), the `GLOSSARY.md` terms and the convention's own names. CI fails when a known wrong spelling appears in the Gujarati ARB file, templates, labels, email templates, seed data or fixtures, or when a Gujarati string spells a listed term another way. [L31]
59b. A **release checklist**, `docs/release/registration-release-checklist.md`, must be complete before 2A is released [L31]:
    - "Gujarati reviewed by a native speaker", signed off by the owner, from a generated sheet of every Gujarati string added or changed since the last release beside its English, each marked OK or corrected; corrections join the spelling list.
    - English strings pass cspell in CI.
    - The manual checks of Testing Strategy 7.

### Membership

60. Submitting a registration (or a waitlisted one being accepted) makes the contact and each linked adult a **member** with the event's **"role for people who register"**: Participant by default, settable per event and per template (for example Player). Members already in the event keep their roles and gain this one. [L17]
61. Cancelling a registration, or merging it away, removes the registration role. The person stays a member only if they hold another role. [L17]
62. Personal RSVP links create no member until the guest signs in and is linked (Requirement 13). Children never become members. [L17]
63. Membership changes follow the Stage 1 rules: member documents are written only by the server, `permissions` comes from `computePermissions`, and the `memberIds`/`adminIds` arrays are still kept in step. [L17]

### Organizer screens

64. The event home shows a **Registration** entry to `registrations.manage`. Its summary shows counts by status (submitted, pending review, waitlisted, cancelled, drafts not yet sent), the not-yet-confirmed counts in groups and people with a link to each follow-up list (Requirement 4a), personal-link delivery states (Requirement 13b), capacity used, the deadline, the public link and QR with copy and share, and shortcuts to the lists below. [L16, L20, L22]
65. People gains filters for registration status, "Possible duplicates", "Missing waiver", "Not answered" (RSVP) and the waitlist in queue order with "Offer a place". Each group row shows its registration status as a tag. [L16]
66. A group's detail adds the registration's status and change log, the contact and linked adults, waiver acceptances per person, and the actions approve (when review is on), waitlist, cancel, reinstate, merge, resend confirmation, and send a "complete your registration" link. [L16]
67. **Event settings → Registration** holds the mode, capacity, deadline, review on or off, extra guests, sections and their order, built-in blocks, waivers, the after-registration note, the role for people who register, the offer window and the slug. Fields keep their existing Fields screen. [L16]
68. The roster export adds registration status, contact, submitted date and waiver acceptances per person. [L16]

### Quality and speed

69. The event page shows its content within **4 seconds** of opening the link and the form is usable within **6 seconds** [L14, L28]:
    - **Conditions:** Chrome DevTools' "Fast 4G" network preset with 4x CPU slowdown, a first visit with an empty cache, the release web build on the dev Hosting site, the median of 5 runs; plus one check on a real mid-range Android phone over mobile data.
    - **Content** means the event's title, dates and place are visible. **Usable** means Register can be tapped and the first field typed in.
    - Opening `/e/:eventSlug` returns a small server-rendered page with the title, dates, place, a Register button and link-preview tags (event name and cover photo, so links shared on WhatsApp, iMessage or email preview properly). The app loads behind it and takes over. This is built from the start.
    - Results are recorded in `docs/testing/load-baselines.md`. It is a manual check before 2A is done, not a CI gate.
    - If the form misses 6 seconds, the owner decides the remedy.
70. Supported browsers: iOS Safari 16+, Chrome on Android, and desktop Chrome, Safari, Edge and Firefox. [L14]
71. Every 2A screen meets the design system's quality floor: 48 px tap targets, readable at 320 px with 200% text, screen-reader labels, dark mode, status shown with an icon and colour together, all text through `context.strings`, and general concepts through `event.words`. [L14]
72. Registering should feel at least as easy as a Google Form: one link, no app, answers saved as you go, a review page and a confirmation. Savita's unaided session in Gujarati on the web (U-05) is the acceptance check. [L6]

## Technical Decisions

1. **Data model** (all under `events/{eventId}`, Firestore as the source of truth) [L4, L9, L10, L15]:
   - `registrations/{registrationId}`: `groupId`, `contactUid` (or none for a personal-link group until linked), `status`, `submittedAt`, `updatedAt`, `waitlistPosition`, `cancelReason` and `mergedInto`, `duplicateOf` flags, `rsvp` answers per person for RSVP events, `extraGuestsAllowed`, and the last `submissionId` for idempotency. `changes/{changeId}` holds the change log; only the server writes it.
   - `registrationLinks/{tokenHash}`: the group a personal link opens, and whether it is active. The token is stored hashed.
   - `waivers/{waiverId}` with `versions/{n}`; acceptances under the person's `private/` area, written only by the server.
   - `settings.registration` on the event: `mode`, `deadline`, `review`, `extraGuests`, `sections`, `blocks`, `afterNote` and its replacement date, `registrationRoleId`, `offerHours`. `capacity` stays where it is.
   - `eventSlugs/{slug}` at the top level, mapping a slug to its event, written only by the server.
   - `registrationTally/current`: places used, the next waitlist number and open offers with their expiry; written only by the server, in the same transaction as every capacity change. [L26, L29]
   - `photoConsent/current`: the No and Not answered list (Requirement 30), written only by the server, readable only with `photoConsent.read`. [L27]
   - Registration status and RSVP answers mirrored onto groups and participants (Requirement 4a), written only by the server. [L20]
   - `registrationLinks/{tokenHash}` also records the delivery state: not sent, sent, opened, answered. [L22]
2. **Server-side writes:** submitting, editing after the deadline, waitlist offers, approval, cancellation, merging, invites, linked-adult changes, waiver acceptances, slugs and personal links are callables or triggers, checked with `requirePermission` or ownership of the group. Clients may read their own registration and save drafts within rules. Every new callable is exported from `functions/src/index.ts` (`appCallables.test.ts`), and every new restricted path joins `roleMatrix.test.ts`. [L9, L10, L12, L17]
3. **The public event page** reads through a callable, as `previewInvite` does, returning public fields only, so events stay unreadable to non-members in rules. The public and personal-link callables allow unauthenticated calls, enforce App Check and per-address or per-link rate limits (Requirement 13a). A Hosting rewrite sends `/e/:eventSlug` to a function that renders the small first page with link-preview tags, then loads the Flutter app (Requirement 69). [L5, L21, L28]
4. **Idempotent submit:** the client sends a `submissionId` generated once per form; the server ignores a repeat with the same ID, in a transaction that also reads and updates `registrationTally/current`, so two families taking the last places get one each and the next is waitlisted. Firestore count queries are not used for this, because they are not transactional. [L18, L9, L26]
5. **Sign-in:** `IAuthService` gains email sign-in link (send and complete) and phone code (send and confirm) methods, implemented with Firebase Auth. SMS regions are limited to US, CA and GB in Firebase settings. Email links use the flavor's Hosting domain (Firebase Dynamic Links no longer exist), with Android App Links and iOS Universal Links association files on that domain and the matching app settings per flavor. Account linking reuses `linkMyParticipants`, extended to verified phone numbers in E.164, with the shared linking cases in fixtures. [L8, L24, L25]
6. **Email:** an `EmailTransport` interface in functions, one implementation for the chosen provider, a mock for tests. The provider is chosen during implementation from Resend or Postmark, by a simple API and free tier; its API key is a Secret Manager secret, never in the app. Messages are rendered from templates on the server, in the recipient's language. The dev and staging allowed list is a server setting (Requirement 51a). [L11, L33]
7. **Language:** Flutter's gen-l10n ARB files feed an `AppStrings` adapter, keeping `context.strings` call sites as `app_strings.dart` already plans. The person's language is stored on `users/{uid}`; before sign-in it is kept on the device. [L13]
8. **Drafts:** the device copy goes through `IDraftStore`, with browser storage on web and the app's local storage on mobile, keyed by event and person; the server draft is a `registrations` document with status `draft`. [L18, L30]
9. **Mirroring:** registrations shown in the app follow the existing pattern (Firestore writes, Drift mirror with the `kIsWeb` fork) only where a screen lists them; the public form reads Firestore directly. Any Drift schema change adds a migration and its test. [L4]
10. **Membership** reuses the member-document callables and `computePermissions`; registration never writes member documents from the client. [L17]
11. **Scheduled work:** the offer-expiry function runs every 15 minutes and the tally recount nightly, both using an injected clock in their pure parts. [L26, L29]
12. **New permission:** `photoConsent.read` joins the catalogue in `functions/src/events/permissions.ts` and the presets (`npm run gen:roles`). [L27]
13. **App Check** starts only in `main`, like the crash reporter; tests and emulator runs never need a real token. Any new package (share sheet, incoming links, App Check) carries its exact resolved version in `pubspec.yaml`. [L21, L30]

## Testing Strategy

1. **TDD for pure logic**, one failing test at a time, with no Flutter or Firebase imports: the duplicate matcher (name normalisation, birth date, contact match), the capacity and waitlist allocator (whole groups, next group that fits, offer expiry), form condition evaluation (category and one-answer conditions, hidden means not required), either/or session choices, waiver applicability and version status, RSVP counts (yes, maybe, no, extras), confirmed and not-yet-confirmed counts, phone number normalisation and phone linking (phone, mixed email and phone, badly formatted numbers), offer expiry and skipped groups, and the change-log diff. Implementations that run on both sides keep shared cases in fixtures, as `attends()` does. [L9, L10, L6, L7, L15, L20, L24, L29]
2. **Backend tests** (Jest on the `demo-crewpoint` emulators): every callable's success and refusal paths; rules for registrations, links, waivers, acceptances and slugs; the role matrix for each new path; idempotent submit under concurrent submissions; two submissions racing for the last places; accepting an offer racing its expiry; the tally recount; refusing a missing, wrong or turned-off link token and hitting the rate limits; `photoConsent.read` alone reading neither private details nor the roster, and the list updating when a guardian changes an answer; membership changes; the dev allowed list; and the email outbox written with the right recipients, language and template, sent only through the mock transport. N-00 proves no real email or SMS can be sent. [L11, L17, L18, L19, L21, L26, L27, L29, L33]
3. **Widget tests** for the form sections, review, error states, offline and saved indicators, the waitlist result, the language switch, the sign-in link screens (other device, expired link), the offer banner, the Photo consent screen and the organizer summary, at 320 px with 200% text and in dark mode. Router tests open `/e/:eventSlug`, `/r/:token` and `/e/:eventSlug/registration` signed out, new and signed in, and refuse a `from=` outside `/join/`, `/e/` and `/r/`. [L14, L18, L23, L25]
4. **Robot journeys** (`test/journeys/`, extending the existing robots and harnesses), with stable `domain.feature.action` keys on every new interactive widget [L19]:
   - a family registers on an open event: event page, email sign-in (fake), the form with sections, stays, session choices and a waiver, review, submit, confirmation, and "my registration";
   - a draft survives a reload and a lost connection, and a double submit creates one registration;
   - an RSVP by personal link with Yes, Maybe, a plus-one and a declined guest;
   - a full event waitlists a group, a cancellation offers the place, and the group accepts;
   - a contact invites a family member, who edits the registration and sees no other group;
   - the committee merges a flagged duplicate;
   - the registration path in Gujarati.
5. **Test Seams:** `IAuthService` fakes for email links and phone codes; `IDraftStore` (save, load and clear a draft per event and person; a memory fake); `IIncomingLinkSource` (a stream of opened links including the launch link; the fake pushes links on demand); the existing `IConnectivity` for Submit and the saved indicator, switched mid-journey; `IShareSheet` (share text and a link; the fake records what was shared); the `EmailTransport` mock; the injected `Clock` for deadlines, offer windows and invite expiry; `FakeMemberCalls` extended for the new callables; and the existing fake Firestore and Drift harnesses. No automated test calls Firebase Auth, an email provider or SMS for real, or touches `crewpoint-dev`. [L19, L30]
6. **Acceptance suite:** scenarios L-03 to L-07, B-01 to B-03, B-06 to B-09, B-11 to B-13, B-15, B-16, W-01, W-05, Z-02, Z-03, N-01, N-02, N-22, PA-02, WE-01 to WE-05, GAP-WED-13, GAP-ANY-02 and GAP-ANY-03 get tests named by ID, with `scenarios.json` updated and finished ones added to `finished_scenarios.json`. [L2]
7. **Manual checks**, gathered on the release checklist (Requirement 59b): real email delivery to Gmail, Outlook and Yahoo from the sending domain (O-04); a real SMS code to US, Canadian and UK numbers; an email sign-in link opened on iPhone and Android, with and without the app, and on a second device; the speed budget under Requirement 69's conditions; the owner's Gujarati review; and Savita's unaided web registration in Gujarati (U-05). [L8, L11, L14, L25, L28, L31]
8. **Spelling checks** in CI: the approved Gujarati list (Requirement 59a) and cspell on English strings. [L31]

## Out of Scope

- Fees, charges, payments, refunds, receipts and the fee estimate on the review page (2B). [L1]
- Waitlist offers with a payment deadline, and finance handling of paid duplicates (2B). [L9, L10]
- Sponsorships, pledges, sign-up lists (PA-03), budget lines and the sponsorship list (2C). [L1]
- The raffle (its own Stage 2 slice). [L2]
- Scheduled and automatic messages, audiences, history screens, de-duplication and push-to-email fallback (Stage 3). [L11]
- Gujarati for screens outside the registration path (Stage 3). [L13]
- Gujarati in PDFs (2B, with receipts). [L31]
- Sending SMS from CrewPoint, beyond Firebase's own sign-in codes. [L22, L24]
- Typed email codes (Stage 3, only if needed). [L8]
- File uploads in the form, and prices on questions or add-ons. [L6]
- Boarding and check-in waiver checks, the directory screen and the 21+ flag (Stage 5). [L7]
- Shuttle runs and the waterpark package (Stage 4).

## Open Questions

- Which domain will send email, for example `mail.crewpoint.app`, and who controls its DNS? This blocks only turning on real delivery and its manual checks; it is needed by early January so the domain can warm up before February. [L11, L33]
- The convention's waiver text (D10, Z-03). Placeholder text is used until it arrives. [L7]

## Follow-Ups

- Update L-04 in `docs/testing/CREWPOINT_CONVENTION_TEST_v4.md` to "email sign-in link". [L8]
- Update the Stage 2 and Stage 3 sections of `ai_specs/event-platform-plan.md`: Stage 2 split into 2A, 2B, 2C and the raffle slice; basic email and registration-path Gujarati moved into 2A; Stage 3 keeps the rest. [L1, L11, L13]
- Update CLAUDE.md's Architecture sections for registrations, public routes, email and languages as Work Items land.

## Notes

- The owner checks the Gujarati translation (Requirement 59b). [L31]
- `GLOSSARY.md` defines Waiver, Waitlist, Personal link, Linked adult and Event page, with a Waiver row in the event-type table; registration mode stays a setting name. [L32]
- Source of convention scenarios: `docs/testing/CREWPOINT_CONVENTION_TEST_v4.md` (PR #232). Platform scenarios PA-02, WE-01 to WE-05 and the GAP entries are in `ai_specs/event-platform-plan.md` and `docs/guide/GAPS.md`.
- The interview recorded the owner's context that the convention has always registered through Google Forms, and through mailed forms before that. [L6]
