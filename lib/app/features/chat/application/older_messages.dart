import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/chat/domain/chat_window.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Older chat messages loaded so far, oldest first (Req 57).
@immutable
class OlderMessages {
  const OlderMessages({
    this.messages = const [],
    this.loading = false,
    this.hasMore = true,
    this.failed = false,
  });

  final List<ChatMessageModel> messages;
  final bool loading;

  /// Whether a page may lie before the oldest loaded message.
  final bool hasMore;

  /// The last load failed, such as without a connection.
  final bool failed;

  OlderMessages copyWith({
    List<ChatMessageModel>? messages,
    bool? loading,
    bool? hasMore,
    bool? failed,
  }) => OlderMessages(
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    hasMore: hasMore ?? this.hasMore,
    failed: failed ?? this.failed,
  );
}

/// Loads older chat messages a page at a time, from the server, keeping
/// them in memory rather than on the device.
class OlderMessagesController extends Notifier<OlderMessages> {
  OlderMessagesController(this.eventId);

  final String eventId;

  @override
  OlderMessages build() => const OlderMessages();

  /// Loads the page before [before], the oldest message showing.
  Future<void> load(DateTime before) async {
    if (state.loading) return;
    state = state.copyWith(loading: true, failed: false);
    try {
      final page = await ref
          .read(chatRepositoryProvider)
          .fetchOlder(eventId, before: before);
      if (!ref.mounted) return;
      final seen = {for (final m in state.messages) m.id};
      state = state.copyWith(
        loading: false,
        hasMore: page.length >= chatPageSize,
        messages: [
          for (final m in page.reversed)
            if (!seen.contains(m.id)) m,
          ...state.messages,
        ],
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(loading: false, failed: true);
    }
  }
}

final olderMessagesProvider = NotifierProvider.autoDispose
    .family<OlderMessagesController, OlderMessages, String>(
      OlderMessagesController.new,
    );
