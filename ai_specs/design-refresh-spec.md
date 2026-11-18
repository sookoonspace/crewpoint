---
type: Spec
title: Design refresh
---

## Problem

CrewPoint looks dated. The owner describes the current look as "from old iOS (iPhone 3rd generation era)". The earlier refresh (`ai_specs/screen-design-refresh-spec.md`) covered only the five main tabs. Every screen added in Stage 1 (People, groups, Schedule, Agenda, Counts, Roles, Setup and others) was built to work, mostly from plain Material list tiles and dialogs, on a cream, sage and terracotta palette with Poppins headings. Styling is spread across `lib/app/core/constants/` (`AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppSizes` and more) and each screen's own widgets, so there is no single place to change the look.

Entering people is also slow. An organizer adds one participant at a time, choosing the group again for each person, so a family of five takes five trips through the person form. Each person's own answers (meal choice, shirt size and so on) are entered on that one-person form.

Stage 2 is about to add many more screens (registration, payments, receipts), which would inherit the current look if nothing changes first.

## Proposed Outcome

CrewPoint gets a clean, professional look ("not a candy store") from one central design system, laid out properly for phones and for laptops, and an organizer can enter a whole group with all its people and their answers from one screen.

The owner first approves the look from mockups saved in the repo, then the design system is built, then the new group screen in the new look, then every other screen. The owner's full dev test of Stage 1 happens once, on the new interface, and Stage 2 starts after.

## User Stories

1. As the owner, I want to see and choose a style direction from mockups before any code is written, so I know what I am getting.
2. As the owner, I want sample mockups of the most-used screens saved in the repo, so the agreed look is recorded.
3. As a developer, I want one central design system for colours, type, spacing and components, so the look is easy to manage and change.
4. As an organizer, I want to add a whole group, with every person in it, from one screen, so I do not repeat the form for each person.
5. As an organizer, I want each person's own answers (for example meal preference and shirt size) on that same screen, so everything about the group is entered at once.
6. As a group's linked adult, I want to add people to my own group and change their answers, so my group's details are right.
7. As an organizer on a laptop, I want layouts that use the space (a sidebar, a dashboard grid, list and detail), so heavy work is comfortable on the web.
8. As an organizer, I want to give my event an optional cover photo, so the event list and event home look finished.
9. As any user, I want every screen to look and behave consistently, in light and dark mode and at large text sizes.

## Requirements

### Order of work

1. The order is: mockups and the owner's choice of direction, then the design system, then the new group screen, then the remaining screens most-used first, then the owner's full Stage 1 test on dev, then Stage 2. [L1] [L8]
2. Stage 2 waits for at least the mockups, the design system and the group screen, so registration and payments are built in the new look from the start. [L8]
3. Each Work Item merges after CI and reaches dev only with the owner's approval for that deploy. Stg waits, and prod waits for the lawyer's approval of the privacy policy (Req 39 of Stage 1). [L8]

### Mockups

4. Mockups are static screens written as HTML and exported to PNG, kept in `docs/design/mockups/`: one HTML source and one PNG per screen, in light and dark. Phone mockups are 390 px wide. They use the same colour and type values the app will use. [L2]
5. All mockups are also published together as one private page that the owner can open on a phone and share. [L2]
6. Round 1: three style directions, each shown on the Event home only. [L2] [L9]
   - **Slate and sage:** white, slate grey text, and a deeper sage accent.
   - **Ink and indigo:** white, near-black text, and a muted indigo accent, like the MeetCraft reference without gradients.
   - **Warm neutral:** off-white, charcoal, and a toned-down terracotta accent.
7. Round 2, in the chosen direction: nine phone screens, Home (event list), Event home, People (roster), New group, Person form, Schedule (day), Tasks, Budget and Create event (template picker). Also two laptop screens: the Event home dashboard and People as list and detail. [L2] [L6]
8. The Person form mockup covers every field type in use: text, the adult or child switch, a date, the group picker, single and multiple choice, yes or no, custom questions, a private section, the save bar and error states. Other forms (event details, expense, task, session) follow its pattern. [L2]
9. Every direction keeps: the CrewPoint name and logo shape, and Inter for text. [L9]
10. Every direction uses exactly one accent colour; status colours are used only for status (green for paid or done, amber for due, red for overdue); no gradients; no illustrations. The cream background is not kept. Poppins may be replaced (Inter throughout, or Inter Display for headings). [L9]
11. Chat, settings, roles, counts and other admin screens get no mockups; they follow the design system. [L2]
12. The reference shots the owner shared guide the feel only: the Dribbble wedding planner (soft cards, status chips, budget summary, a people picker with avatars and checks), the event booking app (photo-led cards, pill chips) and MeetCraft (white dashboard, stat cards, a segmented progress ring, tabs, a timeline). Their candy colours, gradients and illustrations are not used. [L9]

### Design system

