<goal>
Make CrewPoint's web app feel like a web app on desktop instead of a stretched mobile UI. On viewports ≥ 840 px, screen content should center and clamp to a comfortable line length (480–960 px depending on the screen type) with proportional side gutters; on phone viewports (< 600 px) every screen renders identically to today. Mobile experience is preserved unchanged. The visual language stays the same — same Material 3 widgets, same cream + sage + charcoal palette, default Material hover states only — this is a layout pass, not a visual redesign.

**Why now.** The user is a first-time web-app shipper and the current build stretches phone-pattern single-column UIs to 1920 px wide. Pre-launch is the right window to fix this before users form a "the web app is busted" mental model. Counsel-pending legal copy and the Sookoon microsite at `sookoon.space/crewpoint/` already point at `crewpoint.sookoon.space`; the app behind that custom domain should look like it was designed for the browser.

**Who benefits.** Every web user, especially desktop and tablet-landscape users. Mobile users see no change. The fix also benefits future RTL audits (already in `todo.md`) since clamped content with explicit max-widths is easier to mirror than viewport-stretching ListViews.
</goal>

<background>
**Stack.** Flutter 3.27+ / Dart 3.11.5, Riverpod 3.0, Material 3 (`useMaterial3: true` is the project default).

**Existing responsive scaffolding** (`lib/app/core/widgets/responsive_shell.dart`):
- `ResponsiveShell` switches between `NavigationBar` (bottom) and `NavigationRail` (side) at width ≥ **720** px today. Spec migrates this to **840** (Material 3 medium → expanded boundary).
- `ResponsiveShell.body` is a single-child `Expanded` slot that renders the active feature screen. The clamping work targets each feature's body, not the shell.

**Per-screen clamping today.** Three exceptions to "stretches viewport-wide":
- `lib/app/features/auth/presentation/auth_gate_screen.dart` — auth form column clamps via `BoxConstraints(maxWidth: 480)` inside the `Center` wrapper. Layout-regression tests at `test/app/features/auth/auth_gate_screen_layout_test.dart` already lock this in.
- `lib/app/features/budget/presentation/event_budget_page.dart` — clamps at 1600 (already wide-friendly).
- `lib/app/features/chat/presentation/widgets/message_bubble.dart` — bubble width = `MediaQuery.sizeOf(context).width * 0.75`. **This is broken under the clamp** because the bubble would stay at 75% of the *viewport* (e.g. 1440 px) inside a 720-px-clamped chat thread. Spec replaces it with a `LayoutBuilder` constraint that scopes 75% to the *clamped* width.

**`AppSpacing` token reference** (`lib/app/core/constants/app_spacing.dart`): `xs = 4`, `sm = 8`, `md = 12`, **`lg = 16`**, **`xl = 24`**, `xxl = 32`, `xxxl = 48`. Different screens use different outer-padding tokens today (some use `lg = 16`, others use `xl = 24`). The padding scale this spec introduces is anchored to a *canonical* "screen horizontal padding" helper (24 px on compact/medium, 40 px on expanded+) that screens adopt regardless of which existing token they happened to use. See Requirement 5.

**Every other feature screen** stretches its body edge-to-edge today: dashboard, tasks (list + detail), chat thread, event detail, profile, edit profile, privacy dashboard, markdown render screen, create event, create task, member management, onboarding.

**Reference implementations:**
- Auth-gate clamp pattern (`auth_gate_screen.dart:21-39`) — `Center > ConstrainedBox(maxWidth: …) > content`. Replicate this shape via a shared `ContentMaxWidth` widget.
- `auth_gate_screen_layout_test.dart` — pump at fixed surface size (`tester.binding.setSurfaceSize`), assert `tester.getSize(find.byKey(...))`. Replicate the test pattern per screen.
- `lib/app/core/constants/app_spacing.dart` — existing spacing token file. Add a `Breakpoints` constants file beside it.

**Out of scope** (deferred to a future "V1+ web rebuild" if/when prioritized):
- Master-detail layouts (chat list + thread, events list + detail). User-stated V1 lite scope.
- Multi-column dashboards / desktop tables for budget/tasks.
- Hover states beyond Material defaults, keyboard shortcuts, right-click menus.
- Visual redesign (Linear/Notion-style minimalism).
- Multi-column event card grid on the dashboard.

