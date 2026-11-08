/**
 * Req 38c: the server works out balances the same way as the app's
 * `BalanceLedger`, so someone with limited access sees the same figures.
 */
import {calculateLedger} from '../../src/events/ledger';

const split = (userId: string, amount: number) => ({userId, amount});

test('payers are owed, people in a split owe, and it adds up to zero', () => {
  const ledger = calculateLedger([
    {payerId: 'a', amount: 30, splits: [split('a', 10), split('b', 10), split('c', 10)]},
  ], ['a', 'b', 'c']);
  expect(ledger.netBalances).toEqual({a: 20, b: -10, c: -10});
  expect(ledger.settlements).toEqual([
    {fromUserId: 'b', toUserId: 'a', amount: 10},
    {fromUserId: 'c', toUserId: 'a', amount: 10},
  ]);
});

test('a payment reduces what is owed, including older negative payee splits', () => {
  const ledger = calculateLedger([
    {payerId: 'a', amount: 20, splits: [split('a', 10), split('b', 10)]},
    {payerId: 'b', amount: 4, isPayment: true, splits: [split('a', 4)]},
    {payerId: 'b', amount: 1, isPayment: true, splits: [split('a', -1)]},
  ], ['a', 'b']);
  expect(ledger.netBalances).toEqual({a: 5, b: -5});
});

test('an expense with no splits is shared by every member, and a donation leaves out the payer', () => {
  expect(calculateLedger([{payerId: 'a', amount: 30, splits: []}], ['a', 'b', 'c']).netBalances)
    .toEqual({a: 20, b: -10, c: -10});
  expect(calculateLedger([{payerId: 'a', amount: 30, isDonation: true, splits: []}], ['a', 'b', 'c']).netBalances)
    .toEqual({a: 30, b: -15, c: -15});
});

test('rounds to cents and ignores anything under a cent', () => {
  const ledger = calculateLedger([
    {payerId: 'a', amount: 10, splits: [split('a', 3.333), split('b', 3.333), split('c', 3.334)]},
  ], ['a', 'b', 'c']);
  expect(ledger.netBalances).toEqual({a: 6.67, b: -3.33, c: -3.33});
  expect(calculateLedger([], ['a']).settlements).toEqual([]);
});