13. The design system lives in `lib/app/core/design/` and is the only home of the look. [L3]
    - **Tokens:** colours for light and dark, the type scale, spacing, corner radius, shadows and motion. A brand colour or font is a one-line change.
    - **Theme:** `ThemeData` for light and dark is built only from the tokens.
    - **Components** (`lib/app/core/design/components/`): card, list row, status chip, section header, stat card, progress ring, avatar and avatar stack, buttons (primary, secondary, text, destructive), form fields (text, select, date, switch row, choice chips), sheet, dialog, empty state, loading state, error state and top bar.
14. Screens use only design-system components and tokens. [L3]
15. `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppSizes` and the other style constants in `lib/app/core/constants/` move into the tokens and are deleted, so there is no second source. `wcag.dart` and `breakpoints.dart` move into the design system. [L3]
16. A guard test fails if code outside `lib/app/core/design/` uses a colour literal (`Color(0x…)`, `Colors.…`), a font (`GoogleFonts`, `fontFamily`) or a raw size where a token exists. Exceptions are listed in the test. [L3]
17. The dev build has a "Design gallery" screen showing every component in light, dark and 200% text. [L3]
18. `docs/design/design-system.md` explains the tokens and when to use each component, with pictures. [L3]
19. The PNG mockups are the agreed look until a screen is built; after that the code is the source of truth. [L3]
20. One outlined icon set is used throughout, and motion is short and subtle.

### Layout

21. The look is the same on iOS, Android and web: CrewPoint's own style, not stock Cupertino or Material. Platform behaviours stay native: back swipe, date pickers and haptics. [L6]
22. Under 600 px: one column with bottom navigation. [L6]
23. From 840 px: a left sidebar replaces the bottom bar; the Event home is a dashboard grid (summary cards in two or three columns, the next sessions and open tasks side by side); People, Tasks and Budget are list and detail, where tapping a row opens it in a right-hand panel instead of a new page. [L6]
24. There is no separate admin website: it is the same app, laid out for the space. [L6]

### New group

25. The concept is a group (`GLOSSARY.md`); screens show the event's own word through `event.words` (for example "New family" at a convention, "New team" at a cricket tournament). In this Spec "family" is the convention's label, not a code term. [L4]
26. **Entry points:** [L4]
    - People gets a "+" menu with "Add person" and "Add {group}" for anyone holding `participants.edit`.
    - An existing group's sheet gets "Add people", which opens the same screen with the group already set.
    - A group's linked adult gets only "Add people", for their own group. They cannot create a group, as today's rules require.
27. **Top of the screen:** the group name, which is required, then the event's group-scope custom fields. When adding to an existing group, the name is shown and not edited here. [L4]
28. **One card per person,** containing: [L4] [L5]
    - Name, which is required, and an Adult or Child choice.
    - For a child: an optional birth date, which sets the age band.
    - For an adult: an optional email, kept in private details, which is what later links their account.
    - That person's participant-scope custom fields, shown in the card rather than behind "More".
29. **Answers:** [L5]
    - Choice questions show as tappable chips (for example `Veg · Jain · Non-veg` or `S · M · L · XL`), not dropdowns.
    - Required questions are marked, and Save points to any that are missing.
    - Private questions show only to someone allowed to read private details.
