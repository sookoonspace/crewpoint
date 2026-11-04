import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';

/// The words shown for [status].
String eventStatusLabel(DashboardStrings strings, EventStatus status) =>
    switch (status) {
      EventStatus.draft => strings.statusDraft,
      EventStatus.published => strings.statusPublished,
      EventStatus.live => strings.statusLive,
      EventStatus.ended => strings.statusEnded,
      EventStatus.archived => strings.statusArchived,
    };
