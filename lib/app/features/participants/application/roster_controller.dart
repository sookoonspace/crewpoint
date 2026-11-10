import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/participants/data/participant_repository.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/import_job.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/link_request.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';

/// What the roster shows: the people loaded so far for [query], and the
/// names of their groups.
class RosterState {
  const RosterState({
    this.query = const RosterQuery(),
    this.items = const [],
    this.groups = const {},
    this.loading = false,
    this.started = false,
    this.hasMore = false,
    this.error,
    this.lastPage,
  });

  final RosterQuery query;
  final List<ParticipantModel> items;
  final Map<String, GroupModel> groups;
  final bool loading;

  /// False until the first page has been asked for.
  final bool started;
  final bool hasMore;

  /// Why the last page failed, kept until the next try.
  final Object? error;
  final RosterPage? lastPage;

  RosterState copyWith({
    List<ParticipantModel>? items,
    Map<String, GroupModel>? groups,
    bool? loading,
    bool? hasMore,
    Object? error,
    bool clearError = false,
    RosterPage? lastPage,
  }) => RosterState(
    query: query,
    items: items ?? this.items,
    groups: groups ?? this.groups,
    loading: loading ?? this.loading,
    started: true,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : (error ?? this.error),
    lastPage: lastPage ?? this.lastPage,
  );
}

/// Pages through an event's roster online (Req 43, 74). A new query starts
/// from the first page; an answer to an older query is ignored.
class RosterController extends Notifier<RosterState> {
  RosterController(this.eventId);

  final String eventId;
  int _generation = 0;

  @override
  RosterState build() => const RosterState();

  ParticipantRepository get _repo => ref.read(participantRepositoryProvider);

  /// Shows [query] from its first page.
  Future<void> start(RosterQuery query) async {
    final generation = ++_generation;
    state = RosterState(query: query, loading: true, started: true);
    await _load(generation, after: null);
  }

  /// The next page, or the failed one again.
  Future<void> loadMore() async {
    if (state.loading) return;
    if (!state.started) return start(state.query);
    if (!state.hasMore && state.error == null) return;
    final generation = _generation;
    state = state.copyWith(loading: true, clearError: true);
    await _load(generation, after: state.lastPage);
  }

  /// From the first page again, such as after saving someone.
  Future<void> refresh() => start(state.query);

  Future<void> _load(int generation, {required RosterPage? after}) async {
    try {
      final page = await _repo.fetchPage(eventId, state.query, after: after);
      final missing = [
        for (final p in page.items)
          if (p.groupId != null && !state.groups.containsKey(p.groupId))
            p.groupId!,
      ];
      final groups = missing.isEmpty
          ? const <String, GroupModel>{}
          : await _repo.groupsByIds(eventId, missing);
      if (generation != _generation) return;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        groups: {...state.groups, ...groups},
        loading: false,
        hasMore: page.hasMore,
        lastPage: page,
        clearError: true,
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(loading: false, error: e);
    }
  }
}

final rosterProvider = NotifierProvider.autoDispose
    .family<RosterController, RosterState, String>(RosterController.new);

/// One participant, live, for the participant screen.
final participantProvider = StreamProvider.autoDispose
    .family<ParticipantModel?, ({String eventId, String id})>(
      (ref, key) =>
          ref.watch(participantRepositoryProvider).watch(key.eventId, key.id),
    );

/// Their private details, or null when there are none or the viewer may not
/// read them (Z-01).
final participantPrivateProvider = FutureProvider.autoDispose
    .family<ParticipantPrivate?, ({String eventId, String id})>(
      (ref, key) => ref
          .watch(participantRepositoryProvider)
          .readPrivate(key.eventId, key.id),
    );

/// Groups by ID, such as the one a participant is in.
final groupsByIdProvider = FutureProvider.autoDispose
    .family<Map<String, GroupModel>, ({String eventId, String ids})>(
      (ref, key) => ref
          .watch(participantRepositoryProvider)
          .groupsByIds(
            key.eventId,
            key.ids.isEmpty ? const [] : key.ids.split(','),
          ),
    );

/// How many people are attending, for capacity (Req 18b). Null when it
/// cannot be counted, such as without `participants.read` or offline.
final participantCountProvider = FutureProvider.autoDispose
    .family<int?, String>((ref, eventId) async {
      try {
        return await ref.watch(participantRepositoryProvider).count(eventId);
      } catch (_) {
        return null;
      }
    });

/// The event's custom fields, live and in order (Req 41).
final eventFieldsProvider = StreamProvider.autoDispose
    .family<List<CustomField>, String>(
      (ref, eventId) =>
          ref.watch(participantRepositoryProvider).watchFields(eventId),
    );

/// One import job, live, so it can be left and reopened (Req 75).
final importJobProvider = StreamProvider.autoDispose
    .family<ImportJob?, ({String eventId, String jobId})>(
      (ref, key) =>
          ref.watch(importRepositoryProvider).watch(key.eventId, key.jobId),
    );

/// The latest import jobs, newest first.
final recentImportsProvider = StreamProvider.autoDispose
    .family<List<ImportJob>, String>(
      (ref, eventId) =>
          ref.watch(importRepositoryProvider).watchRecent(eventId),
    );

/// Accounts waiting to be linked by an organizer (Req 46). Empty for anyone
/// who may not read them, so the roster can show a count without failing.
final linkRequestsProvider = StreamProvider.autoDispose
    .family<List<LinkRequest>, String>(
      (ref, eventId) =>
          ref.watch(participantRepositoryProvider).watchLinkRequests(eventId),
    );

/// People by ID, such as the records a link request offers.
final participantsByIdProvider = FutureProvider.autoDispose
    .family<Map<String, ParticipantModel>, ({String eventId, String ids})>(
      (ref, key) => ref
          .watch(participantRepositoryProvider)
          .participantsByIds(
            key.eventId,
            key.ids.isEmpty ? const [] : key.ids.split(','),
          ),
    );