30. Every card after the first offers "Same answers as {previous name}", which copies the previous person's answers to that person's custom fields; the person can then change what differs. [L5]
31. **Rows:** the screen opens with two empty person cards. "Add another person" adds a card, and each card has a remove button. At most 20 people are saved at a time. A card left completely empty is ignored, not an error. [L4]
32. **Save:** one Save button creates the group (when new) through `saveGroup`, then writes every person in one batch. [L4]
33. **No duplicates:** each person and a new group get IDs when the screen opens, so retrying after a failure never creates duplicates. [L4]
34. **On failure:** everything typed stays, and the message says what did not save. [L4]
35. **After saving:** the app returns to People filtered to that group and shows "{Group} added with N people" (in the event's words; when adding to an existing group, "N people added to {group}"). [L4]
36. Leaving with anything entered asks first, as the person form does. [L4]
37. Who answers now: an organizer, or the group's linked adult for everyone in their group. A linked adult can later change their group's answers from the group sheet. [L5]
38. Stage 2 self-registration reuses the same person cards; that registration form is not part of this Spec. [L1] [L5]
39. Existing rules apply unchanged: `participants.edit`, or `group.editOwn` for the adult's own group, writes participants and their private details; groups are written only by the group callables; adding plain members to a draft is still refused. Private details are written only by someone allowed to read them, except when adding a new person (as today). [L4]
40. The single-person form stays for quick edits and single additions, rebuilt in the new look. [L4]

### Cover photo

41. An event may have one optional cover photo, set from Event settings ("Cover photo") by someone with `event.manage`, chosen from the phone or computer. It can be replaced or removed. [L7]
42. **Upload:** the app shrinks the photo to about 1,600 px on its long side before uploading. It is stored in Storage under the event, and anyone in the event can view it. [L7]
43. **Where it shows:** as a banner on the Event home and a thumbnail on the event list card. [L7]
44. **With no photo:** a calm banner in the accent colour with the event's icon. There are no stock photos and no per-template default photos. [L7]

### Quality floor

45. Tap targets are at least 48 px, text scales to 200% without clipping, every screen works in dark mode, and status uses icon and colour together, never colour alone.
46. All text goes through `context.strings`, general concepts through `event.words`, and the naming guardrail still passes.

## Technical Decisions

1. Tokens are a `ThemeExtension` (or extensions) read through `Theme.of(context)`, so light and dark differ only in token values; `AppTheme.light()` and `AppTheme.dark()` are replaced by the design system's theme builder. [L3]
2. Components are plain widgets in `lib/app/core/design/components/` with no Riverpod or Firebase imports, so the gallery and tests render them alone. [L3]
3. The old constants are migrated screen by screen and deleted once nothing uses them; the guard test (Req 16) is switched on when the last screen moves, with a temporary list of not-yet-migrated files until then. [L3]
4. The group screen is one route under People. Its source of truth is a local draft (group name, group answers, a list of person drafts with pre-generated IDs) held in a hand-written `Notifier` scoped to the screen, following `lib/app/core/providers.dart` conventions (no Riverpod codegen). [L4]
5. Saving a new group calls `MemberCalls.saveGroup` with the pre-generated group ID, then writes the participants and their `private/details` in one Firestore batch through `ParticipantRepository`, computing `sortName`, `filterTags` and `categoryId` the same way the person form does today (`custom_field.dart`, `category.dart`). [L4]
6. If the group save succeeds and the batch fails, a retry skips the group and repeats only the batch, with the same IDs. [L4]
7. The cover photo goes through the existing `IImageService` seam (`image_picker`, `FirebaseImageService`), extended for an event cover. It is stored at `events/{eventId}/cover.jpg`, with a new `storage.rules` match: event members read, `event.manage` holders write, an image content type, and a size cap. The event document gains an optional cover reference field, and `createEvent` defaults are unchanged. [L7]
8. The three style directions differ only in token values, so the chosen direction becomes the token file. [L2] [L9]
9. Laptop layouts build on `ResponsiveShell` and `Breakpoints` (840 px), which move into the design system. [L6]

## Testing Strategy

1. Domain and state logic for the group screen (draft rules, empty-row skipping, the 20-person cap, "Same answers as", required-answer checks, retry without duplicates) is written test first, one behaviour at a time. [L4] [L5]
2. The group flow has robot journey tests in `test/journeys/` over the existing harnesses (`RolesHarness`, `FakeMemberCalls`, fake Firestore). They cover: an organizer adding a new group of several people with answers; adding people to an existing group; a linked adult adding to their own group and not seeing "Add {group}"; a failed batch kept intact and retried without duplicates; leaving with unsaved entries; and 375 px at 200% text in dark mode. [L4] [L5]
3. Every new interactive widget has a stable key named `domain.feature.action` (for example `people.groupEntry.addPerson`, `people.groupEntry.person.{index}.copy`, `people.groupEntry.save`).
4. Rules tests cover the cover photo Storage path, and the role matrix (`functions/test/roleMatrix.test.ts`) gains it. Existing participant and group rules tests keep passing unchanged. [L7]
5. Design-system components have widget tests. The Design gallery has screenshot (golden) tests in light, dark and 200% text, under the existing `screenshots` tag. [L3]
6. The guard test (Req 16) is a plain Dart test in `test/`, like the naming guardrail. [L3]
7. The cover photo is tested through a fake `IImageService`; no test touches real Storage. The existing rule that tests never initialise Firebase still holds. [L7]
8. Every redesigned screen keeps its existing journey tests passing, updating selectors only where a widget's key must change.
9. `flutter analyze`, `dart run custom_lint`, `flutter test`, `npm run build` and `npm test` pass for each Work Item, as relevant to the change.

## Out of Scope

- Stage 2 self-registration, payments and receipts, which will reuse the person cards. [L1] [L5]
- Custom fields that apply only to some people, for example shirt size for children only. [L5]
- Duplicate detection against other groups, which belongs to Stage 2. [L4]
- Photos of people, galleries and photo sharing. Profile photos are unchanged. [L4] [L7]
- A separate admin website. [L6]
- Changing the app icons, unless the chosen direction needs it; that would be a separate small item. [L9]
- Mockups for chat, settings, roles, counts and other admin screens. [L2]

## Follow-Ups

- Custom fields that apply only to some people (by category or adult or child). [L5]
- App icons, if the chosen direction needs new ones. [L9]

## Notes

- Reference shots: dribbble.com/shots/23844128 (Wedding planner mobile application), dribbble.com/shots/25585528 (Event Booking App), dribbble.com/shots/27190517 (Event Planner Dashboard Design, MeetCraft). [L9]
- The crash fixed in #185 (a disposed text controller in the group name dialog) shows the group entry path needs robot coverage of keyboard and dialog lifecycles.
