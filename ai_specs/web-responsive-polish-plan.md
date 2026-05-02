## Overview

Layout-only pass: `Breakpoints` constants + `ContentMaxWidth` wrapper, ResponsiveShell threshold 720 → 840, chat-bubble fixed cap, per-screen body clamps + padding scale (24/40). Mobile UX (<600 px) preserved unchanged.

**Spec**: `ai_specs/web-responsive-polish-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first under `lib/app/features/`; shared scaffolding in `lib/app/core/{constants,widgets}/`.
- **State management**: Riverpod 3 (no app-state changes; pure layout work).
- **Reference implementations**:
  - `lib/app/features/auth/presentation/auth_gate_screen.dart` — `Center > ConstrainedBox(maxWidth: 480)` clamp shape; replicate in `ContentMaxWidth`.
  - `test/app/features/auth/auth_gate_screen_layout_test.dart` — `setSurfaceSize` + `addTearDown` + `tester.getSize(find.byKey(...))` test pattern.
  - `lib/app/core/widgets/responsive_shell.dart` — `_railBreakpoint` constant (720 → 840).
  - `lib/app/features/chat/presentation/widgets/message_bubble.dart` — `MediaQuery.sizeOf(context).width * 0.75` → fixed cap.
  - `lib/app/features/profile/presentation/profile_screen.dart` — `_HeroCard` full-bleed sliver pattern.
- **Stable Key convention**: `{feature}.{screen}.{element}` (e.g. `dashboard.body.clamped`, `form.card.shell`).
- **Assumptions/Gaps**:
  - `SliverConstrainedCrossAxis` (Flutter 3.7+) is canonical sliver clamp; pair with `SliverPadding` parent (not `Padding`).
  - `MediaQuery.sizeOf(context)` rebuild scope is fine for the static `Breakpoints.screenHorizontalPadding(context)` helper; no Riverpod provider needed.
  - All 10 target screens currently use `AppSpacing.lg = 16` outer horizontal padding. New helper is uniform upgrade — 16 → 24 at compact/medium, 16 → 40 at expanded.
  - `event_detail_screen.dart` is dead code (defined, not routed). Out of scope; tracked in `ai_specs/todo.md`.
  - Sub-widgets (`task_list_screen.dart`, `task_detail_screen.dart`, `chat_screen.dart`) inherit clamp from routed parents — do NOT wrap separately.

## Plan

### Phase 1: Web responsive layout polish (single phase, sequenced)

- **Goal**: every routed body clamped per category; `ResponsiveShell` @ 840; chat bubble fixed-capped; canonical 24/40 padding. Layout-regression tests per category. All existing 210+ tests stay green.
- **Sequencing rule**: run `flutter test` after each subsection (foundations / slice / shell / bubble / forms / lists / details / markdown / padding) so regressions surface close to cause.

**Foundations:**
- [x] `lib/app/core/constants/breakpoints.dart` — `abstract final class Breakpoints` with `compactMax = 600`, `mediumMax = 840`, `expandedMax = 1200`, `largeMax = 1600` + `screenHorizontalPadding(BuildContext)` returning 24/40.
- [x] `lib/app/core/widgets/content_max_width.dart` — `ContentMaxWidth({required maxWidth, required child, alignment = Alignment.topCenter})`; body = `Align > ConstrainedBox(maxWidth) > child`.
- [x] TDD: `ContentMaxWidth` clamps child when parent wider; passes through when parent narrower (two cases via `tester.view.physicalSize`). (`test/app/core/widgets/content_max_width_test.dart`)
- [x] `lib/app/core/widgets/form_card_shell.dart` — `FormCardShell({required child, padding = AppSpacing.xl})`: at viewport > `compactMax` wraps in `Card(elevation: 1) > Padding(padding)`; ≤ compactMax passthrough. `Key('form.card.shell')` on Card.
- [x] TDD: `FormCardShell` resolves Card at 1280×800; Key absent at 375×812. (`test/app/core/widgets/form_card_shell_test.dart`)

**Thin vertical slice — dashboard end-to-end:**
- [x] `lib/app/features/dashboard/presentation/dashboard_screen.dart` — wrap `ListView.separated` body in `ContentMaxWidth(maxWidth: 720, key: Key('dashboard.body.clamped'))`; padding `EdgeInsets.symmetric(horizontal: Breakpoints.screenHorizontalPadding(context), vertical: AppSpacing.xl)`.
- [x] TDD: `dashboard_screen_layout_test.dart` (new) — at 1280×800 `dashboard.body.clamped` width ≤ 720; at 375×812 width fills viewport (> 300 && ≤ 375).

**ResponsiveShell breakpoint migration:**
- [ ] `lib/app/core/widgets/responsive_shell.dart` — `_railBreakpoint` 720 → 840; comment cites M3 medium → expanded boundary.
- [ ] TDD: split existing "renders NavigationRail at 800 and 1280 widths" into three — bar at 800, rail at 880 (NEW boundary case), rail at 1280. Write 880-rail test FIRST (RED before threshold migration since the new test pins behavior at the new boundary).

**Chat bubble width fix:**
- [ ] `lib/app/features/chat/presentation/widgets/message_bubble.dart` — replace `MediaQuery.sizeOf(context).width * 0.75` with **fixed-cap** `Align(alignment: isCurrentUser ? centerRight : centerLeft) > ConstrainedBox(maxWidth: 540)`. **No `LayoutBuilder`** — N bubbles → N rebuilds on resize causes web jank on long threads. 540 = 75% × 720 (chat thread clamp). Pin dependency in a comment naming both constants. **Deliberate divergence from spec §req-6**; rationale is web-perf, not correctness.
- [ ] TDD: extend (or create) `message_bubble_test.dart` — pump inside `SizedBox(width: 720)`, assert bubble width ≤ 540; pump inside `SizedBox(width: 375)`, assert width ≤ 375 (cap inactive below cap); assert `Align` direction flips by `isCurrentUser`.

**Form screens (clamp 480 + FormCardShell at >600 px):**
- [ ] `lib/app/features/profile/presentation/edit_profile_screen.dart` — wrap body in `ContentMaxWidth(maxWidth: 480, key: Key('editProfile.body.clamped')) > FormCardShell(child: form_fields)`.
- [ ] `lib/app/features/dashboard/presentation/create_event_screen.dart` — same shape, `Key('createEvent.body.clamped')`.
- [ ] `lib/app/features/tasks/presentation/create_task_screen.dart` — same shape, `Key('createTask.body.clamped')`.
- [ ] TDD: `edit_profile_screen_layout_test.dart` (new) — at 1280×800 body-clamped width ≤ 480 AND `form.card.shell` Card present; at 375×812 fills viewport AND no Card.

**List screens (clamp 720):**
- [ ] `lib/app/features/tasks/presentation/event_tasks_page.dart` — `ContentMaxWidth(maxWidth: 720, key: Key('eventTasks.body.clamped'))`.
- [ ] `lib/app/features/chat/presentation/event_chat_page.dart` — `ContentMaxWidth(maxWidth: 720, key: Key('eventChat.body.clamped'))`.
- [ ] `lib/app/features/profile/presentation/profile_screen.dart` — **special-case**: keep `_HeroCard` `SliverToBoxAdapter` full-bleed; clamp `SliverPadding` subtree via `SliverConstrainedCrossAxis(maxExtent: 720, sliver: SliverList(...), key: Key('profile.body.clamped'))`.
- [ ] `lib/app/features/dashboard/presentation/member_management_screen.dart` — `ContentMaxWidth(maxWidth: 720, key: Key('memberManagement.body.clamped'))`.
- [ ] TDD: `profile_screen_layout_test.dart` (new) — at 1280×800 `profile.body.clamped` ≤ 720 AND `_HeroCard` width = viewport (1280); at 375×812 both fill viewport.

**Detail screens (clamp 960):**
- [ ] Audit `EventDashboardScreen` for full-bleed hero before wrapping. If hero present → `SliverConstrainedCrossAxis(maxExtent: 960, ...)` on `SliverPadding` subtree only. If absent → plain `ContentMaxWidth(maxWidth: 960)`.
- [ ] `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — wrap per audit, `Key('eventDashboard.body.clamped')`.
- [ ] `lib/app/features/tasks/presentation/event_task_detail_page.dart` — `ContentMaxWidth(maxWidth: 960, key: Key('eventTaskDetail.body.clamped'))`.
- [ ] TDD: `event_dashboard_screen_layout_test.dart` (new) — at 1280×800 body-clamped ≤ 960; at 375×812 fills viewport. If hero present, hero stays full-bleed at both sizes.