**Constraints.**
- Mobile UX must not regress. Every layout test below 600 px must continue to pass.
- The 195+ existing `flutter test` suite must remain green.
- No new packages — clamp work uses Material widgets only.
</background>

<user_flows>
This is a layout pass — no flow changes. Walking through the same flows at three viewport classes:

**Phone (Compact <600, e.g. 375×812):**
1. User lands on the web app at `https://crewpoint.sookoon.space`.
2. Auth gate renders identically to today: 480-clamped form column fills viewport (375 < 480 → no gutters).
3. `ResponsiveShell` shows bottom `NavigationBar` (375 < 840 — same threshold behavior in spec since 375 < 720 and 375 < 840 both resolve to bar).
4. Every feature screen renders edge-to-edge — exactly today's behavior.
5. Footer + auth-gate legal links visible above home indicator on iOS.

**Tablet portrait (Medium 600–840, e.g. 768×1024):**
1. ResponsiveShell stays on bottom `NavigationBar` (768 < 840). New behavior — today this would be a rail at 720; the spec moves the threshold up. Justification: a 768-wide tablet portrait UX is closer to phone than desktop, especially with on-screen keyboards eating vertical space.
2. Feature screen bodies still single-column. Lists clamp at 720, but viewport is 768 → barely any gutter (24-px-each side). Forms clamp at 480 → noticeable gutters (~140 px each side).
3. Markdown render screen clamps at 720 → reads at comfortable line length.

**Desktop expanded (≥840, e.g. 1280×800 or 1920×1080):**
1. ResponsiveShell switches to `NavigationRail` (extended, with labels).
2. Body slot (everything to the right of the rail) gets centered + clamped per screen type:
   - Forms: 480-clamped (auth gate, edit profile, create event/task).
   - Lists/feeds: 720-clamped (dashboard events list, tasks list, chat thread).
   - Detail: 960-clamped (event detail, task detail).
   - Markdown: 720-clamped (privacy / terms / privacy-dashboard).
3. Side gutters fill the remaining horizontal space. At 1920 viewport with rail (~256 px) + 720-clamped body, gutters are ~470 px each side — comfortable, not vacuous.
4. Screen-level horizontal padding scales: 24 px on compact/medium, 40 px on expanded+. Bigger viewport gets more breathing room.

**Edge cases:**
- **Resize across breakpoint mid-session.** ResponsiveShell already has a stable `body` Key (`ValueKey('shell.body')`) so route stack + scroll position survive a 840-px crossing. The new clamps are purely layout (no state), so resizing across them is a clean re-flow with no scroll-position loss.
- **Very narrow heights** (Chrome DevTools at 1280×400 simulating a wide-but-short window). Vertical scrolling handles it; clamps are width-only.
- **DPI changes** (Retina vs. low-DPI). `LayoutBuilder` operates on logical pixels; constraints are unchanged.
- **Browser zoom** (Cmd+plus to 200 %). Clamps scale with the viewport. At 200 %-zoomed 1920 → 960 effective; behaves like a small-desktop layout. Acceptable.
</user_flows>

<requirements>

## Functional

1. **`Breakpoints` constants file** at `lib/app/core/constants/breakpoints.dart` exposing Material 3 standard values:
   - `compactMax = 600.0`, `mediumMax = 840.0`, `expandedMax = 1200.0`, `largeMax = 1600.0`.
   - Helper getters/extensions on `BuildContext` are out of scope for V1 (YAGNI — the constants alone suffice).

2. **`ContentMaxWidth` widget** at `lib/app/core/widgets/content_max_width.dart`:
   - Constructor: `const ContentMaxWidth({required this.maxWidth, required this.child, this.alignment = Alignment.topCenter})`.
   - Body: `Align(alignment) > ConstrainedBox(maxWidth: maxWidth) > child`. No conditional logic on viewport — `ConstrainedBox` self-clamps when `maxWidth < availableWidth`.
   - Default `Alignment.topCenter` so scrollable content centers horizontally without vertical-centering surprises.
   - **Why a widget over an inline `Center > ConstrainedBox`:** consistency, single grep target, easy future tweaks (e.g. add semantic `Section` role for accessibility).

