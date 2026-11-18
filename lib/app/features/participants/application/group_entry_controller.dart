import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/group_draft.dart';

/// Which group screen: a new group, or adding to [groupId].
@immutable
class GroupEntryArgs {
  const GroupEntryArgs({
    required this.eventId,
    this.groupId,
    this.groupName,
    this.editing = false,
  });

  final String eventId;

  /// "Edit answers" on [groupId]: its people, filled in (Req 26).
  final bool editing;

  /// An existing group to add people to; null for a new group.
  final String? groupId;
  final String? groupName;

  @override
  bool operator ==(Object other) =>
      other is GroupEntryArgs &&
      other.eventId == eventId &&
      other.groupId == groupId &&
      other.groupName == groupName &&
      other.editing == editing;

  @override
  int get hashCode => Object.hash(eventId, groupId, groupName, editing);
}

/// How a save ended.
enum GroupSaveOutcome {
  saved,

  /// No connection: nothing was sent (Req 34, ledger L10).
  offline,

  /// Something is missing; [GroupEntryState.check] says what.
  incomplete,

  /// A step failed; [GroupEntryState.failedStep] says which.
  failed,

  /// A save was already running.
  busy,
}

/// The steps of a save, in order (Req 32).
enum GroupSaveStep {
  /// Creating a new group through `saveGroup`.
  group,

  /// The group's own answers, through `saveGroupAnswers`.
  answers,

  /// Every person and their private details, in one batch.
  people,
}

/// The screen's state: the draft, and how far a save got.
@immutable
class GroupEntryState {
  const GroupEntryState({
    required this.draft,
    this.saving = false,
    this.done = const {},
    this.failedStep,
    this.check,
    this.savedGroupAnswers = const {},
    this.savedGroupPrivateAnswers = const {},
  });

  final GroupDraft draft;

  /// The group's answers as the server has them: none for a new group, or
  /// what was loaded for an existing one. They are saved only when the
  /// draft differs, so unread answers are never wiped.
  final Map<String, Object?> savedGroupAnswers;
  final Map<String, Object?> savedGroupPrivateAnswers;

  /// What is missing, once a save has been tried; null before. It follows
  /// later edits, so problems clear as they are fixed.
  final GroupDraftCheck? check;
  final bool saving;

  /// Steps that succeeded; a retry skips them (Req 33).
  final Set<GroupSaveStep> done;

  /// The step the last save stopped at, to say what did not save (Req 34).
  final GroupSaveStep? failedStep;

  /// Something typed or chosen that leaving would lose (Req 36).
  bool get hasEntries =>
      (draft.isNewGroup && draft.groupName.trim().isNotEmpty) ||
      draft.people.any((p) => !p.isEmpty) ||
      !mapEquals(draft.groupAnswers, savedGroupAnswers) ||
      !mapEquals(draft.groupPrivateAnswers, savedGroupPrivateAnswers);

  GroupEntryState copyWith({
    GroupDraft? draft,
    bool? saving,
    Set<GroupSaveStep>? done,
    GroupSaveStep? failedStep,
    bool clearFailure = false,
    GroupDraftCheck? check,
    Map<String, Object?>? savedGroupAnswers,
    Map<String, Object?>? savedGroupPrivateAnswers,
  }) => GroupEntryState(
    draft: draft ?? this.draft,
    saving: saving ?? this.saving,
    done: done ?? this.done,
    failedStep: clearFailure ? null : (failedStep ?? this.failedStep),
    check: check ?? this.check,
    savedGroupAnswers: savedGroupAnswers ?? this.savedGroupAnswers,
    savedGroupPrivateAnswers:
        savedGroupPrivateAnswers ?? this.savedGroupPrivateAnswers,
  );
}

/// Holds the group screen's draft and saves it (Technical Decisions 4–6).
class GroupEntryController extends Notifier<GroupEntryState> {
  GroupEntryController(this.args);

  final GroupEntryArgs args;

  @override
  GroupEntryState build() => GroupEntryState(
    draft: args.editing && args.groupId != null
        ? GroupDraft(
            groupId: args.groupId!,
            isNewGroup: false,
            editing: true,
            groupName: args.groupName ?? '',
            people: const [],
          )
        : GroupDraft.start(
            groupId: args.groupId ?? newRecordId(),
            isNewGroup: args.groupId == null,
            groupName: args.groupName ?? '',
            newId: newRecordId,
          ),
  );

  /// The group's people as saved, when editing. Filled in once.
  bool _peopleLoaded = false;
  void loadPeople(List<PersonDraft> loaded) {
    if (_peopleLoaded) return;
    _peopleLoaded = true;
    final d = state.draft;
    state = state.copyWith(
      draft: d.copyWith(
        people: [for (final p in loaded) PersonDraft.existing(p), ...d.people],
      ),
    );
  }

