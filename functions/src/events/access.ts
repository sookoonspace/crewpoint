import {computePermissions, legacyRoleIds} from "./permissions";
import {expenseAccessOf, readsAllExpensesUnder} from "./expenseAccess";

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
 * Whether [member] may read [expense] (Req 38): with `money.read`, or
 * `expenses.readAll`, which the event's expense access setting puts on member
 * documents, or as its payer or someone in its split.
 */
export function readsExpense(
  member: MemberAccess,
  expense: FirebaseFirestore.DocumentData
): boolean {
  return (
    readsAllExpenses(member) ||
    expense.payerId === member.uid ||
    (Array.isArray(expense.involvedUids) &&
      expense.involvedUids.includes(member.uid))
  );
}

/** Whether [member] reads every expense in the event (Req 38). */
export function readsAllExpenses(member: MemberAccess): boolean {
  return member.permissions.includes("money.read") ||
    member.permissions.includes("expenses.readAll");
}

/**
 * Whether a chat notice may show a money amount (Req 38f): only when
 * everyone who can read chat can read every expense. Under Everyone that
 * holds unless an Observer or Vendor was given chat.
 */
export function chatShowsAmounts(members: readonly MemberAccess[]): boolean {
  return members.filter(readsChat).every(readsAllExpenses);
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
  const access = expenseAccessOf(eventData);
  return ((eventData.memberIds ?? []) as string[]).map((uid) => {
    const roleIds = legacyRoleIds(eventData, uid);
    const permissions = computePermissions(roleIds, {}, {
      readsAllExpenses: readsAllExpensesUnder(access, uid, roleIds),
    });
    return {uid, roleIds, permissions};
  });
}
