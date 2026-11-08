/**
 * The permission catalogue (Req 26). Stage 1 enforces those whose features
 * exist, and later stages use the rest.
 */
export const PERMISSIONS = [
  "event.manage",
  "event.transfer",
  "members.manage",
  "roles.manage",
  "schedule.edit",
  "updates.send",
  "participants.read",
  "participants.edit",
  "participants.readPrivate",
  "participants.import",
  "group.readOwn",
  "group.editOwn",
  "registrations.manage",
  "money.read",
  "money.record",
  "money.refund",
  "money.dueAtDoor",
  "budget.read",
  "budget.edit",
  "expenses.readAll",
  "contributions.manage",
  "tasks.manage",
  "chat.send",
  "chat.urgent",
  "messages.send",
  "checkin.scan",
  "checkin.lookup",
  "counts.read",
  "incidents.report",
  "incidents.receive",
  "reports.export",
  "competition.manage",
  "scores.enter",
] as const;

export type Permission = (typeof PERMISSIONS)[number];

export interface RoleDefinition {
  name: string;
  permissions: readonly Permission[];
}

const allExcept = (...out: Permission[]): Permission[] =>
  PERMISSIONS.filter((p) => !out.includes(p));

/** Every preset includes `group.readOwn` (Req 26b). */
const preset = (name: string, permissions: Permission[]): RoleDefinition => ({
  name,
  permissions: [...new Set<Permission>([...permissions, "group.readOwn"])],
});

/**
 * Built-in presets (Req 26a). Organizers may edit them per event, and add
 * custom roles, in `events/{id}/roles/{roleId}`. Vendors get only what
 * Req 32 gives them, and Observers only read the event and its schedule,
 * which every member can do without a permission.
 */
export const PRESET_ROLES: Record<string, RoleDefinition> = {
  owner: preset("Owner", [...PERMISSIONS]),
  coOwner: preset("Co-owner", allExcept("event.transfer")),
  admin: preset("Admin", allExcept("event.transfer", "roles.manage")),
  finance: preset("Finance", [
    "money.read",
    "money.record",
    "money.refund",
    "budget.read",
    "budget.edit",
    "expenses.readAll",
    "contributions.manage",
    "participants.read",
    "counts.read",
    "reports.export",
    "chat.send",
  ]),
  crewLead: preset("Crew lead", [
    "tasks.manage",
    "schedule.edit",
    "updates.send",
    "participants.read",
    "participants.edit",
    "money.dueAtDoor",
    "counts.read",
    "chat.send",
    "chat.urgent",
    "messages.send",
    "incidents.report",
    "incidents.receive",
  ]),
  crewMember: preset("Crew member", [
    "updates.send",
    "participants.read",
    "money.dueAtDoor",
    "counts.read",
    "chat.send",
    "incidents.report",
    "incidents.receive",
  ]),
  volunteer: preset("Volunteer", [
    "checkin.scan",
    "checkin.lookup",
    "money.dueAtDoor",
    "incidents.report",
    "chat.send",
  ]),
  scorer: preset("Scorer", ["scores.enter", "chat.send"]),
  vendor: preset("Vendor", []),
  sponsor: preset("Sponsor", ["chat.send"]),
  participant: preset("Participant", ["chat.send"]),
  observer: preset("Observer", []),
};

/** Role documents an event holds, keyed by role ID. */
export type EventRoles = Record<string, {permissions?: unknown}>;

/**
 * What one role grants: the event's own version of it if there is one, which
 * covers edited presets and custom roles, or else the built-in preset.
 */
export function rolePermissions(
  roleId: string,
  eventRoles: EventRoles
): readonly unknown[] {
  const own = eventRoles[roleId]?.permissions;
  if (Array.isArray(own)) return own;
  return PRESET_ROLES[roleId]?.permissions ?? [];
}

/**
 * A member's permissions: the union of their roles, in catalogue order.
 * Names outside the catalogue are dropped. A group's contact and its linked
 * adults also get `group.editOwn`, whatever their role (Req 26b), and the
 * event's expense access setting can add `expenses.readAll` (Req 38).
 */
export function computePermissions(
  roleIds: readonly string[],
  eventRoles: EventRoles,
  {
    editsOwnGroup = false,
    readsAllExpenses = false,
  }: {editsOwnGroup?: boolean; readsAllExpenses?: boolean} = {}
): Permission[] {
  const granted = new Set<unknown>();
  if (editsOwnGroup) granted.add("group.editOwn");
  if (readsAllExpenses) granted.add("expenses.readAll");
  for (const id of roleIds) {
    rolePermissions(id, eventRoles).forEach((p) => granted.add(p));
  }
  return PERMISSIONS.filter((p) => granted.has(p));
}

/**
 * Roles from the old arrays: the creator is Owner, admins are Admin, and
 * everyone else is Participant. Used by the migration, and by callables
 * reading an event that has not been migrated yet.
 */
export function legacyRoleIds(
  event: FirebaseFirestore.DocumentData,
  uid: string
): string[] {
  if (event.creatorId === uid) return ["owner"];
  if ((event.adminIds ?? []).includes(uid)) return ["admin"];
  if ((event.memberIds ?? []).includes(uid)) return ["participant"];
  return [];
}

/**
 * Roles that count as admins in the old `adminIds` array, which stays in step
 * with member documents until it is removed.
 */
export function isAdminLevel(roleIds: readonly string[]): boolean {
  return roleIds.some((r) => r === "owner" || r === "coOwner" || r === "admin");
}
