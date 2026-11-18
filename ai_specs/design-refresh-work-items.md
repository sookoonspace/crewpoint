# Design refresh — Work Items

Local copy of the Work Items for [Spec #186](https://github.com/sookoonspace/crewpoint/issues/186). The GitHub issues linked below are the source of truth, and this copy follows them. Generated on 2026-11-18.

Local Spec copy: `ai_specs/design-refresh-spec.md`.

## Index

| # | Issue | Work Item | Blocked by |
|---|---|---|---|
| 1 | [#189](https://github.com/sookoonspace/crewpoint/issues/189) | Round 1 mockups (three directions, two icon sets) | None |
| 2 | [#190](https://github.com/sookoonspace/crewpoint/issues/190) | Round 2 mockups in the chosen direction | #189 |
| 3 | [#191](https://github.com/sookoonspace/crewpoint/issues/191) | design system foundation (tokens, theme, guard test) | #190 |
| 4 | [#192](https://github.com/sookoonspace/crewpoint/issues/192) | display components, Design gallery and goldens in CI | #191 |
| 5 | [#193](https://github.com/sookoonspace/crewpoint/issues/193) | action and form components | #192 |
| 6 | [#194](https://github.com/sookoonspace/crewpoint/issues/194) | responsive shell and list and detail | #192 |
| 7 | [#195](https://github.com/sookoonspace/crewpoint/issues/195) | New group screen for organizers | #193 |
| 8 | [#196](https://github.com/sookoonspace/crewpoint/issues/196) | linked adults and Edit answers on the group screen | #195 |
| 9 | [#197](https://github.com/sookoonspace/crewpoint/issues/197) | Person form in the new look | #193 |
| 10 | [#198](https://github.com/sookoonspace/crewpoint/issues/198) | event cover photo | #192 |
| 11 | [#199](https://github.com/sookoonspace/crewpoint/issues/199) | Home and Event home | #194, #198 |
| 12 | [#200](https://github.com/sookoonspace/crewpoint/issues/200) | People as list and detail | #194, #196, #197 |
| 13 | [#201](https://github.com/sookoonspace/crewpoint/issues/201) | Tasks as list and detail | #194 |
| 14 | [#202](https://github.com/sookoonspace/crewpoint/issues/202) | Budget as list and detail | #194 |
| 15 | [#203](https://github.com/sookoonspace/crewpoint/issues/203) | Schedule, Agenda and Session | #193 |
| 16 | [#204](https://github.com/sookoonspace/crewpoint/issues/204) | Create event, Setup and Join | #193 |
| 17 | [#205](https://github.com/sookoonspace/crewpoint/issues/205) | Chat | #193 |
| 18 | [#206](https://github.com/sookoonspace/crewpoint/issues/206) | event admin screens | #193 |
| 19 | [#207](https://github.com/sookoonspace/crewpoint/issues/207) | people admin, profile and app screens | #193 |
| 20 | [#208](https://github.com/sookoonspace/crewpoint/issues/208) | finish the migration | #199, #200, #201, #202, #203, #204, #205, #206, #207 |

## 1. [#189](https://github.com/sookoonspace/crewpoint/issues/189) Design refresh: Round 1 mockups (three directions, two icon sets)

Parent: #186

#### What to build
Static HTML mockups of the Event home in the three style directions, exported to PNG, plus the same screen shown with each of the two icon sets, so the owner can choose a direction and an icon set before any app code changes.

#### Required context
- Spec #186 Req 4–6, 9, 10, 12 and the reference shots in its Notes.
- Current Event home: `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` (what the screen shows today).
- Current palette and type for comparison: `lib/app/core/constants/app_colors.dart`, `app_typography.dart`.

#### Acceptance criteria
- [ ] `docs/design/mockups/` holds one HTML source and one PNG per screen, in light and dark, phone width 390 px.
- [ ] Three directions on the Event home only:
  - **Slate and sage:** white, slate grey text, a deeper sage accent.
  - **Ink and indigo:** white, near-black text, a muted indigo accent, like the MeetCraft reference without gradients.
  - **Warm neutral:** off-white, charcoal, a toned-down terracotta accent.
- [ ] Every direction keeps the CrewPoint name and logo shape and Inter for text, uses exactly one accent colour, uses status colours only for status (green paid or done, amber due, red overdue), has no gradients, no illustrations and no cream background. Headings are Inter or Inter Display.
- [ ] The Event home is also shown with Material Symbols Outlined and with Lucide icons.
- [ ] Colour and type values are written as named values in the HTML, so the chosen direction can become the token file (Technical Decision 8).
- [ ] All mockups are published together as one private page the owner can open on a phone and share.
- [ ] The owner's choice of direction and icon set is recorded in Spec #186 (and `ai_specs/design-refresh-spec.md`) as a new Interview Ledger record.

#### Covers
- User Stories: 1
- Requirements: 4, 5, 6, 9, 10, 12
- Technical Decisions: 8
- Interview Ledger: L1, L2, L9, L20

#### Blocked by
None - ready to start

## 2. [#190](https://github.com/sookoonspace/crewpoint/issues/190) Design refresh: Round 2 mockups in the chosen direction

Parent: #186

#### What to build
Mockups of the most-used screens, phone and laptop, in the direction and icon set chosen in Round 1, approved by the owner as the agreed look.

#### Required context
- Spec #186 Req 4, 5, 7, 8, 11, 19 and 23 (laptop layout) and the Round 1 decision.
- Screens being mocked: `dashboard_screen.dart`, `event_dashboard_screen.dart`, `roster_screen.dart`, `participant_screen.dart`, `schedule_screen.dart`, `event_tasks_page.dart`, `event_budget_page.dart`, `template_picker_screen.dart`.
- Custom field types: `lib/app/features/participants/domain/models/custom_field.dart`.

#### Acceptance criteria
- [ ] Nine phone screens (390 px), light and dark, HTML plus PNG in `docs/design/mockups/`: Home (event list), Event home, People (roster), New group, Person form, Schedule (day), Tasks, Budget and Create event (template picker).
- [ ] The Person form covers every field type in use: text, the adult or child switch, a date, the group picker, single and multiple choice, yes or no, custom questions, a private section, the save bar and error states.
- [ ] The New group mockup shows the group name, group answers, person cards with chips, "Same answers as {previous name}", "Add another person" and a missing required answer.
- [ ] Two laptop screens: the Event home dashboard (summary cards in two or three columns, next sessions and open tasks side by side, left sidebar) and People as list and detail.
- [ ] Event home shows the cover banner and the no-photo banner (accent colour with the event's icon).
- [ ] No mockups for chat, settings, roles, counts or other admin screens.
- [ ] The private page from Round 1 is updated with every Round 2 mockup.
- [ ] The owner approves the set; the mockups are the agreed look until each screen is built (Req 19).

#### Covers
- User Stories: 2
- Requirements: 4, 5, 7, 8, 11, 19
- Interview Ledger: L2, L6

#### Blocked by
#189

## 3. [#191](https://github.com/sookoonspace/crewpoint/issues/191) Design refresh: design system foundation (tokens, theme, guard test)

Parent: #186

#### What to build
The single home of the look: tokens and theme in `lib/app/core/design/`, built from the chosen direction, with the old constants forwarding to it and a guard test that stops new hard-coded style.

#### Required context
- Spec #186 Req 13, 15, 16, 20; Technical Decisions 1, 3, 8; Testing Strategy 6.
- Today's style sources: `lib/app/core/constants/` (`app_colors`, `app_typography`, `app_spacing`, `app_radius`, `app_sizes`, `app_durations`, `app_icons`, `app_pdf_theme`, `wcag`, `breakpoints`) and `lib/app/core/theme/app_theme.dart`, `theme_mode_provider.dart`.
- The naming guardrail as the model for a plain Dart source-scanning test: `test_acceptance/naming_guardrail.dart`.
- `pubspec.yaml` for fonts and any icon package; CLAUDE.md rule on exact caret floors.
- The Round 1 decision (direction and icon set) in Spec #186's ledger.

#### Acceptance criteria
- [ ] Tokens live in `lib/app/core/design/` as `ThemeExtension`(s) read through `Theme.of(context)`: colours for light and dark, type scale, spacing, corner radius, shadows, motion (from `app_durations.dart`) and icons (from `app_icons.dart`), with the chosen direction's values. A brand colour or font is a one-line change.
- [ ] A design-system theme builder makes light and dark `ThemeData` only from the tokens and replaces `AppTheme.light()` / `AppTheme.dark()`; light and dark differ only in token values.
- [ ] The chosen icon set is reached only through icon tokens.
- [ ] Inter (and Inter Display if chosen) is bundled as a font asset; tests turn off runtime font fetching.
- [ ] `wcag.dart` and `breakpoints.dart` move into `lib/app/core/design/`; `app_pdf_theme.dart` moves there and reads the tokens, so exported PDFs match the app.
- [ ] `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppSizes`, `AppDurations` and `AppIcons` become deprecated forwarders to the tokens so unmigrated screens keep compiling; `app_assets.dart` stays in `lib/app/core/constants/`.
- [ ] A guard test in `test/` (a plain Dart test) fails if code outside `lib/app/core/design/` uses `Color(0x…)`, `Colors.…`, `GoogleFonts`, `fontFamily:`, a number other than `0` inside `EdgeInsets`, `SizedBox`, `BorderRadius` or `Radius`, or `Card`, `ListTile`, `Chip`/`ChoiceChip`/`FilterChip`/`InputChip`, `ElevatedButton`, `FilledButton`, `OutlinedButton` or `TextButton`. Calculated sizes are allowed. Listed exceptions sit in the test.
- [ ] Until the last screen moves, the guard test carries a temporary list of not-yet-migrated files; a file not on the list that breaks a rule fails the test.
- [ ] Platform behaviours stay native (back swipe, date pickers, haptics); the theme is CrewPoint's own, not stock Cupertino or Material (Req 21).
- [ ] Existing journey tests keep passing.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 3
- Requirements: 13 (tokens, theme), 15, 16, 20, 21
- Technical Decisions: 1, 3, 8
- Testing Strategy: 6, 9
- Interview Ledger: L3, L18, L19, L20

#### Blocked by
#190

## 4. [#192](https://github.com/sookoonspace/crewpoint/issues/192) Design refresh: display components, Design gallery and goldens in CI

Parent: #186

#### What to build
The first set of design-system components, a dev-only Design gallery showing them in light, dark and 200% text, golden tests of the gallery that CI runs, and the first version of the design-system guide.

#### Required context
- Spec #186 Req 13 (components), 17, 18; Technical Decision 2; Testing Strategy 5.
- Widgets these replace later: `lib/app/core/widgets/` (`status_badge`, `progress_ring`, `section_label`, `screen_header`, `empty_state_placeholder`, `skeletons`, `loading_animation`, `stat_triplet`, `settings_row`).
- Dev tools route: `AppRoutes.devTools` (`/profile/dev-tools`, `AppFlavor.dev` only) in `lib/app/core/router/app_router.dart`.
- Existing golden setup: `test/screenshots/_screenshot_helpers.dart`, `dart_test.yaml`, `scripts/regenerate-screenshots.sh`, `.github/workflows/flutter.yml`.

#### Acceptance criteria
- [ ] In `lib/app/core/design/components/`: card, list row, status chip, section header, stat card, progress ring, avatar and avatar stack, empty state, loading state, error state and top bar, built only from tokens.
- [ ] Components are plain widgets with no Riverpod or Firebase imports.
- [ ] Each component has widget tests, including its interactive keys and semantics.
- [ ] Status chips show icon and colour together; status colours appear only for status.
- [ ] A "Design gallery" screen, reachable only in the dev build, shows every component in light, dark and 200% text.
- [ ] Gallery golden tests run in light, dark and 200% text under a new `design` tag that CI runs on every PR; the goldens are generated on Linux by a script or CI job, not on a Mac. The `screenshots` tag stays manual.
- [ ] `docs/design/design-system.md` explains the tokens and when to use each component, with pictures from the gallery.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 3, 9
- Requirements: 13 (components), 17, 18
- Technical Decisions: 2
- Testing Strategy: 5, 9
- Interview Ledger: L3, L15

#### Blocked by
#191

## 5. [#193](https://github.com/sookoonspace/crewpoint/issues/193) Design refresh: action and form components

Parent: #186

#### What to build
The design system's buttons, form fields, sheet and dialog, ready for the group screen and every form.

#### Required context
- Spec #186 Req 13 (components), 21; Technical Decision 2.
- Widgets these replace later: `lib/app/core/widgets/` (`primary_button`, `destructive_button`, `custom_text_field`, `forms/`, `form_card_shell`, `dialog_overlay`, `segmented_filter_bar`, `reserved_checkmark_chip`).
- Approved Person form mockup in `docs/design/mockups/`.

#### Acceptance criteria
- [ ] Buttons: primary, secondary, text and destructive, each with a loading (busy) state that ignores taps.
- [ ] Form fields: text, select, date, switch row and choice chips (single and multiple), each with label, required mark, help and error text.
- [ ] Date fields open the platform's native date picker; haptics follow the platform (Req 21).
- [ ] Sheet and dialog components that keep their text controllers alive until they close (the #185 crash).
- [ ] Each component has widget tests, gallery entries in light, dark and 200% text, `design` goldens and a section in `docs/design/design-system.md`.
- [ ] Components are plain widgets with no Riverpod or Firebase imports.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 3
- Requirements: 13 (components), 18, 21
- Technical Decisions: 2
- Testing Strategy: 5, 9
- Interview Ledger: L3

#### Blocked by
#192

## 6. [#194](https://github.com/sookoonspace/crewpoint/issues/194) Design refresh: responsive shell and list and detail

Parent: #186

#### What to build
The app shell and a route-driven list-and-detail layout in the design system, so phone, tablet and laptop widths each get the agreed layout.

#### Required context
- Spec #186 Req 21–24; Technical Decision 9.
- `lib/app/core/widgets/responsive_shell.dart` (switches at 840 px), `content_max_width.dart`, `Breakpoints` (now in the design system).
- Router conventions: `lib/app/core/router/app_router.dart` (router built once, `refreshListenable`).
- Approved laptop mockups in `docs/design/mockups/`.

#### Acceptance criteria
- [ ] The shell lives in `lib/app/core/design/` and uses only tokens and components.
- [ ] Under 840 px: one column with bottom navigation; from 600 to 839 px the content is capped at a comfortable width and centred.
- [ ] From 840 px: a left sidebar replaces the bottom bar.
- [ ] A list-and-detail component: from 840 px, tapping a row opens it in a right-hand panel instead of a new page.
- [ ] With nothing selected, the panel shows a quiet prompt (for example "Select a {participant} to see details", words from `event.words`).
- [ ] The route is the source of truth: a detail route opens the list with that row selected, and back and shared links work.
- [ ] Narrowing below 840 px turns an open detail into a full page; widening returns to the split.
- [ ] Switching rows with unsaved edits in the panel asks first.
- [ ] Widget tests at 375, 744 and 1280 px cover each of the above.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 7
- Requirements: 21, 22, 23, 24
- Technical Decisions: 9
- Interview Ledger: L6, L16, L17

#### Blocked by
#192

## 7. [#195](https://github.com/sookoonspace/crewpoint/issues/195) Design refresh: New group screen for organizers

Parent: #186

#### What to build
One screen where an organizer creates a group, or adds people to an existing group, with every person's answers, saved in one go and safe to retry.

#### Required context
- Spec #186 Req 25–36, 38, 39; Technical Decisions 4–6; Testing Strategy 1–3; Notes (#185).
- Person form today: `lib/app/features/participants/presentation/participant_screen.dart` (leave-confirmation, private details, `filterTags`, `categoryId`).
- Group save paths: `MemberCalls.saveGroup` (`lib/app/features/dashboard/data/member_calls.dart`), `ParticipantRepository.save` and `saveGroupAnswers` (`lib/app/features/participants/data/participant_repository.dart`).
- Pure rules: `custom_field.dart` (`checkAnswer`, `filterTagsFor`), `category.dart`.
- Roster and group sheet: `roster_screen.dart`, `group_sheets.dart`.
- Rules: `firestore.rules` `participants` match (`editsParticipant`, group `exists`).
- Tests: `test/harness/roles_harness.dart`, `fake_member_calls.dart`, `test/robots/`; bounded pumps, not `pumpAndSettle`.
- Approved New group mockup in `docs/design/mockups/`.

#### Acceptance criteria
- [ ] Entry: People gets a "+" menu with "Add person" and "Add {group}" for `participants.edit` holders; an existing group's sheet gets "Add people", which opens the same screen with the group set.
- [ ] The screen is one route under People; titles and labels use the event's words (`event.words`).
- [ ] Top of the screen: the group name (required), then the event's group-scope custom fields. Adding to an existing group shows the name without editing it.
- [ ] One card per person: name (required) and Adult or Child; a child gets an optional birth date that sets the age band; an adult gets an optional email kept in private details; the person's participant-scope fields show in the card.
- [ ] Choice questions are tappable chips; required questions are marked and Save points to any that are missing; private questions show only to someone allowed to read private details.
- [ ] Every card after the first offers "Same answers as {previous name}", copying every custom-field answer the viewer can see (standard and private), never name, adult or child, birth date or email.
- [ ] The screen opens with two empty cards; "Add another person" adds one; each card has a remove button; at most 20 people per save; completely empty cards are ignored.
- [ ] A new group needs at least one named person; otherwise Save says "Add at least one person".
- [ ] Save runs `MemberCalls.saveGroup` (new group, pre-generated ID), then `saveGroupAnswers`, then every person and their `private/details` in one Firestore batch, computing `sortName`, `filterTags` and `categoryId` as the person form does.
- [ ] IDs are fixed when the screen opens; each step records success and a retry repeats only unfinished steps, so no duplicates.
- [ ] On failure everything typed stays and the message says what did not save.
- [ ] Offline, Save shows "You're offline. Connect to save this {group}." and nothing is sent or lost.
- [ ] Save is disabled with progress while saving; a second tap does nothing.
- [ ] After saving: back to People filtered to that group, with "{Group} added with N people" (new group) or "N people added to {group}" (existing group).
- [ ] Leaving with anything entered asks first.
- [ ] A new group starts with no linked adults. Existing rules are unchanged; drafts still refuse plain members.
- [ ] Person cards are a reusable widget (Stage 2 registration reuses them, Req 38).
- [ ] Draft logic is written test first, one behaviour at a time: draft rules, empty-card skipping, the 20 cap, "Same answers as", required-answer checks, retry without duplicates, offline refusal.
- [ ] Robot journeys in `test/journeys/` cover: an organizer adding a new group of several people with answers; adding people to an existing group; a failed batch kept intact and retried without duplicates; offline showing the message and keeping the draft; a second tap on Save doing nothing; closing dialogs and sheets with the keyboard up and leaving mid-edit (#185); leaving with unsaved entries; 375 px at 200% text in dark mode.
- [ ] Keys follow `domain.feature.action`, for example `people.groupEntry.addPerson`, `people.groupEntry.person.{index}.copy`, `people.groupEntry.save`.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, and `npm test` passes if rules tests are touched, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 4, 5
- Requirements: 25–36, 38, 39, 45, 46
- Technical Decisions: 4, 5, 6
- Testing Strategy: 1, 2, 3, 9
- Interview Ledger: L4, L5, L10, L14

#### Blocked by
#193

## 8. [#196](https://github.com/sookoonspace/crewpoint/issues/196) Design refresh: linked adults and Edit answers on the group screen

Parent: #186

#### What to build
A group's linked adult can add people to their own group and change their group's answers, and organizers can change a whole group's answers in one place, through the group screen's edit mode.

#### Required context
- Spec #186 Req 26, 37, 39; Technical Decision 4; Testing Strategy 2.
- How a linked adult sees People today: `roster_screen.dart` (`ownGroups` from `myMemberProvider`, no group sheet without `participants.edit`).
- Rules for linked adults: `firestore.rules` (`inMyGroup`, `group.editOwn`, the `fields`/`filterTags` update path).
- The group screen from the New group Work Item.

#### Acceptance criteria
- [ ] For a linked adult, People shows a "Your {group}" header for each group they are linked to, with "Add people" and "Edit answers".
- [ ] A linked adult never sees "Add {group}" and cannot rename the group, change its adults, delete it or change invitations.
- [ ] "Edit answers" opens the group screen in edit mode: the group's answers and one filled-in card per existing person, saved in one go with the same retry, offline and double-tap rules as adding.
- [ ] Organizers with `participants.edit` get "Edit answers" on the group sheet.
- [ ] Private answers show and save only for someone allowed to read private details (a linked adult of the group is).
- [ ] Existing rules are unchanged; existing participant and group rules tests keep passing.
- [ ] Robot journeys cover: a linked adult adding to their own group and not seeing "Add {group}"; a linked adult changing answers; an organizer changing answers from the group sheet.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 6
- Requirements: 26, 37, 39
- Technical Decisions: 4
- Testing Strategy: 2, 3
- Interview Ledger: L5, L11

#### Blocked by
#195

## 9. [#197](https://github.com/sookoonspace/crewpoint/issues/197) Design refresh: Person form in the new look

Parent: #186

#### What to build
The single-person form, kept for quick edits and single additions, rebuilt from the form components to match the approved Person form mockup, which every other form then follows.

#### Required context
- Spec #186 Req 8, 40.
- `lib/app/features/participants/presentation/participant_screen.dart`, `AttendanceSection`, `FieldAnswerInput`, `GroupPickerSheet`.
- Approved Person form mockup in `docs/design/mockups/`.
- Existing journeys under `test/journeys/` that drive the person form.

#### Acceptance criteria
- [ ] The form matches the mockup for every field type: text, adult or child, date, group picker, single and multiple choice, yes or no, custom questions, private section, save bar and error states.
- [ ] Behaviour is unchanged: who may read and write private details, leave confirmation, `?group=` start, `new` to add.
- [ ] The screens use only design-system components and tokens (Req 14); their files are removed from the guard test's temporary list.
- [ ] Existing journey tests keep passing, with selectors changed only where a widget's key must change (Testing Strategy 8); every new interactive widget has a `domain.feature.action` key.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- Requirements: 8, 14, 40, 45, 46
- Testing Strategy: 8, 9
- Interview Ledger: L2, L4

#### Blocked by
#193

## 10. [#198](https://github.com/sookoonspace/crewpoint/issues/198) Design refresh: event cover photo

Parent: #186

#### What to build
An optional cover photo per event, set from Event settings, shown as a banner on the Event home and a thumbnail on the event list card, with a calm fallback banner when there is none.

#### Required context
- Spec #186 Req 41–44; Technical Decision 7; Testing Strategy 4, 7.
- Image seam: `lib/app/core/services/image_service.dart` (`IImageService`, picker defaults 512 px), `firebase_image_service.dart`.
- `storage.rules`; Storage rules test model: `functions/test/imports/importRules.test.ts`.
- Event model and Drift: `lib/app/core/database/app_database.dart` (schema v17, migrations), events DAO, `EventRepository`.
- `deleteEvent` in `functions/src/`; `createEvent` defaults.
- Template icons: `assets/templates/*.json` (`icon`), `TemplatePickerScreen.iconFor`, `iconForEventType` (`dashboard/domain/event_type_emoji.dart`); saved templates carry `baseTemplateId`.
- `docs/ops/` for the CORS checklist step.

#### Acceptance criteria
- [ ] Event settings has "Cover photo" for `event.manage` holders: choose from the phone or computer, replace, or remove.
- [ ] The photo is picked with `maxWidth`/`maxHeight` 1600 and quality 85 through `IImageService`, and stored at `events/{eventId}/cover.jpg`.
- [ ] The event document carries `cover: {path, updatedAt}`; the app works out the download URL; a replaced photo shows everywhere without a stale copy. A missing field means no photo; `createEvent` defaults are unchanged.
- [ ] `storage.rules`: read for anyone with a member document in the event; write and delete with `event.manage` (checked on the member document, not `memberIds`); JPEG, PNG or WebP only, under 5 MB.
- [ ] Removing the photo deletes the file; `deleteEvent` deletes `events/{eventId}/cover.jpg`.
- [ ] Drift's events table gains `cover_path` and `cover_updated_at` (schema v17 → v18) with `test/database/migration_v17_to_v18_test.dart`; thumbnails show on an offline cold start once loaded before. The `kIsWeb` fork reads the field from Firestore.
- [ ] A banner component shows the photo on the Event home and a thumbnail on the event list card.
- [ ] With no photo: a calm accent-coloured banner with the event's icon: the template's icon (a saved template uses its base template's), else `iconForEventType`, else a plain event icon. No stock photos, no per-template default photos.
- [ ] A Storage rules test built like `importRules.test.ts` runs for each of the twelve preset roles: everyone in the event reads; only `event.manage` holders upload, replace and delete; outsiders and signed-out users do nothing; a file of 5 MB or more, or a non-image, is refused. `roleMatrix.test.ts` is unchanged.
- [ ] App tests use a fake `IImageService` and cover set, replace, remove and the banner icon fallbacks.
- [ ] `docs/ops/` records the one-time Storage CORS setting for dev, stg and prod, and it is checked on dev.
- [ ] CLAUDE.md's data model notes the `cover` field and the Storage path.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, `npm run build` and `npm test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 8
- Requirements: 41, 42, 43, 44
- Technical Decisions: 7
- Testing Strategy: 4, 7, 9
- Interview Ledger: L7, L12, L13, L21

#### Blocked by
#192

## 11. [#199](https://github.com/sookoonspace/crewpoint/issues/199) Design refresh: Home and Event home

Parent: #186

#### What to build
The event list and the Event home in the new look, with the Event home as a dashboard grid on laptops.

#### Required context
- Spec #186 Req 14, 23, 43, 45, 46.
- `dashboard_screen.dart`, `event_dashboard_screen.dart`, `lib/app/core/widgets/event_tile.dart`, `task_progress_summary.dart`, `stat_triplet.dart`.
- Approved Home, Event home and Event home dashboard mockups in `docs/design/mockups/`.
- The cover banner from the cover photo Work Item.

#### Acceptance criteria
- [ ] Home and Event home match the approved mockups in light and dark.
- [ ] From 840 px the Event home is a dashboard grid: summary cards in two or three columns, the next sessions and open tasks side by side.
- [ ] The cover banner (or the no-photo banner) heads the Event home; the event list card shows the thumbnail.
- [ ] The screens use only design-system components and tokens (Req 14); their files are removed from the guard test's temporary list.
- [ ] Existing journey tests keep passing, with selectors changed only where a widget's key must change (Testing Strategy 8); every new interactive widget has a `domain.feature.action` key.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 7, 9
- Requirements: 14, 23, 43, 45, 46
- Testing Strategy: 8, 9
- Interview Ledger: L6

#### Blocked by
#194, #198

## 12. [#200](https://github.com/sookoonspace/crewpoint/issues/200) Design refresh: People as list and detail

Parent: #186

#### What to build
The roster, group sheets and group picker in the new look, with People as list and detail on laptops.

#### Required context
- Spec #186 Req 14, 23.
- `roster_screen.dart`, `group_sheets.dart`, `GroupPickerSheet`, `link_requests_screen.dart` count banner, route `people/:participantId`.
- Approved People and People list-and-detail mockups.

#### Acceptance criteria
- [ ] People matches the approved mockups.
- [ ] From 840 px, People uses the list-and-detail component: `people/:participantId` opens the roster with that person selected on the right; the empty panel shows the quiet prompt; narrowing turns it into a full page; switching with unsaved edits asks first.
- [ ] Filters (group, answer), search, paging and the linked adult's "Your {group}" header keep working.
- [ ] The screens use only design-system components and tokens (Req 14); their files are removed from the guard test's temporary list.
- [ ] Existing journey tests keep passing, with selectors changed only where a widget's key must change (Testing Strategy 8); every new interactive widget has a `domain.feature.action` key.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 7, 9
- Requirements: 14, 23, 45, 46
- Testing Strategy: 8, 9
- Interview Ledger: L6, L17

#### Blocked by
#194, #196, #197

## 13. [#201](https://github.com/sookoonspace/crewpoint/issues/201) Design refresh: Tasks as list and detail

Parent: #186

#### What to build
Task list, detail and forms, and My tasks, in the new look, with Tasks as list and detail on laptops.

#### Required context
- Spec #186 Req 14, 23.
- `event_tasks_page.dart`, `event_task_detail_page.dart`, `task_list_screen.dart`, `task_detail_screen.dart`, `create_task_screen.dart`, `edit_task_screen.dart`, `my_tasks_screen.dart`.
- Approved Tasks mockup; form pattern from the Person form.

#### Acceptance criteria
- [ ] Tasks matches the approved mockup; task forms follow the Person form pattern.
- [ ] From 840 px, Tasks uses the list-and-detail component with the task route selecting the row, the quiet empty prompt, full page below 840 px, and a prompt before switching with unsaved edits.
- [ ] Status chips: green done, amber due, red overdue, each with an icon.
- [ ] The screens use only design-system components and tokens (Req 14); their files are removed from the guard test's temporary list.
- [ ] Existing journey tests keep passing, with selectors changed only where a widget's key must change (Testing Strategy 8); every new interactive widget has a `domain.feature.action` key.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 7, 9
- Requirements: 14, 23, 45, 46
- Testing Strategy: 8, 9
- Interview Ledger: L17

#### Blocked by
#194

## 14. [#202](https://github.com/sookoonspace/crewpoint/issues/202) Design refresh: Budget as list and detail

Parent: #186

#### What to build
The event budget page, ledger, global Budget tab and expense form in the new look, with Budget as list and detail on laptops.

#### Required context
- Spec #186 Req 14, 23.
- `event_budget_page.dart`, `budget_ledger_screen.dart`, `budget_screen.dart`, expense form and detail, `balance_tile.dart`, `money_text.dart`; `myBalanceProvider` paths for limited readers; `large_event.dart` (20 largest balances).
- Approved Budget mockup; form pattern from the Person form.

#### Acceptance criteria
- [ ] Budget matches the approved mockup; the expense form follows the Person form pattern.
- [ ] From 840 px, the summary and settle-up stay above the expense list, and an expense opens on the right, with the expense route selecting the row, the quiet empty prompt, full page below 840 px, and a prompt before switching with unsaved edits.
- [ ] Limited readers (no `money.read` / `expenses.readAll`) still see only their balance from `myBalanceProvider`.
- [ ] Paid shows green with an icon, owed or due amber, overdue red.
- [ ] The screens use only design-system components and tokens (Req 14); their files are removed from the guard test's temporary list.
- [ ] Existing journey tests keep passing, with selectors changed only where a widget's key must change (Testing Strategy 8); every new interactive widget has a `domain.feature.action` key.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 7, 9
- Requirements: 14, 23, 45, 46
- Testing Strategy: 8, 9
- Interview Ledger: L17

#### Blocked by
#194

## 15. [#203](https://github.com/sookoonspace/crewpoint/issues/203) Design refresh: Schedule, Agenda and Session

Parent: #186

#### What to build
The schedule (by day and by venue), the agenda and the session screen in the new look.

#### Required context
- `schedule_screen.dart`, `agenda_screen.dart`, `session_screen.dart`, `VenueCard`, `LastUpdatedNote`.
- Approved Schedule (day) mockup; form pattern from the Person form.

#### Acceptance criteria
- [ ] Schedule matches the approved mockup; the session form follows the Person form pattern.
- [ ] Agenda, venue view, hidden drafts for `schedule.edit` and the offline "Last updated" note keep working.
- [ ] The screens use only design-system components and tokens (Req 14); their files are removed from the guard test's temporary list.
- [ ] Existing journey tests keep passing, with selectors changed only where a widget's key must change (Testing Strategy 8); every new interactive widget has a `domain.feature.action` key.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 9
- Requirements: 14, 45, 46
- Testing Strategy: 8, 9

#### Blocked by
#193

## 16. [#204](https://github.com/sookoonspace/crewpoint/issues/204) Design refresh: Create event, Setup and Join

Parent: #186

#### What to build
The template picker, create and edit event forms, the setup checklist and the join screen in the new look.

#### Required context
- `template_picker_screen.dart`, `create_event_screen.dart`, `edit_event_screen.dart`, `setup_checklist_screen.dart`, `join_screen.dart`.
- Approved Create event mockup; form pattern from the Person form.

#### Acceptance criteria
- [ ] The template picker matches the approved mockup; event forms follow the Person form pattern.
- [ ] Fast-path templates still need only a title and date; saved templates still list first; join previews and refusals still show.
- [ ] The screens use only design-system components and tokens (Req 14); their files are removed from the guard test's temporary list.
- [ ] Existing journey tests keep passing, with selectors changed only where a widget's key must change (Testing Strategy 8); every new interactive widget has a `domain.feature.action` key.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 9
- Requirements: 14, 45, 46
- Testing Strategy: 8, 9

#### Blocked by
#193

## 17. [#205](https://github.com/sookoonspace/crewpoint/issues/205) Design refresh: Chat

Parent: #186

#### What to build
The chat inbox and event chat in the new look, following the design system (no mockup).

#### Required context
- Spec #186 Req 11.
- `chat_inbox_screen.dart`, `chat_screen.dart`, `event_chat_page.dart`, `lib/app/core/widgets/conversation_tile.dart`.

#### Acceptance criteria
- [ ] Chat follows the design system; urgent messages and settlement bubbles use status colour with an icon.
- [ ] "Show earlier messages", the offline note and unread counts keep working.
- [ ] The screens use only design-system components and tokens (Req 14); their files are removed from the guard test's temporary list.
- [ ] Existing journey tests keep passing, with selectors changed only where a widget's key must change (Testing Strategy 8); every new interactive widget has a `domain.feature.action` key.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 9
- Requirements: 11, 14, 45, 46
- Testing Strategy: 8, 9

#### Blocked by
#193

## 18. [#206](https://github.com/sookoonspace/crewpoint/issues/206) Design refresh: event admin screens

Parent: #186

#### What to build
Event settings, members, roles, crews, transfer, expense access and the invite sheet in the new look, following the design system (no mockups).

#### Required context
- Spec #186 Req 11.
- `event_settings_screen.dart`, `member_management_screen.dart`, `member_detail_screen.dart`, `roles_screen.dart`, `role_editor_screen.dart`, `crews_screen.dart`, `transfer_screen.dart`, `expense_access_screen.dart`, `event_detail_screen.dart`, `AddMemberSheet`.

#### Acceptance criteria
- [ ] Every listed screen follows the design system and the Person form pattern for forms.
- [ ] Permission gating is unchanged.
- [ ] The screens use only design-system components and tokens (Req 14); their files are removed from the guard test's temporary list.
- [ ] Existing journey tests keep passing, with selectors changed only where a widget's key must change (Testing Strategy 8); every new interactive widget has a `domain.feature.action` key.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 9
- Requirements: 11, 14, 45, 46
- Testing Strategy: 8, 9

#### Blocked by
#193

## 19. [#207](https://github.com/sookoonspace/crewpoint/issues/207) Design refresh: people admin, profile and app screens

Parent: #186

#### What to build
Counts, fields, import and link requests; profile, notifications and privacy; onboarding, sign-in, the update screen and dev tools, in the new look.

#### Required context
- Spec #186 Req 11.
- `counts_screen.dart`, `fields_screen.dart`, `import_screen.dart`, `link_requests_screen.dart`; `profile_screen.dart`, `edit_profile_screen.dart`, `notification_settings_screen.dart`, `privacy_dashboard_screen.dart`, `markdown_render_screen.dart`; `onboarding_screen.dart`, `auth_gate_screen.dart`, `app_update_gate.dart`; `dev_tools_screen.dart`.

#### Acceptance criteria
- [ ] Every listed screen follows the design system and the Person form pattern for forms.
- [ ] Permission gating, exports and the update gate are unchanged.
- [ ] The screens use only design-system components and tokens (Req 14); their files are removed from the guard test's temporary list.
- [ ] Existing journey tests keep passing, with selectors changed only where a widget's key must change (Testing Strategy 8); every new interactive widget has a `domain.feature.action` key.
- [ ] Quality floor (Req 45, 46): tap targets at least 48 px, text at 200% without clipping, dark mode works, status shows icon and colour together, all text through `context.strings`, general concepts through `event.words`, naming guardrail passes.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).

#### Covers
- User Stories: 9
- Requirements: 11, 14, 45, 46
- Testing Strategy: 8, 9

#### Blocked by
#193

## 20. [#208](https://github.com/sookoonspace/crewpoint/issues/208) Design refresh: finish the migration

Parent: #186

#### What to build
Remove every second source of style, switch the guard test fully on, and leave the docs describing the design system as the only way to style the app.

#### Required context
- Spec #186 Req 14–16, 18, 19; Technical Decision 3.
- The deprecated forwarders and the guard test's temporary list from the foundation Work Item.
- `lib/app/core/widgets/` leftovers; CLAUDE.md "UI conventions".

#### Acceptance criteria
- [ ] `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppSizes`, `AppDurations`, `AppIcons` and their files are deleted; `app_assets.dart` stays in `lib/app/core/constants/`.
- [ ] Widgets in `lib/app/core/widgets/` replaced by design-system components are deleted; nothing outside `lib/app/core/design/` is a second source of style.
- [ ] The guard test's temporary list is empty and removed; only listed exceptions remain.
- [ ] `docs/design/design-system.md` is complete; the mockups are marked as superseded by the code for built screens (Req 19).
- [ ] CLAUDE.md's "UI conventions" section is rewritten for `lib/app/core/design/`.
- [ ] `flutter analyze` (zero issues), `dart run custom_lint` and `flutter test` pass, using seams and fakes only; no test initialises Firebase or touches a real project.
- [ ] Merges after CI; reaches dev only with the owner's approval for that deploy. Stg and prod wait (Spec Req 3).
- [ ] After this lands on dev, the owner's full Stage 1 test runs on the new interface (Req 1).

#### Covers
- User Stories: 3, 9
- Requirements: 1, 14, 15, 16, 18, 19
- Technical Decisions: 3
- Interview Ledger: L1, L3, L8, L18, L19

#### Blocked by
#199, #200, #201, #202, #203, #204, #205, #206, #207