  /// The fields and visibility of the last save, to keep [GroupEntryState.check]
  /// current as the draft changes.
  ({List<CustomField> fields, bool readsPrivate})? _checking;

  void edit(GroupDraft Function(GroupDraft draft) change) {
    final before = state.draft;
    final draft = change(before);
    final checking = _checking;
    // A finished step whose input changed must run again.
    final done = {...state.done};
    if (draft.groupName != before.groupName) done.remove(GroupSaveStep.group);
    state = state.copyWith(
      draft: draft,
      done: done,
      check: checking == null
          ? null
          : draft.check(checking.fields, readsPrivate: checking.readsPrivate),
    );
  }

  /// An existing group's answers, once loaded: [private] is null when the
  /// viewer may not read them. Filled in only before anything is typed.
  bool _groupLoaded = false;
  void loadGroupAnswers(
    Map<String, Object?> standard,
    Map<String, Object?>? private, {
    String? name,
  }) {
    if (_groupLoaded) return;
    _groupLoaded = true;
    final d = state.draft;
    state = state.copyWith(
      draft: d.copyWith(
        groupName: name,
        groupAnswers: {...standard},
        groupPrivateAnswers: {...?private},
      ),
      savedGroupAnswers: {...standard},
      savedGroupPrivateAnswers: {...?private},
    );
  }

  Future<GroupSaveOutcome> save({
    required List<CustomField> fields,
    required bool readsPrivate,
    required String? createdBy,
    required List<EventCategory> categories,
    required DateTime eventStart,
  }) async {
    if (state.saving) return GroupSaveOutcome.busy;
    _checking = (fields: fields, readsPrivate: readsPrivate);
    final check = state.draft.check(fields, readsPrivate: readsPrivate);
    state = state.copyWith(check: check);
    if (!check.ok) return GroupSaveOutcome.incomplete;
    state = state.copyWith(saving: true);
    try {
      return await _run(
        fields: fields,
        readsPrivate: readsPrivate,
        createdBy: createdBy,
        categories: categories,
        eventStart: eventStart,
      );
    } finally {
      if (ref.mounted) state = state.copyWith(saving: false);
    }
  }

  Future<GroupSaveOutcome> _run({
    required List<CustomField> fields,
    required bool readsPrivate,
    required String? createdBy,
    required List<EventCategory> categories,
    required DateTime eventStart,
  }) async {
    if (!await ref.read(connectivityProvider).isOnline()) {
      return GroupSaveOutcome.offline;
    }
    final draft = state.draft;
    final eventId = args.eventId;
    final repo = ref.read(participantRepositoryProvider);
    final steps = <GroupSaveStep, Future<void> Function()>{
      if (draft.isNewGroup)
        GroupSaveStep.group: () => ref
            .read(memberCallsProvider)
            .saveGroup(
              eventId: eventId,
              groupId: draft.groupId,
              name: draft.groupName.trim(),
            ),
      if (!mapEquals(draft.groupAnswers, state.savedGroupAnswers) ||
          (readsPrivate &&
              !mapEquals(
                draft.groupPrivateAnswers,
                state.savedGroupPrivateAnswers,
              )))
        GroupSaveStep.answers: () => repo.saveGroupAnswers(
          eventId,
          draft.groupId,
          standard: draft.groupAnswers,
          private: readsPrivate ? draft.groupPrivateAnswers : null,
          definitions: fields,
        ),
      GroupSaveStep.people: () => repo.savePeople(
        eventId,
        writesPrivateOfExisting: readsPrivate,
        draft.records(
          eventId: eventId,
          createdBy: createdBy,
          categories: categories,
          eventStart: eventStart,
        ),
        definitions: fields,
      ),
    };
    for (final MapEntry(key: step, value: run) in steps.entries) {
      if (state.done.contains(step)) continue;
      try {
        await run();
      } catch (e, st) {
        debugPrint('Group save stopped at ${step.name}: $e\n$st');
        if (ref.mounted) state = state.copyWith(failedStep: step);
        return GroupSaveOutcome.failed;
      }
      if (!ref.mounted) return GroupSaveOutcome.failed;
      state = step == GroupSaveStep.answers
          ? state.copyWith(
              savedGroupAnswers: draft.groupAnswers,
              savedGroupPrivateAnswers: readsPrivate
                  ? draft.groupPrivateAnswers
                  : null,
              clearFailure: true,
            )
          : state.copyWith(done: {...state.done, step}, clearFailure: true);
    }
    return GroupSaveOutcome.saved;
  }
}

final groupEntryProvider = NotifierProvider.autoDispose
    .family<GroupEntryController, GroupEntryState, GroupEntryArgs>(
      GroupEntryController.new,
    );