3. **Wrap every routed screen body** in `ContentMaxWidth` with the canonical clamp for its category. Sub-widgets imported by these routed pages — `lib/app/features/tasks/presentation/task_list_screen.dart`, `lib/app/features/tasks/presentation/task_detail_screen.dart`, `lib/app/features/chat/presentation/chat_screen.dart` — **must NOT be wrapped separately**. They inherit the clamp from their routed parent (`event_tasks_page.dart`, `event_task_detail_page.dart`, `event_chat_page.dart`); double-wrapping would either be redundant or visually broken (inner-tighter clamp wins, outer is dead code).

   - **Form screens (clamp 480):**
     - `lib/app/features/profile/presentation/edit_profile_screen.dart`
     - `lib/app/features/dashboard/presentation/create_event_screen.dart`
     - `lib/app/features/tasks/presentation/create_task_screen.dart`
   - **List / feed screens (clamp 720):**
     - `lib/app/features/dashboard/presentation/dashboard_screen.dart`
     - `lib/app/features/tasks/presentation/event_tasks_page.dart`
     - `lib/app/features/chat/presentation/event_chat_page.dart`
     - `lib/app/features/profile/presentation/profile_screen.dart` &nbsp;**(see hero special-case below)**
     - `lib/app/features/dashboard/presentation/member_management_screen.dart`
   - **Detail screens (clamp 960):**
     - `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` &nbsp;**(audit for full-bleed hero before wrapping)**
     - `lib/app/features/tasks/presentation/event_task_detail_page.dart`
   - **Markdown reader (clamp 720):**
     - `lib/app/features/profile/presentation/markdown_render_screen.dart`
     - `lib/app/features/profile/presentation/privacy_dashboard_screen.dart`
   - **Already-clamped or out of scope:**
     - `event_budget_page.dart` (clamps at 1600 — leave unchanged).
     - `auth_gate_screen.dart` (clamps at 480 — keep current `ConstrainedBox` or refactor to `ContentMaxWidth` per implementer choice; either is fine).
     - `onboarding_screen.dart` — onboarding is a one-time flow; full-bleed presentation is intentional. Skip clamp.
   - **Sub-widgets imported by routed pages** (do NOT wrap — they inherit the clamp):
     - `task_list_screen.dart`, `task_detail_screen.dart`, `chat_screen.dart`.
   - **Dead code** (defined but not routed; wrap is wasted effort):
     - `event_detail_screen.dart` is defined in `lib/app/features/dashboard/presentation/` but referenced nowhere in `lib/`. Track as a separate cleanup item in `ai_specs/todo.md` ("Delete `event_detail_screen.dart` if `EventDashboardScreen` has fully replaced it; otherwise wire it into the router"). Out of scope for this spec.
   - **Bottom sheets / modal dialogs** (sign_out_sheet, add_member_sheet, join_event_sheet, expense_modal, settle_sheet, dispute_sheet, critical_alert_modal): already overlay-centered with their own width constraints. Skip clamp.

   **Special-case: full-bleed hero patterns.** `ProfileScreen` uses `Scaffold > CustomScrollView > [SliverToBoxAdapter(_HeroCard), SliverPadding(SliverList(...))]`. The `_HeroCard` is a full-viewport-width gradient that's the page's visual signature. **Do not wrap the entire body in `ContentMaxWidth`** — that would shrink the gradient to 720 px on desktop. Instead, clamp only the `SliverPadding` subtree (settings / payment / account / danger zone). Concrete pattern:
   ```dart
   CustomScrollView(
     slivers: [
       SliverToBoxAdapter(child: _HeroCard(user: user)),  // full-bleed
       SliverPadding(
         padding: EdgeInsets.symmetric(
           horizontal: Breakpoints.screenHorizontalPadding(context),
         ),
         sliver: SliverConstrainedCrossAxis(
           maxExtent: 720,
           sliver: SliverList(...),  // clamped
         ),
       ),
     ],
   )
   ```
   Implementer must audit every list / detail screen for similar full-bleed hero patterns before wrapping. `EventDashboardScreen` is the most likely candidate — if it has a hero card or banner, apply the same `SliverConstrainedCrossAxis` pattern at the 960 detail-clamp.

