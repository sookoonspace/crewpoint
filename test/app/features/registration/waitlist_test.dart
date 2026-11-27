import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/registration/domain/my_registration.dart';
import 'package:crewpoint_app/app/features/registration/domain/waitlist.dart';

/// #248: what the waitlist screen and my registration work out.
void main() {
  WaitlistView view(int? capacity, int used, int held) => WaitlistView.fromMap({
    'capacity': capacity,
    'placesUsed': used,
    'held': held,
    'waiting': const [
      {'registrationId': 'r1', 'groupName': 'Shahs', 'size': 2, 'position': 1},
    ],
  });

  test('free places, how far over, and whether a group fits', () {
    final v = view(10, 7, 1);
    expect((v.free, v.over, v.fits(v.waiting.single)), (2, 0, true));
    expect(view(10, 8, 1).fits(view(10, 8, 1).waiting.single), isFalse);
    expect((view(6, 8, 0).over, view(6, 8, 0).free), (2, 0));
    expect((view(null, 8, 0).free, view(null, 8, 0).over), (null, 0));
  });

  test('a place is on offer only while waitlisted and before it runs out', () {
    final now = DateTime.utc(2027, 2, 1);
    MyRegistration r(String status, DateTime? until) =>
        MyRegistration(status: status, offerExpiresAt: until);
    expect(r('waitlisted', now.add(const Duration(hours: 1))).offeredAt(now), isTrue);
    expect(r('waitlisted', now).offeredAt(now), isFalse);
    expect(r('waitlisted', null).offeredAt(now), isFalse);
    expect(r('submitted', now.add(const Duration(hours: 1))).offeredAt(now), isFalse);
  });
}
