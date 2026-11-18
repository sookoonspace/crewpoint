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