4. **`ResponsiveShell` breakpoint migration** (the `_railBreakpoint` const in `lib/app/core/widgets/responsive_shell.dart`):
   - `_railBreakpoint` 720 → 840.
   - Comment explains the move (Material 3 medium → expanded boundary; tablet portrait belongs to "bar" not "rail" UX).
   - **Existing test must be updated, not just complemented**: `test/app/core/widgets/responsive_shell_test.dart` currently has a "renders NavigationRail at 800 and 1280 widths" test that pumps at `Size(800, 600)` and asserts `findsOneWidget` for `NavigationRail`. After the migration `800 < 840` → bar, not rail → that test fails. The implementer must rewrite this test (split into "renders bar at 800" + "renders rail at 880" + "renders rail at 1280", per the new boundary). The 1280 case stays correct; the 800 case flips expectation; new 880 case is added. See Validation 14.

5. **Screen-level horizontal padding scales at Expanded+ (≥840 px) via a canonical helper.** Different screens currently use different outer-padding tokens (`AppSpacing.lg = 16` in `profile_screen.dart`'s `SliverPadding`, `AppSpacing.xl = 24` in `dashboard_screen.dart`'s `ListView.padding`, etc.). Rather than scaling each token, this spec introduces a single canonical helper that overrides the per-screen choice:

   ```dart
   // lib/app/core/constants/breakpoints.dart
   abstract final class Breakpoints {
     static const double compactMax = 600.0;
     static const double mediumMax = 840.0;
     static const double expandedMax = 1200.0;
     static const double largeMax = 1600.0;

     /// Canonical screen-level outer horizontal padding. Returns 24 px
     /// at compact/medium viewports and 40 px at expanded+. Use this on
     /// every routed page being wrapped per Requirement 3, regardless
     /// of which existing AppSpacing token the page used before.
     static double screenHorizontalPadding(BuildContext context) =>
       MediaQuery.sizeOf(context).width >= mediumMax ? 40.0 : 24.0;
   }
   ```

   Every screen wrapped in `ContentMaxWidth` per (3) replaces its existing outer horizontal padding with `Breakpoints.screenHorizontalPadding(context)`. The 24-px baseline is intentional — it's a clean step-up from the existing 16-px `lg` and matches the existing 24-px `xl` callers, so the change is "neutral or wider" at compact, never narrower. Vertical padding stays at the existing `AppSpacing.xl` (24) value.

   Forms (clamp 480) get this treatment too even though the clamp itself is doing most of the visual work — consistency is more valuable than micro-optimizing the form padding.

6. **Chat bubble width math fix** (`lib/app/features/chat/presentation/widgets/message_bubble.dart:45`):
   - Replace `MediaQuery.sizeOf(context).width * 0.75` with a `LayoutBuilder` constraint scoped to the bubble's parent constraints.
   - Concrete shape:
     ```dart
     LayoutBuilder(builder: (context, constraints) {
       final maxBubbleWidth = constraints.maxWidth * 0.75;
       return ConstrainedBox(
         constraints: BoxConstraints(maxWidth: maxBubbleWidth),
         child: …,
       );
     });
     ```
   - At a 720-px-clamped chat thread, bubbles cap at ~540 px on desktop. On phone (375 viewport), bubbles cap at ~281 px — same as today's `width * 0.75`.

## Error Handling

7. **No new error paths introduced.** Layout work is structural; widget tree changes don't add runtime failure modes.

8. **`ContentMaxWidth` with `maxWidth: double.infinity`** (defensive — should never happen in practice): widget passes the child through unchanged. No assertion error.

## Edge Cases

9. **Breakpoint boundaries** — inclusive-lower-bound convention applied consistently:
    - `width < 600` → Compact.
    - `600 ≤ width < 840` → Medium.
    - `840 ≤ width < 1200` → Expanded. **Tests verify `width = 840` lands on Expanded** (rail; the 720 / 960 / 480 clamps activate when viewport > clamp value).
    - `1200 ≤ width < 1600` → Large. `width ≥ 1600` → Extra-large.
    - The Compact ↔ Medium boundary at 600 is **visually unobservable in this app** because no clamp triggers below 720 (lists clamp at 720 → at any viewport ≤ 720 the body fills). Don't write a test for the 600 boundary; it's a no-op transition for this layout pass. Documented here so future contributors understand the boundary convention is consistent with Material 3.

10. **Resizing across the rail breakpoint mid-session.** `ResponsiveShell` already preserves body identity via `ValueKey('shell.body')`. No additional work needed.

