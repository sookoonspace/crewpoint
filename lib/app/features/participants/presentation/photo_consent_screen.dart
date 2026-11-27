import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart'
    show AdminNote, AdminScaffold, NoAccessView;
import 'package:crewpoint_app/app/features/participants/application/photo_consent_provider.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/photo_consent.dart';

const _k = 'people.photoConsent';

/// `photo-consent` (Spec #233 Req 30; #247), for `photoConsent.read`: who
/// said no to photos and videos, and who has not answered yet, which is
/// treated as no, with a name search. Each row shows only the name, group
/// name and age band.
class PhotoConsentScreen extends ConsumerStatefulWidget {
  const PhotoConsentScreen({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<PhotoConsentScreen> createState() => _PhotoConsentScreenState();
}

class _PhotoConsentScreenState extends ConsumerState<PhotoConsentScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.photoConsent;
    final event = widget.event;
    final me = ref.watch(currentUserIdProvider) ?? '';
    if (!event.can(me, 'photoConsent.read')) {
      return AdminScaffold(title: s.title, body: const NoAccessView());
    }
    final list = ref.watch(photoConsentListProvider(event.id));
    final Widget body = switch (list) {
      AsyncValue(hasValue: true, :final value) => _page(value),
      AsyncValue(error: _?) => CpErrorState(
        key: const Key('$_k.error'),
        title: s.failed,
        retryLabel: s.retry,
        retryKey: const Key('$_k.retry'),
        onRetry: () => ref.invalidate(photoConsentListProvider(event.id)),
      ),
      _ => CpLoadingState.rows(
        key: const Key('$_k.loading'),
        semanticLabel: s.loading,
      ),
    };
    return AdminScaffold(title: s.title, body: body);
  }

  Widget _page(PhotoConsentList? list) {
    final s = context.strings.photoConsent;
    final cp = context.cp;
    final shown = list?.matching(_search.text) ?? const <PhotoConsentEntry>[];
    final saidNo = [
      for (final p in shown)
        if (p.saidNo) p,
    ];
    final unanswered = [
      for (final p in shown)
        if (!p.saidNo) p,
    ];
    final searching = _search.text.trim().isNotEmpty;
    Widget section({
      required String key,
      required String title,
      required List<PhotoConsentEntry> people,
      required String empty,
      required IconData icon,
      required Color color,
    }) => Column(
      key: Key('$_k.$key'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.sm,
      children: [
        CpSectionHeader(title: '$title (${people.length})'),
        if (people.isEmpty)
          Text(
            searching ? s.noMatches : empty,
            key: Key('$_k.$key.empty'),
            style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
          )
        else
          CpCard(
            child: CpRowGroup(
              children: [
                for (final p in people)
                  CpListRow(
                    key: Key('$_k.row.${p.id}'),
                    // Status with an icon and colour together (Req 71).
                    leading: Icon(
                      icon,
                      size: cp.sizes.iconMd,
                      color: color,
                      semanticLabel: title,
                    ),
                    title: p.name.isEmpty ? s.unnamed : p.name,
                    subtitle: [
                      if (p.groupName.isNotEmpty) p.groupName,
                      if (p.ageBand.isNotEmpty) p.ageBand,
                    ].join(' · '),
                  ),
              ],
            ),
          ),
      ],
    );
    return ListView(
      key: const Key('$_k.body'),
      padding: EdgeInsets.fromLTRB(
        cp.space.lg,
        cp.space.sm,
        cp.space.lg,
        cp.space.xxl,
      ),
      children: [
        ContentMaxWidth(
          maxWidth: cp.sizes.phoneColumn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.lg,
            children: [
              KeyedSubtree(
                key: const Key('$_k.note'),
                child: AdminNote(s.note, icon: CpIcons.camera),
              ),
              if (list == null)
                CpEmptyState(
                  key: const Key('$_k.notReady'),
                  icon: CpIcons.camera,
                  title: s.title,
                  message: s.notReady,
                )
              else ...[
                CpSearchField(
                  fieldKey: const Key('$_k.search'),
                  controller: _search,
                  hint: s.searchHint,
                  onChanged: (_) => setState(() {}),
                ),
                section(
                  key: 'saidNo',
                  title: s.saidNo,
                  people: saidNo,
                  empty: s.noneSaidNo,
                  icon: CpIcons.blocked,
                  color: cp.colors.overdue,
                ),
                section(
                  key: 'notAnswered',
                  title: s.notAnswered,
                  people: unanswered,
                  empty: s.noneUnanswered,
                  icon: CpIcons.statusInfo,
                  color: cp.colors.due,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
