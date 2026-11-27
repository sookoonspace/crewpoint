import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/features/registration/domain/committee.dart';

/// #249: what the summary and a group's registration work out.
void main() {
  test('the summary reads counts, not-confirmed totals and how far over', () {
    final s = RegistrationSummary.fromMap(const {
      'byStatus': {
        'submitted': {'groups': 3, 'people': 6},
        'pending': {'groups': 1, 'people': 2},
        'waitlisted': {'groups': 2, 'people': 5},
        'draft': {'groups': 4, 'people': null},
      },
      'capacity': 5,
      'placesUsed': 8,
    });
    expect(s.count('cancelled'), (groups: 0, people: 0));
    expect(s.count('draft'), (groups: 4, people: null));
    expect(s.notConfirmed, (groups: 7, people: 7));
    expect(s.over, 3);
  });

  test('actions follow the status: approve only when pending, reinstate '
      'when waiting or cancelled', () {
    GroupRegistration r(String status) =>
        GroupRegistration(registrationId: 'r', status: status);
    expect(r('pending').actions(review: true), [
      RegistrationAction.approve,
      RegistrationAction.waitlist,
    ]);
    expect(r('submitted').actions(review: true), [RegistrationAction.waitlist]);
    expect(r('cancelled').actions(review: true), [
      RegistrationAction.reinstate,
    ]);
    expect(r('draft').actions(review: true), isEmpty);
    expect((r('cancelled').canCancel, r('draft').canResend), (false, false));
  });
}