11. **`EventCard` items in the dashboard list become "narrow" (720 px clamp) on desktop.** Acceptable for V1 lite. Multi-column event grid is explicitly out-of-scope and tracked for a future "V1+ web rebuild".

12. **Chat thread with a single very-long message.** Bubble caps at 75 % of clamped width via `LayoutBuilder`; long lines wrap inside. No horizontal overflow.

## Validation

13. **Layout-regression tests** at three viewport classes for at least one representative screen per category:
    - Form: `auth_gate_screen` already covered. Add `edit_profile_screen` at 1280×800 (clamps to 480).
    - List: `dashboard_screen` at 1280×800 (clamps to 720) and 375×812 (fills viewport).
    - Detail: `event_dashboard_screen` at 1280×800 (clamps to 960) and 375×812 (fills).
    - Markdown: `markdown_render_screen` at 1280×800 (clamps to 720). Existing test already exists for content rendering — extend it for clamp.

14. **`ResponsiveShell` breakpoint test migration + additions** (`test/app/core/widgets/responsive_shell_test.dart` exists today):
    - **Update the existing "renders NavigationRail at 800 and 1280 widths" test.** After the breakpoint move (720 → 840), the 800-px assertion would fail (800 < 840 → bar, not rail). Split this test into three:
      - "renders NavigationBar at 800 width" — pumps `Size(800, 1024)`, asserts `find.byType(NavigationBar), findsOneWidget`.
      - "renders NavigationRail at 880 width" (new boundary case) — pumps `Size(880, 1024)`, asserts `find.byType(NavigationRail), findsOneWidget`.
      - "renders NavigationRail at 1280 width" — pumps `Size(1280, 800)`, asserts rail. Existing assertion stays correct since 1280 > 840.
    - The existing "renders NavigationBar below 720 width" test (pumps 600×800) stays correct unchanged (600 < 840 still → bar).

15. **`flutter analyze` clean. `flutter test` green.** Existing 210-test suite must stay passing.

16. **Manual smoke** — Chrome at 375 / 768 / 1280 / 1920 widths after the work lands:
    - Auth gate: 480-clamped at all sizes; footer spans full width.
    - Dashboard: 720-clamped at desktop; full-bleed at phone.
    - Privacy Dashboard → Privacy Policy: markdown body 720-clamped, frontmatter stamps centered above it.
    - Chat thread: bubbles within 75 % of clamped width, not 75 % of viewport.

</requirements>

<boundaries>

**Edge cases:**
- **Viewport exactly 840 px:** Expanded — rail visible, body clamped.
- **Viewport 599 px (just-under Compact boundary):** still Compact category, bottom-bar visible, no clamp needed (viewport narrower than every clamp).
- **Very wide viewport (4K, 3840 px):** body still clamped to per-screen max-width; ~1600 px of side gutter on each side. Acceptable.
- **Very narrow viewport (< 320 px) — pathological resize.** Mobile minimum width per Flutter docs is 320; below that we don't optimize. Existing layout already breaks; not introducing new failure modes.
- **Single-pane chat with a 1080-px image attachment.** `Image.network` with no `width` cap stretches to the bubble's max-width; the new 75 %-of-clamped-width math caps at ~540 px on desktop. Image renders within the bubble.
- **Print stylesheet.** Out of scope. Browser default print view handles legal pages adequately; in-app screens are not designed to print.
- **`DashboardScreen` FAB position at large viewports.** `DashboardScreen` has a `FloatingActionButton` (Create Event) that anchors to the **Scaffold's** bottom-right, not the clamped body's bottom-right. At 1920 viewport with a 720-clamp, the FAB sits ~600 px to the right of the visible content. **Accepted V1 quirk** — fixing this requires either an in-clamp inline "Create event" button (visual departure from the existing FAB pattern) or a `Positioned` overlay aligned to the clamp (more layout machinery). Track in `ai_specs/todo.md` under "Web polish followups" for V1+. Mobile experience is unaffected (FAB anchors correctly when viewport ≤ clamp).

