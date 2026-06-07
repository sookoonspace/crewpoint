/**
 * Unit-level guard for the dispute-recipient selection logic.
 *
 * The CF deletes the original settlement expense before notifying, so
 * the trigger has to reconstruct the counterparty from `payerId` +
 * `payeeId` snapshots stored on the dispute chat notice. Pin the
 * "counterparty of disputer" semantic so that future schema renames
 * don't silently flip the recipient.
 */
import {pickDisputeRecipient} from '../../src/events/onSettlementDisputed';

describe('pickDisputeRecipient', () => {
  test('debtor (payer) disputing notifies the creditor (payee)', () => {
    const result = pickDisputeRecipient('debtor', 'debtor', 'creditor');
    expect(result).toBe('creditor');
  });

  test('creditor (payee) disputing notifies the debtor (payer)', () => {
    const result = pickDisputeRecipient('creditor', 'debtor', 'creditor');
    expect(result).toBe('debtor');
  });

  test('returns null when disputer is neither payer nor payee', () => {
    // Defensive — the callable enforces this at the auth layer but the
    // trigger shouldn't crash if a malformed notice doc gets in.
    const result = pickDisputeRecipient('outsider', 'debtor', 'creditor');
    expect(result).toBeNull();
  });
});
