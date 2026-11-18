---
type: Interview Ledger
parent: design-refresh-spec.md
---

## Records

### L1

Status: current

Question: How should the redesign and adding a whole group fit together?

Recommended Answer:
- One Spec, "Design refresh": the look first, then group entry as the first screen built in the new look, then every other screen most-used first.
- Each step is its own Work Item, tested on dev before the next.

Answer: Yes, one Spec, look first. Save a few UI samples for the most-used screens in the docs folder, and have a central design system so it is easy to manage.

Decision: One Spec, look first, then group entry in the new look, then the remaining screens. Mockups are saved in `docs/`, and there is one central design system.

Reason: Building group entry in today's look and restyling it later would build it twice. The first real screen proves the components.

### L2

Status: current

Question: What should the samples be, and which screens?

Recommended Answer:
- Static HTML mockups exported to PNG in `docs/design/mockups/`, one HTML and one PNG per screen, at 390 px, in light and dark, using the app's real colour and type values. Also published as one private page.
- Screens: Home (event list), Event home, People (roster), New group, Schedule (day), Tasks, Budget, Create event (template picker).
- Round 1: two or three style directions on the Event home only. Round 2: every screen in the chosen direction.
- No mockups for chat, settings, roles, counts and other admin screens.

Answer: Yes, and we need a form as well.

Decision: As recommended, plus a ninth phone mockup: the Person form, covering every field type (text, adult or child, date, group picker, single and multiple choice, yes or no, custom questions, private section, save bar, error states). Other forms follow its pattern.

### L3

Status: current

Question: What should the central design system be?

Recommended Answer:
- One home: `lib/app/core/design/` with tokens (light and dark colours, type scale, spacing, radius, shadows, motion), a theme built only from them, and components in `design/components/`: card, list row, status chip, section header, stat card, progress ring, avatar and avatar stack, buttons (primary, secondary, text, destructive), form fields (text, select, date, switch row, choice chips), sheet, dialog, empty, loading and error states, top bar.
- `AppColors`, `AppTypography` and the other constants move into the tokens and are deleted.
- A guard test fails on hard-coded colours, fonts or raw sizes outside `design/`.
- A "Design gallery" screen in the dev build, `docs/design/design-system.md`, and screenshot tests of the gallery.
- Mockups are the agreed look until a screen is built; then code is the source of truth.

Answer: yes

Decision: As recommended.

Negative Requirements:
- No second source of style values outside `lib/app/core/design/`.

### L4

Status: current

Question: What exactly does the New group screen do?

Recommended Answer:
- Entry: a "+" menu on People with "Add person" and "Add {group}" for `participants.edit` holders; "Add people" on an existing group's sheet; a group's linked adult gets only "Add people" for their own group and cannot create groups.
- Top: group name (required) and group-scope custom fields.
- One row per person: name (required), Adult or Child, birth date for a child (optional; sets the age band), email for an adult (optional, private; links their account later).
- Starts with two empty rows, "Add another person", remove per row, at most 20 per save, completely empty rows ignored.
- One Save creates the group and then everyone in one batch. IDs are fixed when the screen opens, so retries never duplicate. On failure everything typed stays and the message says what did not save. Afterwards it returns to People filtered to the group with "{Group} added with N people".
- Leaving with unsaved rows asks first.
- Not included: import, duplicate detection against other groups (Stage 2), photos.

Answer: yes

Decision: As recommended. The screen title and labels use the event's word for group.

### L5

Status: current

Question: How do per-person answers (meal choice, shirt size and so on) work on the group screen, and who answers?

Recommended Answer:
- Each person is a card with their questions shown inline, not behind "More". Choices are tappable chips, not dropdowns. Required questions are marked and Save points to missing ones. Private questions show only to those allowed to read private details.
- Each card after the first has "Same answers as {previous name}".
- Now: the organizer or the group's linked adult answers for everyone in the group; the linked adult can change answers later from the group sheet.
- Later (Stage 2, not this Spec): groups answer for themselves through the registration link, reusing the same cards.
- Not included: questions that apply only to some people.

