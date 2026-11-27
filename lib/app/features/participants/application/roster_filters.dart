import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/participant.dart';

/// What the roster is searching and filtering by. Kept outside the screen
/// so the list keeps them when choosing someone opens their record beside
/// it, which builds the list again on the detail route (Spec #186 Req 23).
class RosterFilters {
  const RosterFilters({
    this.search = '',
    this.group,
    this.category,
    this.answer,
    this.missingWaiver = false,
    this.registrationStatus,
  });

  final String search;
  final GroupModel? group;
  final EventCategory? category;

  /// A field answer to filter by, such as Diet is Jain.
  final ({CustomField field, Object value})? answer;

  /// Only people missing a waiver (#246); it replaces the other filters.
  final bool missingWaiver;

  /// Only one registration status (#249); it replaces the other filters.
  final String? registrationStatus;

  bool get any =>
      search.isNotEmpty ||
      group != null ||
      category != null ||
      answer != null ||
      missingWaiver ||
      registrationStatus != null;
}

class RosterFiltersController extends Notifier<RosterFilters> {
  RosterFiltersController(this.eventId);

  final String eventId;

  /// Where the list was scrolled to, so it opens there again. Not state:
  /// scrolling never rebuilds anything.
  double scrollOffset = 0;

  @override
  RosterFilters build() => const RosterFilters();

  void setSearch(String text) => state = RosterFilters(
    search: text,
    group: state.group,
    category: state.category,
    answer: state.answer,
  );

  void setGroup(GroupModel? group) => state = RosterFilters(
    search: state.search,
    group: group,
    category: state.category,
    answer: state.answer,
  );

  void setCategory(EventCategory? category) => state = RosterFilters(
    search: state.search,
    group: state.group,
    category: category,
    answer: state.answer,
  );

  void setAnswer(({CustomField field, Object value})? answer) =>
      state = RosterFilters(
        search: state.search,
        group: state.group,
        category: state.category,
        answer: answer,
      );

  /// Only people missing a waiver, or back to everyone (#246).
  void setMissingWaiver(bool on) =>
      state = RosterFilters(search: state.search, missingWaiver: on);

  /// Only one registration status, or none (#249).
  void setRegistrationStatus(String? status) =>
      state = RosterFilters(search: state.search, registrationStatus: status);

  /// Back to everyone.
  void clear() => state = RosterFilters(search: state.search);
}

/// The roster's filters for one event, kept while any roster shows it.
final rosterFiltersProvider = NotifierProvider.autoDispose
    .family<RosterFiltersController, RosterFilters, String>(
      RosterFiltersController.new,
    );
