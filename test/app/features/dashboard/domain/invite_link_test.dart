import 'package:crewpoint_app/app/features/dashboard/domain/models/invite.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spec #233 Req 15 (#238): the same states `inviteState.ts` gives.
void main() {
  final now = DateTime(2027, 1, 10, 12);
  final later = now.add(const Duration(hours: 1));
  final earlier = now.subtract(const Duration(hours: 1));

  InviteLink link({
    DateTime? expiresAt,
    bool singleUse = false,
    DateTime? usedAt,
    DateTime? turnedOffAt,
    String code = 'ABC234',
  }) => InviteLink(
    code: code,
    roleId: 'participant',
    expiresAt: expiresAt,
    singleUse: singleUse,
    usedAt: usedAt,
    turnedOffAt: turnedOffAt,
  );

  test('active before expiry, and with no expiry at all', () {
    expect(link(expiresAt: later).stateAt(now), InviteLinkState.active);
    expect(link().stateAt(now), InviteLinkState.active);
  });

  test('expired at and after its expiry', () {
    expect(link(expiresAt: now).stateAt(now), InviteLinkState.expired);
    expect(link(expiresAt: earlier).stateAt(now), InviteLinkState.expired);
  });

  test('a single-use link is used once used, even after it expires', () {
    expect(
      link(expiresAt: later, singleUse: true).stateAt(now),
      InviteLinkState.active,
    );
    expect(
      link(expiresAt: earlier, singleUse: true, usedAt: earlier).stateAt(now),
      InviteLinkState.used,
    );
  });

  test('turned off wins over everything', () {
    expect(
      link(
        expiresAt: earlier,
        singleUse: true,
        usedAt: earlier,
        turnedOffAt: earlier,
      ).stateAt(now),
      InviteLinkState.off,
    );
  });

  test('reads what listInviteLinks returns, with defaults for old invites', () {
    final parsed = InviteLink.fromMap({
      'code': 'XYZ789',
      'roleId': 'volunteer',
      'expiresAt': later.millisecondsSinceEpoch,
      'singleUse': true,
      'uses': 1,
      'usedAt': earlier.millisecondsSinceEpoch,
      'turnedOffAt': null,
    });
    expect(parsed.code, 'XYZ789');
    expect(parsed.roleId, 'volunteer');
    expect(parsed.expiresAt, later);
    expect(parsed.stateAt(now), InviteLinkState.used);
    final old = InviteLink.fromMap({'code': 'OLD234'});
    expect(old.roleId, 'participant');
    expect(old.singleUse, isFalse);
    expect(old.uses, 0);
  });

  test('usable links come first, keeping the order within each part', () {
    final sorted = usableFirst([
      link(code: 'OFF111', turnedOffAt: earlier),
      link(code: 'NEW222', expiresAt: later),
      link(code: 'OLD333', expiresAt: earlier),
      link(code: 'NEW444', expiresAt: later),
    ], now);
    expect(sorted.map((l) => l.code), ['NEW222', 'NEW444', 'OFF111', 'OLD333']);
  });
}