**Error scenarios:**
- **`ContentMaxWidth` rendered with a child wider than `maxWidth` (e.g. a fixed-width child via `SizedBox(width: 1200)` inside a 720-clamp).** The child overflows its parent — Flutter renders an overflow error in debug. Resolution: per-screen `ContentMaxWidth` wraps `Padding > ListView/Column` whose children flex naturally; no fixed-width children today. Tests will catch any regression.
- **Theme switch (light/dark) with a clamped layout.** Theme-aware decorations re-render; clamp is theme-agnostic. No extra work.

**Limits:**
- Per-screen `maxWidth` is a const (480 / 720 / 960 / 1200 / 1600). No runtime override path; if a future screen needs a custom clamp, pass a different `maxWidth` to `ContentMaxWidth`.
- No max-height clamp. Vertical scrolling stays the default.

</boundaries>

<implementation>

**Files to create:**
- `lib/app/core/constants/breakpoints.dart` — Material 3 const values.
- `lib/app/core/widgets/content_max_width.dart` — `ContentMaxWidth` widget.
- `test/app/core/widgets/content_max_width_test.dart` — pure unit test asserting the widget composes `Align + ConstrainedBox` correctly and respects `maxWidth`.

**Files to modify (per-screen body wrap):**
- `lib/app/features/profile/presentation/edit_profile_screen.dart` — wrap body in `ContentMaxWidth(maxWidth: 480)`.
- `lib/app/features/dashboard/presentation/create_event_screen.dart` — clamp 480.
- `lib/app/features/tasks/presentation/create_task_screen.dart` — clamp 480.
- `lib/app/features/dashboard/presentation/dashboard_screen.dart` — clamp 720.
- `lib/app/features/tasks/presentation/event_tasks_page.dart` — clamp 720.
- `lib/app/features/chat/presentation/event_chat_page.dart` — clamp 720.
- `lib/app/features/profile/presentation/profile_screen.dart` — clamp 720 **on the SliverPadding subtree only; `_HeroCard` stays full-bleed**. See Requirement 3 special-case.
- `lib/app/features/dashboard/presentation/member_management_screen.dart` — clamp 720.
- `lib/app/features/dashboard/presentation/event_dashboard_screen.dart` — clamp 960. **Audit for full-bleed hero before wrapping.**
- `lib/app/features/tasks/presentation/event_task_detail_page.dart` — clamp 960.
- `lib/app/features/profile/presentation/markdown_render_screen.dart` — clamp 720.
- `lib/app/features/profile/presentation/privacy_dashboard_screen.dart` — clamp 720.

**Files to modify (other):**
- `lib/app/core/widgets/responsive_shell.dart` — `_railBreakpoint` 720 → 840 + comment + key on the body slot stays.
- `lib/app/features/chat/presentation/widgets/message_bubble.dart:45` — replace viewport-based bubble width with `LayoutBuilder`-constrained 75 %-of-parent.

**Test files (new + extend):**
- `test/app/core/widgets/content_max_width_test.dart` (new) — unit test (above).
- `test/app/features/profile/edit_profile_screen_layout_test.dart` (new) — clamp 480 at 1280×800; fills at 375×812.
- `test/app/features/dashboard/dashboard_screen_layout_test.dart` (new) — clamp 720 at 1280×800; fills at 375×812.
- `test/app/features/dashboard/event_dashboard_screen_layout_test.dart` (new) — clamp 960 at 1280×800.
- `test/app/features/profile/markdown_render_screen_test.dart` (extend existing) — add a clamp assertion at 1280×800.
- `test/app/core/widgets/responsive_shell_test.dart` (existing or new) — add `800×1024` (bar) and `880×1024` (rail) cases. If the file doesn't exist yet, create it following the auth-gate layout test pattern.

**Files to NOT modify:**
- `lib/app/features/auth/presentation/auth_gate_screen.dart` — already clamps at 480. Optional refactor to `ContentMaxWidth` (KISS — leaving the existing `ConstrainedBox` is also fine; either is acceptable).
- `lib/app/features/budget/presentation/event_budget_page.dart` — already clamps at 1600 (intentional for budget tables).
- `lib/app/features/onboarding/presentation/onboarding_screen.dart` — full-bleed by design.
- **`lib/app/features/tasks/presentation/task_list_screen.dart`, `task_detail_screen.dart`, `lib/app/features/chat/presentation/chat_screen.dart`** — sub-widgets imported by routed `event_*_page.dart` siblings. They inherit the clamp from the routed parent. Wrapping them separately would double-wrap.
- **`lib/app/features/dashboard/presentation/event_detail_screen.dart`** — defined but not routed anywhere in `lib/`. Dead code as of writing. Tracked separately in `ai_specs/todo.md`: "Delete `event_detail_screen.dart` if `EventDashboardScreen` has fully replaced it; otherwise wire it into the router." Out of scope for this spec.
- All bottom sheets / modal dialogs — overlay-centered, already constrained.
- All robot tests + journey tests — must remain green; spec is layout-only and shouldn't change finder paths or selectors.

