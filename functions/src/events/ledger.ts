/**
 * Balances for an event, worked out the same way as the app's
 * `BalanceLedger` (lib/app/features/budget/domain/models/balance_ledger.dart),
 * so someone reading only part of the expenses sees the same figures (Req
 * 38c). Keep the two in step.
 */
export interface LedgerExpense {
  payerId: string;
  amount: number;
  isPayment?: boolean;
  isDonation?: boolean;
  splits?: {userId: string; amount: number}[];
}

export interface Transfer {
  fromUserId: string;
  toUserId: string;
  amount: number;
}

export interface Ledger {
  /** Positive is owed money, negative owes money. */
  netBalances: Record<string, number>;
  /** The fewest transfers that settle everything. */
  settlements: Transfer[];
}

const round = (value: number) => Math.round(value * 100) / 100;

export function calculateLedger(
  expenses: readonly LedgerExpense[],
  memberIds: readonly string[]
): Ledger {
  const balances = new Map<string, number>(memberIds.map((id) => [id, 0]));
  const add = (uid: string, amount: number) =>
    balances.set(uid, (balances.get(uid) ?? 0) + amount);

  for (const expense of expenses) {
    add(expense.payerId, expense.amount);
    const splits = expense.splits ?? [];
    if (expense.isPayment) {
      // Settlements recorded before the sign fix store a negative payee split.
      for (const s of splits) add(s.userId, -Math.abs(s.amount));
      continue;
    }
    const shares = splits.length > 0 ? splits : equalSplits(expense, memberIds);
    for (const s of shares) add(s.userId, -s.amount);
  }

  const netBalances: Record<string, number> = {};
  for (const [uid, value] of balances) netBalances[uid] = round(value);
  return {netBalances, settlements: simplify(netBalances)};
}

function equalSplits(
  expense: LedgerExpense,
  memberIds: readonly string[]
): {userId: string; amount: number}[] {
  const sharing = expense.isDonation ?
    memberIds.filter((id) => id !== expense.payerId) :
    memberIds;
  if (sharing.length === 0) return [];
  const share = expense.amount / sharing.length;
  return sharing.map((userId) => ({userId, amount: share}));
}

/** Greedy: the largest debtor pays the largest creditor, until settled. */
function simplify(balances: Record<string, number>): Transfer[] {
  const creditors = new Map<string, number>();
  const debtors = new Map<string, number>();
  for (const [uid, value] of Object.entries(balances)) {
    if (value > 0.01) creditors.set(uid, value);
    else if (value < -0.01) debtors.set(uid, -value);
  }
  const largest = (m: Map<string, number>) =>
    [...m.entries()].reduce((a, b) => (a[1] >= b[1] ? a : b));
  const transfers: Transfer[] = [];
  while (creditors.size > 0 && debtors.size > 0) {
    const [to, owed] = largest(creditors);
    const [from, owes] = largest(debtors);
    const amount = Math.min(owed, owes);
    transfers.push({fromUserId: from, toUserId: to, amount: round(amount)});
    creditors.set(to, owed - amount);
    debtors.set(from, owes - amount);
    if (creditors.get(to)! < 0.01) creditors.delete(to);
    if (debtors.get(from)! < 0.01) debtors.delete(from);
  }
  return transfers;
}