Answer: Yes, I like it. (The owner first asked that each person gets to choose their own answers, for example meal preference and shirt size.)

Decision: As recommended.

### L6

Status: current

Question: How should the redesign handle web and tablet?

Recommended Answer:
- The same look on iOS, Android and web, CrewPoint's own style, with native platform behaviours (back swipe, date pickers, haptics).
- Under 600 px: one column, bottom navigation.
- From 840 px: a left sidebar; the Event home as a dashboard grid; People, Tasks and Budget as list and detail.
- Mockups add two laptop screens: the Event home dashboard and People list and detail.
- No separate admin website.

Answer: Yes, do the laptop layout too.

Decision: As recommended.

### L7

Status: current

Question: Should events get a cover photo?

Recommended Answer:
- Optional, set from Event settings by anyone who can manage the event; resized to about 1,600 px before upload; stored under the event in Storage; readable by anyone in the event.
- Shown as a banner on the Event home and a thumbnail on the event list card.
- With no photo: a calm accent-coloured banner with the event's icon. No stock photos, no per-template defaults.
- Not included: galleries, photo sharing, profile photo changes.

Answer: Yes, include the cover photo.

Decision: As recommended.

### L8

Status: current

Question: When does this happen, compared with the owner's full dev test of Stage 1 and Stage 2?

Recommended Answer:
- Order: mockups and choice, design system and gallery, group entry in the new look, the remaining screens most-used first, then the owner's full Stage 1 dev test on the new interface, then Stage 2.
- Stage 2 waits for at least the first three steps.
- Unchanged: merge after CI, dev deploys only with approval, stg waits, prod waits for the lawyer.

Answer: Yes, that order works.

Decision: As recommended.

Reason: Testing now would mean retesting every screen after the redesign, which changes no data or permissions apart from the cover photo and the group save.

### L9

Status: current

Question: What must the style directions keep, and what can change?

Recommended Answer:
- Keep: the CrewPoint name and logo shape, and Inter for text.
- Free: the palette (the cream background goes), the heading font (Poppins may go), the accent.
- Three directions on the Event home: Slate and sage; Ink and indigo; Warm neutral.
- All three: exactly one accent colour, status colours only for status, no gradients, no illustrations.
- App icons change only if the chosen direction needs it, as a separate small item.

Answer: Yes, it works.

Decision: As recommended. The owner wants a clean, professional look and not a "candy store", guided by three Dribbble references (a wedding planner app, an event booking app, the MeetCraft event planner dashboard).

Negative Requirements:
- No gradients, no illustrations, no more than one accent colour.

### L10

Status: current

Question: What happens when someone taps Save on the group screen with no connection, or taps it twice?

Recommended Answer:
- Saving needs a connection for a new group and an existing one alike: "You're offline. Connect to save this {group}." and everything typed stays.
- Save is disabled with progress while saving.

Answer: Needs a connection (as recommended).

Decision: As recommended.

Reason: A new group cannot be created offline (the group step is a callable), and an offline Firestore batch never completes, so the screen would wait forever.

Negative Requirements:
- No offline queueing of group saves.

### L11

Status: current

Question: How does a group's linked adult (no `participants.edit`) add people and change their group's answers, given they have no group sheet today?

Recommended Answer:
- People shows a "Your {group}" header per linked group, with "Add people" and "Edit answers", both opening the group screen; "Edit answers" fills in the existing people's cards.
- Organizers get "Edit answers" too.
- No renaming, adults, deletion or invitations for linked adults.

Answer: Header + group screen (as recommended).

Decision: As recommended. The group screen has an add mode and an edit-answers mode.

### L12

Status: current

Question: How are the cover photo's Storage rules tested, since the role matrix covers Firestore only?

Recommended Answer: Its own Storage rules test like `importRules.test.ts`, for each of the twelve preset roles, plus file type and size checks.

Answer: Yes, own test.

Decision: As recommended.

### L13

Status: current

Question: What does the event record for its cover, is it available offline, and what happens to the file on removal?

