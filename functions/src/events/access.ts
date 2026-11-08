import {computePermissions, legacyRoleIds} from "./permissions";

/**
 * What the server needs to know about one member to decide what they may
 * read. It mirrors `firestore.rules`, so pushes and summaries never tell
 * someone about a record they could not open (Req 32).
 */
export interface MemberAccess {
  uid: string;
  roleIds: readonly string[];
  permissions: readonly unknown[];
}

/**
 * Adding your own expense and creating tasks are open to every member
 * except those holding only Observer or Vendor (Req 34).
 */
export function contributesWith(roleIds: readonly string[]): boolean {
  return roleIds.some((r) => r !== "observer" && r !== "vendor");
}

/** Reading chat needs `chat.send` (Req 32). */
export function readsChat(member: MemberAccess): boolean {
  return member.permissions.includes("chat.send");
}

/**
 * Vendors and Observers read only expenses they paid or share in, unless
 * their role holds `money.read` or `expenses.readAll` (Req 32).
 */
export function readsExpense(
  member: MemberAccess,
  expense: FirebaseFirestore.DocumentData
): boolean {
  return (
    contributesWith(member.roleIds) ||
    member.permissions.includes("money.read") ||
    member.permissions.includes("expenses.readAll") ||
    expense.payerId === member.uid ||
    (Array.isArray(expense.involvedUids) &&
      expense.involvedUids.includes(member.uid))
  );
}

/**
 * Everyone in the event with their roles and permissions, from member
 * documents, or from the old arrays on an event not yet migrated.
 */
export async function readAllAccess(
  eventRef: FirebaseFirestore.DocumentReference,
  eventData: FirebaseFirestore.DocumentData
): Promise<MemberAccess[]> {
  const snapshot = await eventRef.collection("members").get();
  if (!snapshot.empty) {
    return snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        uid: doc.id,
        roleIds: Array.isArray(data.roleIds) ? data.roleIds : [],
        permissions: Array.isArray(data.permissions) ? data.permissions : [],
      };
    });
  }
  return ((eventData.memberIds ?? []) as string[]).map((uid) => {
    const roleIds = legacyRoleIds(eventData, uid);
    return {uid, roleIds, permissions: computePermissions(roleIds, {})};
  });
}
