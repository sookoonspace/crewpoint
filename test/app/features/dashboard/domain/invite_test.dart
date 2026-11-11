import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/invite.dart';

/// Req 47, 56: the invite link, and the expiries an organizer can pick,
/// up to a whole registration period. Pure.
void main() {
  final now = DateTime.utc(2026, 11, 10, 12);
  EventModel event({DateTime? start, DateTime? end, bool dateOnly = true}) =>
      EventModel(
        id: 'e1',
        title: 'Convention',
        creatorId: 'owner',
        startDate: start,
        endDate: end,
        dateOnly: dateOnly,
        timeZone: 'America/Chicago',
      );

  test('the link opens /join/:code on this flavor’s web app', () {
    expect(
      inviteLink('ABC234', flavor: AppFlavor.prod),
      'https://crewpoint.sookoon.space/join/ABC234',
    );
    expect(
      inviteLink('ABC234', flavor: AppFlavor.dev),
      'https://crewpoint-dev.web.app/join/ABC234',
    );
  });

  test('fixed lengths count from now', () {
    expect(
      inviteExpiryFor(InviteExpiry.day, null, now),
      now.add(const Duration(days: 1)),
    );
    expect(
      inviteExpiryFor(InviteExpiry.week, null, now),
      now.add(const Duration(days: 7)),
    );
    expect(
      inviteExpiryFor(InviteExpiry.month, null, now),
      now.add(const Duration(days: 30)),
    );
  });

  test('until the event starts or ends, where the event is', () {
    final e = event(
      start: DateTime.utc(2027, 7, 16),
      end: DateTime.utc(2027, 7, 18),
    );
    expect(
      inviteExpiryFor(InviteExpiry.eventStart, e, now),
      DateTime.utc(2027, 7, 16, 5),
    );
    // The whole last day counts.
    expect(
      inviteExpiryFor(InviteExpiry.eventEnd, e, now),
      DateTime.utc(2027, 7, 19, 5),
    );
    final timed = event(start: DateTime.utc(2027, 5, 1, 15), dateOnly: false);
    expect(
      inviteExpiryFor(InviteExpiry.eventStart, timed, now),
      DateTime.utc(2027, 5, 1, 15),
    );
  });

  test('event choices are offered only when the date is ahead', () {
    final past = event(
      start: DateTime.utc(2026, 1, 1),
      end: DateTime.utc(2026, 1, 2),
    );
    expect(inviteExpiryFor(InviteExpiry.eventStart, past, now), isNull);
    expect(inviteExpiryFor(InviteExpiry.eventEnd, past, now), isNull);
    expect(inviteExpiryFor(InviteExpiry.eventStart, event(), now), isNull);
    expect(inviteExpiryChoices(past, now), [
      InviteExpiry.day,
      InviteExpiry.week,
      InviteExpiry.month,
    ]);
  });

  test('never beyond the longest an invite can last', () {
    final far = event(start: DateTime.utc(2030, 1, 1));
    expect(
      inviteExpiryFor(InviteExpiry.eventStart, far, now),
      now.add(const Duration(days: maxInviteDays)),
    );
  });

  test('a picked date lasts to the end of that day', () {
    expect(
      expiryOnDate(DateTime(2027, 3, 31), now),
      DateTime(2027, 3, 31, 23, 59),
    );
    expect(
      expiryOnDate(DateTime(2029, 1, 1), now),
      now.add(const Duration(days: maxInviteDays)),
    );
  });
}
