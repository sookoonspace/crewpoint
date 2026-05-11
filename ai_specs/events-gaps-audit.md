# Events Feature — Gaps Audit

Companion report to `tasks-polish-spec.md`. Not a spec; a snapshot of what the events feature does and doesn't cover, so the next round of prioritization has somewhere to start.

## Summary

The events feature has a solid skeleton — create (already Firestore-write + Drift-mirror) / dashboard / member management / invite / join / leave / archive (toggle UI, not wired) / delete — but several editing and observability surfaces are missing or only half-implemented. The currently-in-flight `tasks-polish-spec.md` closes the highest-friction gaps (no way to edit an event after creation, no real assignee names on tasks, no expense edit/delete, no Firestore rule for expense updates). Everything else below is captured for a later sweep.

## Closed by `tasks-polish-spec.md`

- Settings gear icon on `EventDashboardScreen` (`event_dashboard_screen.dart:189`) — currently a no-op; will route to a new `EditEventScreen`.
- No edit-event screen — adding one with title, description, start/end dates, eventType, and archive status editable. Currency stays immutable (data-integrity boundary — `ExpenseModel.amount` is currency-agnostic; changing event currency post-expenses would silently corrupt the ledger).
- End-date was never collected on event create (`CreateEventScreen` only has `_startDate`) — `EditEventScreen` introduces the picker + validator. Backfilling onto create is deferred.
- `EventRepository.updateEvent` method — new. The rest of the events repo write path was already Firestore-write + Drift-mirror; this just adds the missing mutation.
- Archive toggle on the dashboard (`event_dashboard_screen.dart:542–558`) was `// TODO: Update event status via Firestore` — converges onto the new `updateEvent` path.
- Settings-gear visibility used `event.isAdmin(event.creatorId)` (coincidence-only correctness) — tightened to check the current viewer's UID.
- Assignee dropdown + task detail showed truncated UIDs instead of display names — hydrated via existing `usersByIdProvider`.
- Tasks had no budget field — adding optional `budgetEstimate` (display-only, locale-aware input).
- Tasks had no edit screen, only delete — adding `EditTaskScreen` with full RBAC parity.
- Task tiles all looked the same — adding a 4px status color stripe (flush with the card edge via `Clip.antiAlias`).
- Expenses had no edit/delete UI despite repository support — adding `PopupMenuButton` on `ExpenseTile` (callbacks-from-parent for RBAC), with Edit hidden on settlement payments.
- Firestore rules blocked expense updates entirely (`allow update: if false`) and excluded admins from expense delete — both fixed by the spec.

## Open gaps

Each line ends with rough effort estimate. Effort is "engineer-days" for a single mid-skilled Flutter dev, not calendar days.

### Editing & ownership

- **Transfer ownership.** `promoteToAdmin` / `removeEventMember` Cloud Functions exist; no equivalent for handing the `creatorId` baton. Today the only way to leave as owner is to delete the event. — **2d**
- **Event settings screen** (vs scattered switches). After `EditEventScreen` lands there will be: settings gear → edit screen, dashboard switch → archive, dashboard tile → delete, dashboard tile → leave. A real "Settings" tab consolidating these is overdue. — **2d**
- **Bulk member management actions.** `member_management_screen.dart` supports per-member promote/demote/remove, but no bulk select. Low priority unless rosters grow. — **3d**

### Observability & history

- **Audit log / change history.** Nothing tracks who edited what, when, in any entity (event, task, expense). Useful for trip disputes. — **5d** (new collection + UI; touches Cloud Functions for write-amp).
- **Event-level activity feed.** No "Bo added a task", "Pat settled $25 with Alex" timeline. Adjacent to chat but not the same surface. — **4d**
- **Per-event notification preferences.** FCM exists for urgent chat (per `tasks-budget-chat-plan.md` Phase 8), but no per-event mute/urgent-only toggle. — **3d**

### Discovery & lifecycle

- **Event templates / duplicate.** No way to copy an event's members + settings to a new one. Power users with recurring trips will ask. — **2d**
- **Recurring events.** Out of scope for V1 by design; capture here so it's not forgotten. — **5d+**.
- **Cover image** for an event. Currently only an `eventType` badge. — **2d** (uses existing image_picker + Firebase Storage path).
- **Per-event timezone.** Dates use device local. Cross-timezone trips display inconsistently across members. — **3d** (model + render + DST edge cases).
- **Calendar export (ICS).** No way to add an event or its tasks' due dates to a personal calendar. — **2d**.

### Quality & polish

- **`EventDetailScreen` is a near-stub.** (`event_detail_screen.dart`). The dashboard hub is `EventDashboardScreen`; the detail screen is barely referenced. Audit whether it should be deleted or merged. — **0.5d** audit, **1d** if any consumer turns up.
- **No empty-state polish** when an event has no members/tasks/expenses beyond default Material widgets. — **1d** sweep.
- **No event archive UX path** for the dashboard list view (you can only archive from inside the event). — **1d**.

## Recommended next pick

If picking one item next, **Per-event notification preferences** (3d) — completes the chat-notifications story already shipped, low schema risk, immediate user-visible value.

If picking two, add **Cover image** (2d) — independent vector, high perceived polish, reuses image_picker + Storage flow already in Budget receipts.

Defer the audit log / activity feed pair until at least one of those gets requested by a real user; both are expensive without a forcing function.