**Patterns to use:**
- Auth-gate clamp pattern (the `Center > ConstrainedBox(maxWidth: 480) > Column` shape inside `auth_gate_screen.dart`) is the visual reference. Extract into `ContentMaxWidth` for reuse.
- Layout-test pattern from `auth_gate_screen_layout_test.dart` (`tester.binding.setSurfaceSize` + `tester.getSize(find.byKey(...))`) is the test reference.
- Stable Keys: each `ContentMaxWidth` body wrapper gets a screen-scoped Key for layout-regression tests, e.g. `Key('dashboard.body.clamped')`.

**What to avoid (and why):**
- **No `LayoutBuilder` at the screen-body level.** `ConstrainedBox` self-clamps without rebuilding the subtree on every resize; `LayoutBuilder` would. Performance + simpler tests.
- **No CSS-style "container queries" via custom resize logic.** Material 3 breakpoints + `ConstrainedBox` are sufficient. Don't introduce a dependency on viewport-aware Riverpod providers — that's premature abstraction.
- **No `FractionallySizedBox`** — too clever, hard to predict at narrow widths. `ConstrainedBox(maxWidth)` is unambiguous.
- **No multi-column dashboards in this pass.** User explicitly chose V1 lite. Adding columns is a separate spec.
- **No hover-state work.** Material 3's defaults are sufficient for V1 lite.

</implementation>

<validation>

**Baseline coverage outcomes:**

- **Unit test** for `ContentMaxWidth`: pumps the widget at multiple parent constraints; asserts the child is wrapped in an `Align` + `ConstrainedBox` with the correct `maxWidth`.
- **Widget tests (layout-regression)** for one representative screen per category:
  - Form clamp at 480: `edit_profile_screen_layout_test.dart` at 1280×800 asserts the body's clamped Key has width ≤ 480; at 375×812 asserts width fills viewport.
  - List clamp at 720: `dashboard_screen_layout_test.dart` at 1280×800 asserts ≤ 720; at 375×812 asserts fills viewport.
  - Detail clamp at 960: `event_dashboard_screen_layout_test.dart` at 1280×800 asserts ≤ 960; at 375×812 fills viewport.
  - Markdown clamp at 720: extend `markdown_render_screen_test.dart` (existing) with a clamp assertion. The existing test does NOT manipulate surface size (it pumps at the default 800×600). The new clamp assertion must explicitly call `await tester.binding.setSurfaceSize(const Size(1280, 800));` and `addTearDown(() async => tester.binding.setSurfaceSize(null));` per the auth-gate-layout-test pattern, so the assertion isn't accidentally satisfied by the default surface and the resize doesn't leak into adjacent tests.
- **Widget tests for `ResponsiveShell` boundary:** add tests at `375×812` (bar), `800×1024` (bar — new boundary verification), `880×1024` (rail — new boundary verification), `1280×800` (rail). Use `find.byKey(Key('shell.bar.dashboard'))` vs. `Key('shell.rail.dashboard')` to differentiate.
- **No new logic = no new business-rule tests.** This is a structural pass.

**TDD expectations** (this is a layout-only feature, so TDD discipline applies but is leaner than a typical state-management feature):

