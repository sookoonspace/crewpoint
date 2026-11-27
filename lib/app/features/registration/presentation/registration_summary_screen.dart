import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_colors.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart'
    show AdminNote, AdminScaffold, NoAccessView;
import 'package:crewpoint_app/app/features/participants/application/roster_filters.dart';
import 'package:crewpoint_app/app/features/registration/domain/committee.dart';
import 'package:crewpoint_app/app/features/registration/presentation/event_page_screen.dart'
    show eventPageLink;
import 'package:crewpoint_app/app/features/registration/presentation/widgets/registration_status.dart';

const _k = 'registration.summary';

/// The Registration summary (#249), through `getRegistrationSummary`.
final registrationSummaryProvider = FutureProvider.autoDispose
    .family<RegistrationSummary, String>(
      (ref, eventId) =>
          ref.watch(memberCallsProvider).getRegistrationSummary(eventId),
      retry: (_, _) => null,
    );

/// `registration` (Spec #233 Req 64, 4a; #249), for `registrations.manage`:
/// counts by status, each opening its follow-up list, the not-yet-confirmed
/// totals, places, the deadline, the public link with its QR code, the
/// closing reminder, and shortcuts to the lists.
class RegistrationSummaryScreen extends ConsumerStatefulWidget {
  const RegistrationSummaryScreen({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<RegistrationSummaryScreen> createState() =>
      _RegistrationSummaryScreenState();
}

class _RegistrationSummaryScreenState
    extends ConsumerState<RegistrationSummaryScreen> {
  bool _reminding = false;

  String get _base => '/dashboard/event/${widget.event.id}';

  /// Opens People on one status, the follow-up list (Req 4a).
  void _openStatus(String status) {
    if (status == 'waitlisted') {
      context.push('$_base/waitlist');
      return;
    }
    ref
        .read(rosterFiltersProvider(widget.event.id).notifier)
        .setRegistrationStatus(status);
    context.push('$_base/people');
  }

  Future<void> _remind() async {
    final s = context.strings.committee;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => CpDialog(
        title: s.remindTitle,
        message: s.remindBody,
        actions: [
          CpButton.text(
            key: const Key('$_k.remind.cancel'),
            label: s.cancel,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          CpButton(
            key: const Key('$_k.remind.confirm'),
            label: s.send,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reminding = true);
    try {
      final sent = await ref
          .read(memberCallsProvider)
          .sendClosingReminder(widget.event.id);
      messenger.showSnackBar(SnackBar(content: Text(s.remindersSent(sent))));
    } on Object catch (e, st) {
      log('sendClosingReminder failed', error: e, stackTrace: st);
      messenger.showSnackBar(SnackBar(content: Text(s.failed)));
    } finally {
      if (mounted) setState(() => _reminding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.committee;
    final event = widget.event;
    final me = ref.watch(currentUserIdProvider) ?? '';
    if (!event.can(me, 'registrations.manage')) {
      return AdminScaffold(title: s.title, body: const NoAccessView());
    }
    final summary = ref.watch(registrationSummaryProvider(event.id));
    // Kept alive while this screen is open, so a list it opens with a
    // filter set still has it when People builds.
    ref.watch(rosterFiltersProvider(event.id));
    final Widget body = switch (summary) {
      AsyncValue(hasValue: true, :final value) => _page(value!),
      AsyncValue(error: _?) => CpErrorState(
        key: const Key('$_k.error'),
        title: s.loadFailed,
        retryLabel: s.retry,
        retryKey: const Key('$_k.retry'),
        onRetry: () => ref.invalidate(registrationSummaryProvider(event.id)),
      ),
      _ => CpLoadingState.rows(
        key: const Key('$_k.loading'),
        semanticLabel: s.title,
      ),
    };
    return AdminScaffold(title: s.title, body: body);
  }

  Widget _page(RegistrationSummary v) {
    final s = context.strings.committee;
    final waitlist = context.strings.waitlist;
    final page = context.strings.eventPage;
    final cp = context.cp;
    final words = widget.event.words;
    final group = words.other('group').toLowerCase();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final muted = cp.type.bodyMedium.copyWith(color: cp.colors.textMuted);
    final deadline = v.deadline;
    final when = deadline == null
        ? null
        : DateFormat.yMMMEd(
            locale,
          ).add_jm().format(inEventZone(deadline, v.timeZone));
    final link = v.slug == null ? null : eventPageLink(v.slug!);
    final notConfirmed = v.notConfirmed;
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
              CpSectionHeader(title: s.byStatusHeading),
              CpCard(
                child: CpRowGroup(
                  children: [
                    for (final status in registrationStatuses)
                      CpListRow(
                        key: Key('$_k.status.$status'),
                        leading: RegistrationStatusIcon(status: status),
                        title: s.status(status),
                        subtitle: [
                          s.countOf(v.count(status).groups, group),
                          if (v.count(status).people case final people?)
                            s.people(people),
                        ].join(' · '),
                        // Drafts have no people to list yet.
                        trailing: status == 'draft'
                            ? null
                            : Icon(
                                CpIcons.chevronRight,
                                size: cp.sizes.iconMd,
                                color: cp.colors.textMuted,
                              ),
                        onTap: status == 'draft'
                            ? null
                            : () => _openStatus(status),
                      ),
                  ],
                ),
              ),
              CpSectionHeader(title: s.notConfirmedHeading),
              Text(
                [
                  s.countOf(notConfirmed.groups, group),
                  s.people(notConfirmed.people),
                ].join(' · '),
                key: const Key('$_k.notConfirmed'),
                style: cp.type.bodyLarge.copyWith(color: cp.colors.text),
              ),
              CpSectionHeader(title: s.placesHeading),
              CpCard(
                key: const Key('$_k.places'),
                padding: EdgeInsets.all(cp.space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: cp.space.xs,
                  children: [
                    Text(
                      v.capacity == null
                          ? waitlist.noCapacity
                          : waitlist.placesUsed(v.placesUsed, v.capacity!),
                      style: cp.type.titleMedium.copyWith(
                        color: cp.colors.text,
                      ),
                    ),
                    if (v.held > 0) Text(waitlist.held(v.held), style: muted),
                  ],
                ),
              ),
              if (v.over > 0)
                KeyedSubtree(
                  key: const Key('$_k.over'),
                  child: AdminNote(
                    waitlist.over(v.over),
                    icon: CpIcons.statusUrgent,
                  ),
                ),
              CpSectionHeader(title: s.deadlineHeading),
              Text(
                when == null
                    ? s.noDeadline
                    : DateTime.now().isAfter(deadline!)
                    ? s.closed(when)
                    : s.closes(when),
                key: const Key('$_k.deadline'),
                style: cp.type.bodyLarge.copyWith(color: cp.colors.text),
              ),
              CpSectionHeader(title: s.linkHeading),
              if (link == null)
                AdminNote(s.noLink, icon: CpIcons.statusInfo)
              else
                CpCard(
                  key: const Key('$_k.link'),
                  padding: EdgeInsets.all(cp.space.lg),
                  child: Column(
                    spacing: cp.space.md,
                    children: [
                      Container(
                        padding: EdgeInsets.all(cp.space.md),
                        decoration: BoxDecoration(
                          color: CpFixedColors.qrPaper,
                          borderRadius: cp.radii.lg,
                        ),
                        child: ref
                            .watch(qrRendererProvider)
                            .render(
                              link,
                              size: cp.sizes.qrCode,
                              foreground: CpFixedColors.qrInk,
                              background: CpFixedColors.qrPaper,
                              semanticLabel: page.qrLabel(link),
                            ),
                      ),
                      SelectableText(
                        link,
                        textAlign: TextAlign.center,
                        style: cp.type.bodyMedium.copyWith(
                          color: cp.colors.text,
                        ),
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: cp.space.sm,
                        runSpacing: cp.space.sm,
                        children: [
                          CpButton.secondary(
                            key: const Key('$_k.copy'),
                            label: page.copyLink,
                            icon: CpIcons.actionCopy,
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: link));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(page.copied)),
                              );
                            },
                          ),
                          CpButton.secondary(
                            key: const Key('$_k.share'),
                            label: page.share,
                            icon: CpIcons.actionShare,
                            onPressed: () => SharePlus.instance.share(
                              ShareParams(text: '${widget.event.title}\n$link'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              CpSectionHeader(title: s.listsHeading),
              CpCard(
                child: CpRowGroup(
                  children: [
                    CpListRow(
                      key: const Key('$_k.waitlist'),
                      leading: Icon(
                        CpIcons.placesFull,
                        size: cp.sizes.iconMd,
                        color: cp.colors.textMuted,
                      ),
                      title: waitlist.title,
                      onTap: () => context.push('$_base/waitlist'),
                    ),
                    CpListRow(
                      key: const Key('$_k.missingWaiver'),
                      leading: Icon(
                        CpIcons.terms,
                        size: cp.sizes.iconMd,
                        color: cp.colors.textMuted,
                      ),
                      title: context.strings.people.missingWaiver,
                      onTap: () {
                        ref
                            .read(
                              rosterFiltersProvider(widget.event.id).notifier,
                            )
                            .setMissingWaiver(true);
                        context.push('$_base/people');
                      },
                    ),
                    CpListRow(
                      key: const Key('$_k.settings'),
                      leading: Icon(
                        CpIcons.actionSettings,
                        size: cp.sizes.iconMd,
                        color: cp.colors.textMuted,
                      ),
                      title: s.settings,
                      onTap: () => context.push('$_base/settings/registration'),
                    ),
                  ],
                ),
              ),
              CpSectionHeader(title: s.remindHeading),
              Text(s.remindHelp, style: muted),
              CpButton.secondary(
                key: const Key('$_k.remind'),
                label: s.remind,
                icon: CpIcons.authEmailField,
                busy: _reminding,
                expand: true,
                onPressed: _reminding ? null : _remind,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