**Markdown screens (clamp 720):**
- [ ] `lib/app/features/profile/presentation/markdown_render_screen.dart` — wrap `ListView` body in `ContentMaxWidth(maxWidth: 720, key: Key('markdown.body.clamped'))`.
- [ ] `lib/app/features/profile/presentation/privacy_dashboard_screen.dart` — wrap `ListView` body in `ContentMaxWidth(maxWidth: 720, key: Key('privacyDashboard.body.clamped'))`.
- [ ] TDD: extend `markdown_render_screen_test.dart` with clamp assertion at 1280×800. Use `await tester.binding.setSurfaceSize(const Size(1280, 800))` + `addTearDown(() async => tester.binding.setSurfaceSize(null))` so the existing default 800×600 surface doesn't accidentally satisfy the assertion.

**Padding-scale rollout:**
- [ ] Adopt `Breakpoints.screenHorizontalPadding(context)` on all 10 wrapped screens (replace existing `EdgeInsets.symmetric(horizontal: AppSpacing.lg)` / `EdgeInsets.all(AppSpacing.lg)`). Vertical stays `AppSpacing.xl = 24`.

**Closeout:**
- [ ] `ai_specs/todo.md` — append two follow-ups:
  - "Web polish followups — DashboardScreen FAB anchors to Scaffold's bottom-right, not the clamped body. At 1920 viewport with 720 clamp, FAB sits ~600 px outside content. Defer to V1+: inline 'Create event' button in the header OR `Positioned` overlay aligned to the clamp."
  - "Cleanup `lib/app/features/dashboard/presentation/event_detail_screen.dart` — defined but never routed. Either delete (preferred if `EventDashboardScreen` fully replaces it) or wire into the router."