- **Behavior order:**
  1. RED: write the `ContentMaxWidth` unit test asserting the widget clamps at a given `maxWidth`. (Compilation error first cycle — class doesn't exist.)
  2. GREEN: implement `ContentMaxWidth`. Test passes.
  3. RED: write the dashboard layout-regression test at 1280×800 asserting clamp ≤ 720 — fails because the screen body still stretches.
  4. GREEN: wrap dashboard body in `ContentMaxWidth(maxWidth: 720, key: Key('dashboard.body.clamped'))`. Test passes.
  5. Repeat the RED → GREEN cycle once per screen-category test (form, detail, markdown). Within a single category, additional screens get the wrapper as a non-TDD mechanical pass — the category test already proves the pattern.
- **Vertical-slice cycles:** one category per cycle. Don't write all 14 screen wraps before any tests.
- **Testability seams:** `ContentMaxWidth` widget is the seam. Layout-regression tests use stable Keys on the wrapper, not on the screen's internal widget tree. Future screen refactors that don't change the clamp are test-stable.
- **Mocking policy:** no mocks. Layout tests are pure widget tests against the real Flutter tree.
- **Justified exception:** `ResponsiveShell` breakpoint migration (720 → 840) is a pure constant change. The driving test is the new 800×1024 / 880×1024 pair; existing 1280×800 test is regression coverage. Not a strict RED → GREEN cycle since the existing test wasn't broken (1280 > 720 and > 840 both → rail) — flag as "constant-change refactor with new-boundary regression coverage" in the implementation phase.

**Robot-driven journey tests:** **none required for this spec.** This is a layout-only pass; no new user journeys are introduced. Existing journey tests (auth, dashboard, tasks, chat, budget) must continue to pass at their existing surface sizes. If any journey test breaks on the 720→840 ResponsiveShell migration, fix at the test level (not by reverting the breakpoint).

**Test-type mapping:**
- **Unit tests** — `ContentMaxWidth` widget composition.
- **Widget (layout-regression)** — one per screen category × at least two viewport sizes. Reuse the `setSurfaceSize` + `getSize(find.byKey)` pattern.
- **Existing journey tests** — must stay green. No new robot journeys for this spec.

**Manual smoke checklist** (post-merge, pre-ship):
- Open Chrome DevTools → resize the responsive emulator to 375 / 768 / 800 / 880 / 1280 / 1920 widths. At each:
  - Sign in / sign out works.
  - Dashboard, profile, privacy dashboard, chat all render with the expected clamp.
  - ResponsiveShell switches bar ↔ rail at the 840 boundary (between 800 and 880).
  - No horizontal overflow at any viewport.
  - Existing functionality (event create, task create, edit profile, settle) works inside the new clamps.

</validation>

<done_when>

**Code-level gates:**
- `lib/app/core/constants/breakpoints.dart` exports the four Material 3 breakpoints.
- `lib/app/core/widgets/content_max_width.dart` exports the `ContentMaxWidth` widget.
- All 14 listed screens wrap their body content in `ContentMaxWidth` with the canonical clamp for their category.
- `ResponsiveShell._railBreakpoint = 840` (was 720).
- `message_bubble.dart` uses `LayoutBuilder` for bubble width, not `MediaQuery.sizeOf`.
- Screen-level horizontal padding follows the 24 → 40 px pattern at viewports ≥ 840.

**Test-level gates:**
- New unit test for `ContentMaxWidth` green.
- New layout-regression tests for the four screen categories green.
- New `ResponsiveShell` boundary tests at 800 / 880 viewports green.
- All existing tests still green (210+ at the time of writing).
- `flutter analyze` clean.

**Manual smoke gates:**
- Chrome at 1280 × 800: every wrapped screen visibly clamps + centers, side gutters reasonable.
- Chrome at 375 × 812: every wrapped screen renders identically to today (no clamp applied because viewport < clamp).
- Chrome at exactly 800 → 880 sweep: ResponsiveShell flips bar → rail at the 840 boundary, body identity (route + scroll) survives the flip.

**Out-of-scope tracked in `ai_specs/todo.md`:**
- Master-detail layouts (chat list + thread, events list + detail).
- Multi-column dashboard / desktop tables for budget + tasks.
- Hover affordances, keyboard shortcuts, right-click menus.
- Visual redesign (Linear/Notion-style minimalism) if/when prioritized.
- Multi-column event card grid on the dashboard at desktop widths.
- **DashboardScreen FAB position at large viewports** — FAB anchors to Scaffold's bottom-right (full viewport), not to the clamped body. ~600 px offset from visible content at 1920 viewport. Defer to V1+ (inline "Create event" button OR `Positioned` overlay).
- **`event_detail_screen.dart` cleanup** — file is defined but never routed. Either delete it (preferred if `EventDashboardScreen` fully replaces it) or wire it into the router. Decide before next major refactor.

</done_when>
