import 'package:crewpoint_app/app/core/format/event_date_range.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/budget/application/global_balance_ledger_provider.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  EventModel event(String id, String zone, String currency) => EventModel(
    id: id,
    title: id,
    creatorId: 'bob',
    memberIds: const ['me', 'bob'],
    timeZone: zone,
    currency: currency,
    dateOnly: true,
    startDate: storedCalendarDate(DateTime(2027, 7, 17)),
    endDate: storedCalendarDate(DateTime(2027, 7, 20)),
  );
  final chicago = event('chicago', 'America/Chicago', 'USD');
  final tokyo = event('tokyo', 'Asia/Tokyo', 'JPY');

  test('GE-07 events in different zones show their chosen dates', () {
    String dates(EventModel e) =>
        formatEventDateRange(e.displayStart, e.displayEnd, now: DateTime(2027));
    expect(dates(chicago), 'Jul 17 – Jul 20');
    expect(dates(tokyo), 'Jul 17 – Jul 20');
  });

  test('GE-07 the same moment reads differently in each event', () {
    final moment = DateTime.utc(2027, 7, 17, 23, 30);
    expect(chicago.calendarDay(moment), DateTime(2027, 7, 17));
    expect(tokyo.calendarDay(moment), DateTime(2027, 7, 18));
  });

  test('GE-07 an event is past only when its own last day is over', () {
    final moment = DateTime.utc(2027, 7, 20, 15, 30);
    expect(tokyo.isPast(moment), isTrue);
    expect(chicago.isPast(moment), isFalse);
  });

  test('GE-07 different currencies are totalled apart', () async {
    final container = ProviderContainer(
      overrides: [
        dashboardEventsProvider.overrideWith(
          (_) => Stream.value([chicago, tokyo]),
        ),
        usersByIdProvider.overrideWith((_, _) async => const {}),
        expenseListProvider.overrideWith(
          (_, eventId) => Stream.value([
            ExpenseModel(
              id: 'x-$eventId',
              eventId: eventId,
              payerId: 'bob',
              amount: 100,
              splits: const [
                ExpenseSplit(userId: 'bob', amount: 50),
                ExpenseSplit(userId: 'me', amount: 50),
              ],
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(globalBalanceLedgerProvider('me'), (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    final totals = sub.read().requireValue.totalsByCurrency;
    expect(totals['USD']!.youOwe, 50);
    expect(totals['JPY']!.youOwe, 50);
    expect(totals, hasLength(2));
  });
}