- [ ] Manual smoke (Chrome DevTools): resize across 375 / 768 / 800 / 880 / 1280 / 1920 widths.
  - At each: every wrapped screen renders the expected clamp; ResponsiveShell flips bar ↔ rail at the 840 boundary; no horizontal overflow; existing functionality (sign in, event create, task create, chat send) works inside the clamps.
  - At 1920: verify auth-gate footer hrefs point at `crewpoint.sookoon.space` not `*.web.app` if not already verified.
- [ ] Verify: `flutter analyze` && `flutter test` (full suite must stay green; existing 210+ tests must not regress).

## Risks / Out of scope

- **Risks**:
  - **`SliverConstrainedCrossAxis` × hero `SliverToBoxAdapter`** — if hero uses a `Row` requiring `Expanded`, behavior may differ inside the sliver clamp. Mitigation: visual smoke at 1280×800 after ProfileScreen wrap; keep hero outside the sliver clamp per spec.
  - **Existing journey tests at default 800×600 surface** — 720 → 840 migration means default-surface journey tests now hit `bar` instead of `rail`. Some tests may rely on rail-specific Keys (`shell.rail.dashboard` vs `shell.bar.dashboard`). Mitigation: full `flutter test` after each subsection; if a journey test breaks, fix at the test level (set surface size > 840 explicitly), never revert the breakpoint.
  - **Card on cream BG** — `FormCardShell` adds Material `Card` (elevation 1) against `AppColors.cream`. Default M3 Card surface tint may clash. Mitigation: visual smoke at 1280×800 on the three form screens; if washed out, override `Card.color` to `AppColors.white` and tune elevation in `FormCardShell`.
  - **Single-phase blast radius** — sequencing 14+ screen wraps in one phase with no inter-phase checkpoint increases risk of mid-work breakage going undetected. Mitigation: per-subsection `flutter test` is mandatory, not optional.
- **Out of scope**:
  - Master-detail layouts (chat list + thread, events list + detail) — separate spec.
  - Multi-column dashboards / desktop-dense tables for budget + tasks.
  - Hover states beyond Material defaults, keyboard shortcuts, right-click menus.
  - Visual redesign (Linear/Notion-style minimalism).
  - Multi-column event card grid on the dashboard.
  - DashboardScreen FAB position fix at large viewports — tracked in `ai_specs/todo.md`.
  - `event_detail_screen.dart` cleanup — tracked in `ai_specs/todo.md`.
  - New robot journey tests — layout-only pass; existing journeys must stay green.