Recommended Answer:
- `cover: {path, updatedAt}`; the app works out the download URL.
- Mirrored into Drift (v17 → v18) so thumbnails show on an offline cold start.
- Removing the photo or deleting the event deletes the file.
- Pick at 1600 px, quality 85; JPEG, PNG or WebP under 5 MB; read checked on the member document; Storage CORS set per project for web.

Answer: Path + updated time; yes, store locally; delete the file.

Decision: As recommended.

### L14

Status: current

Question: What does "Same answers as" copy, who are a new group's linked adults, can a new group be empty, and how are group answers saved?

Recommended Answer:
- "Same answers as" copies every answer the person filling in the screen can see, standard and private; never name, adult or child, birth date or email.
- A new group starts with no linked adults.
- A new group needs at least one named person.
- Save order: group, then group answers (`saveGroupAnswers`), then the people batch; a retry repeats only unfinished steps.

Answer: All visible answers; none at first; need one person.

Decision: As recommended.

### L15

Status: current

Question: Should CI compare the Design gallery against saved screenshots?

Recommended Answer: Yes: a `design` tag run in CI, fonts bundled, goldens generated on Linux; the `screenshots` tag stays manual.

Answer: Yes, gallery in CI.

Decision: As recommended.

### L16

Status: current

Question: How do screens 600–839 px wide look?

Recommended Answer: Phone layout with bottom navigation, content capped and centred, as today.

Answer: Phone layout, wider.

Decision: As recommended.

### L17

Status: current

Question: On a laptop, what is Budget's list and detail, and how does the detail panel behave?

Recommended Answer:
- Budget: expense list, expense opens on the right; summary and settle-up stay above the list.
- Nothing selected: a quiet "Select a {participant} to see details".
- Routes select the row, so shared links work; below 840 px the detail becomes a full page; switching rows with unsaved edits asks first.

Answer: Expenses → expense; yes, as described.

Decision: As recommended.

### L18

Status: current

Question: What exactly does the design guard test flag?

Recommended Answer: `Color(0x…)`, `Colors.…`, `GoogleFonts`, `fontFamily:`, non-zero numbers in `EdgeInsets`, `SizedBox`, `BorderRadius`, `Radius`, and plain Material visual widgets (`Card`, `ListTile`, chips, buttons). Layout widgets and calculated sizes are allowed.

Answer: Precise list.

Decision: As recommended.

### L19

Status: current

Question: What happens to the other files in `lib/app/core/constants/`?

Recommended Answer: Durations and icons become tokens; the PDF theme reads the tokens so PDFs match the app; `app_assets.dart` stays; `CLAUDE.md` "UI conventions" is rewritten in the last migration Work Item.

Answer: Three move, assets stay.

Decision: As recommended.

### L20

Status: current

Question: Which outlined icon set does CrewPoint use?

Recommended Answer: Material Symbols Outlined.

Answer: Decide at mockups.

Decision: Round 1 mockups show Material Symbols Outlined and Lucide; the owner picks one with the style direction. Icons are reached only through icon tokens.

### L21

Status: current

Question: Which icon shows on the banner when an event has no cover photo?

Recommended Answer: The template's icon (a saved template uses its base template's), else the older `eventType` icon, else a plain event icon.

Answer: Template, then old type.

Decision: As recommended.

### L22

Status: current

Question: Which Round 1 style direction and icon set does CrewPoint use?

Recommended Answer: Slate and sage. Warm neutral's terracotta accent sits close to the red Overdue colour, so unread badges and accent chips read as warnings on every screen; sage's nearness to the green Done colour is milder and the cooler palette fits "clean, professional, not a candy store".

Answer: Slate and sage, with Lucide icons. (The owner weighed Slate and sage against Warm neutral.)

Decision: Slate and sage with Lucide. Round 2 mockups and the design system tokens start from the `:root` values in `docs/design/mockups/round-1/event-home-slate-sage-lucide-{light,dark}.html`. Status colours stay as shown. App icons do not need to change.
