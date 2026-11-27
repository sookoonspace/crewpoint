import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart'
    show AdminNote, AdminScaffold, NoAccessView;
import 'package:crewpoint_app/app/features/registration/application/waitlist_provider.dart';
import 'package:crewpoint_app/app/features/registration/domain/waitlist.dart';

const _k = 'registration.waitlist';

/// `waitlist` (Spec #233 Req 32, 32a, 34; #248), for `registrations.manage`:
/// places used and held, how far over a lowered capacity the event is,
/// then the waiting groups in queue order, each with Offer a place, or
/// its open offer's expiry with Extend and Withdraw.
class WaitlistScreen extends ConsumerStatefulWidget {
  const WaitlistScreen({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends ConsumerState<WaitlistScreen> {
  String? _busy;

  Future<void> _act(WaitingGroup g, OfferAction action) async {
    final s = context.strings.waitlist;
    int? hours;
    if (action == OfferAction.extend) {
      hours = await _pickHours();
      if (hours == null) return;
    }
    if (action == OfferAction.withdraw && !await _confirmWithdraw()) return;
    if (!mounted) return;
    // Each answer replaces the last, rather than queuing behind it.
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    setState(() => _busy = g.registrationId);
    try {
      await ref
          .read(memberCallsProvider)
          .manageOffer(
            eventId: widget.event.id,
            registrationId: g.registrationId,
            action: action,
            hours: hours,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (action) {
            OfferAction.offer => s.offered,
            OfferAction.extend => s.extended,
            OfferAction.withdraw => s.withdrawn,
          }),
        ),
      );
    } on FirebaseFunctionsException catch (e, st) {
      final noRoom = (e.details as Map?)?['reason'] == 'noRoom';
      if (!noRoom) log('manageOffer failed', error: e, stackTrace: st);
      messenger.showSnackBar(
        SnackBar(content: Text(noRoom ? s.noRoom : s.failed)),
      );
    } on Object catch (e, st) {
      log('manageOffer failed', error: e, stackTrace: st);
      messenger.showSnackBar(SnackBar(content: Text(s.failed)));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
    ref.invalidate(waitlistProvider(widget.event.id));
  }

  Future<int?> _pickHours() {
    final s = context.strings.waitlist;
    return showCpSheet<int>(
      context: context,
      title: s.extendTitle,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            for (final h in const [24, 48, 72])
              CpListRow(
                key: Key('$_k.extend.$h'),
                title: s.hours(h),
                onTap: () => Navigator.of(sheet).pop(h),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmWithdraw() async {
    final s = context.strings.waitlist;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => CpDialog(
        title: s.withdrawTitle,
        message: s.withdrawBody,
        actions: [
          CpButton.text(
            key: const Key('$_k.withdraw.cancel'),
            label: s.cancel,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          CpButton.destructive(
            key: const Key('$_k.withdraw.confirm'),
            label: s.withdraw,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    return sure == true;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.waitlist;
    final event = widget.event;
    final me = ref.watch(currentUserIdProvider) ?? '';
    if (!event.can(me, 'registrations.manage')) {
      return AdminScaffold(title: s.title, body: const NoAccessView());
    }
    final view = ref.watch(waitlistProvider(event.id));
    final Widget body = switch (view) {
      AsyncValue(hasValue: true, :final value) => _page(value!),
      AsyncValue(error: _?) => CpErrorState(
        key: const Key('$_k.error'),
        title: s.loadFailed,
        retryLabel: s.retry,
        retryKey: const Key('$_k.retry'),
        onRetry: () => ref.invalidate(waitlistProvider(event.id)),
      ),
      _ => CpLoadingState.rows(
        key: const Key('$_k.loading'),
        semanticLabel: s.title,
      ),
    };
    return AdminScaffold(title: s.title, body: body);
  }

  Widget _page(WaitlistView v) {
    final s = context.strings.waitlist;
    final cp = context.cp;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String when(DateTime t) => DateFormat.MMMEd(
      locale,
    ).add_jm().format(inEventZone(t, v.timeZone));
    final muted = cp.type.bodyMedium.copyWith(color: cp.colors.textMuted);
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
              CpCard(
                key: const Key('$_k.places'),
                padding: EdgeInsets.all(cp.space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: cp.space.xs,
                  children: [
                    if (v.capacity == null)
                      Text(s.noCapacity, style: muted)
                    else ...[
                      Text(
                        s.placesUsed(v.placesUsed, v.capacity!),
                        key: const Key('$_k.used'),
                        style: cp.type.titleMedium.copyWith(
                          color: cp.colors.text,
                        ),
                      ),
                      if (v.held > 0)
                        Text(
                          s.held(v.held),
                          key: const Key('$_k.held'),
                          style: muted,
                        ),
                    ],
                  ],
                ),
              ),
              // A lowered capacity removes nobody (Req 32a).
              if (v.over > 0)
                KeyedSubtree(
                  key: const Key('$_k.over'),
                  child: AdminNote(s.over(v.over), icon: CpIcons.statusUrgent),
                ),
              if (v.closedAt(DateTime.now()))
                KeyedSubtree(
                  key: const Key('$_k.closed'),
                  child: AdminNote(s.afterDeadline, icon: CpIcons.statusInfo),
                ),
              CpSectionHeader(title: s.title),
              if (v.waiting.isEmpty)
                Text(s.empty, key: const Key('$_k.empty'), style: muted)
              else
                for (final g in v.waiting)
                  _GroupCard(
                    key: Key('$_k.group.${g.registrationId}'),
                    group: g,
                    expires: g.offerExpiresAt == null
                        ? null
                        : when(g.offerExpiresAt!),
                    canOffer: v.fits(g),
                    busy: _busy == g.registrationId,
                    onAction: (a) => _act(g, a),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    super.key,
    required this.group,
    required this.expires,
    required this.canOffer,
    required this.busy,
    required this.onAction,
  });

  final WaitingGroup group;
  final String? expires;
  final bool canOffer;
  final bool busy;
  final ValueChanged<OfferAction> onAction;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.waitlist;
    final cp = context.cp;
    final id = group.registrationId;
    final title = [
      if (group.position != null) s.number(group.position!),
      if (group.groupName.isNotEmpty) group.groupName,
    ].join(' · ');
    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.sm,
        children: [
          Text(
            title,
            style: cp.type.titleMedium.copyWith(color: cp.colors.text),
          ),
          Text(
            s.people(group.size),
            style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
          ),
          // Status with an icon and colour together (Req 71).
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: expires == null
                ? CpTag(
                    label: s.waiting,
                    icon: CpIcons.statusDue,
                    tone: CpTagTone.quiet,
                  )
                : CpTag(
                    key: Key('$_k.offered.$id'),
                    label: s.offeredUntil(expires!),
                    icon: CpIcons.statusDone,
                  ),
          ),
          Wrap(
            spacing: cp.space.sm,
            runSpacing: cp.space.xs,
            children: [
              if (expires == null)
                CpButton.secondary(
                  key: Key('$_k.offer.$id'),
                  label: s.offer,
                  busy: busy,
                  onPressed: busy || !canOffer
                      ? null
                      : () => onAction(OfferAction.offer),
                )
              else ...[
                CpButton.secondary(
                  key: Key('$_k.extend.$id'),
                  label: s.extend,
                  busy: busy,
                  onPressed: busy ? null : () => onAction(OfferAction.extend),
                ),
                CpButton.text(
                  key: Key('$_k.withdraw.$id'),
                  label: s.withdraw,
                  onPressed: busy
                      ? null
                      : () => onAction(OfferAction.withdraw),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
