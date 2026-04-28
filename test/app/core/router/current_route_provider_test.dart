import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/router/current_route_provider.dart';

void main() {
  test('starts as null and reflects subsequent set() calls', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(currentRouteProvider), isNull);

    container
        .read(currentRouteProvider.notifier)
        .set('/dashboard/event/e1/chat');
    expect(
      container.read(currentRouteProvider),
      equals('/dashboard/event/e1/chat'),
    );

    container.read(currentRouteProvider.notifier).set('/dashboard');
    expect(container.read(currentRouteProvider), equals('/dashboard'));
  });
}
