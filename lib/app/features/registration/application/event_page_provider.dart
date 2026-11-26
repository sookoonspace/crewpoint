import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/web/embedded_event.dart';
import 'package:crewpoint_app/app/features/registration/domain/public_event.dart';

/// Reads the public view the server put in the first page for a slug, once
/// (`#cp-event`, web only), or null.
typedef EmbeddedEventSource = Map<String, dynamic>? Function(String slug);

/// The first page's embedded view; tests replace it.
final embeddedEventSourceProvider = Provider<EmbeddedEventSource>(
  (_) => takeEmbeddedEvent,
);

/// The public event page for a slug (#240). On the first load of
/// `/e/:eventSlug` on the web, the view the server put in the first page
/// shows at once, without waiting for App Check and `getEventPage` (Req 69
/// speed budget); otherwise it is read once through `getEventPage`. A
/// failure is shown at once, never retried on its own, since retrying
/// would count against the address's rate limit; Retry invalidates it,
/// which asks the server.
final eventPageProvider = FutureProvider.autoDispose
    .family<PublicEvent, String>((ref, slug) {
      final embedded = ref.read(embeddedEventSourceProvider)(slug);
      if (embedded != null) return PublicEvent.fromMap(embedded);
      return ref.watch(memberCallsProvider).getEventPage(slug);
    }, retry: (_, _) => null);
