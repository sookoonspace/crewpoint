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
import 'package:crewpoint_app/app/features/registration/domain/committee.dart';
import 'package:crewpoint_app/app/features/registration/presentation/widgets/registration_status.dart';

const _k = 'registration.group';

/// A group's registration (#249), through `getGroupRegistration`.
final groupRegistrationProvider = FutureProvider.autoDispose
    .family<GroupRegistration?, ({String eventId, String groupId})>(
      (ref, key) => ref
          .watch(memberCallsProvider)
          .getGroupRegistration(eventId: key.eventId, groupId: key.groupId),
      retry: (_, _) => null,
    );

/// `people/registration/:groupId` (Spec #233 Req 37, 66; #249), for
/// `registrations.manage`: the registration's status, number or offer, the
/// contact and linked adults, each person's waivers and the change log,
/// with approve, move to waitlist, reinstate, cancel and resend, at any
/// time; going over capacity asks first.
class GroupRegistrationScreen extends ConsumerStatefulWidget {
  const GroupRegistrationScreen({
    super.key,
    required this.event,
    required this.groupId,
  });

  final EventModel event;
  final String groupId;

  @override
  ConsumerState<GroupRegistrationScreen> createState() =>
      _GroupRegistrationScreenState();
}

class _GroupRegistrationScreenState
    extends ConsumerState<GroupRegistrationScreen> {
  bool _busy = false;

  ({String eventId, String groupId}) get _key =>
      (eventId: widget.event.id, groupId: widget.groupId);

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirm,
    required String keep,
    bool destructive = false,
  }) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => CpDialog(
        title: title,
        message: body,
        actions: [
          CpButton.text(
            key: const Key('$_k.confirm.keep'),
            label: keep,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          destructive
              ? CpButton.destructive(
                  key: const Key('$_k.confirm.go'),
                  label: confirm,
                  onPressed: () => Navigator.of(dialog).pop(true),
                )
              : CpButton(
                  key: const Key('$_k.confirm.go'),
                  label: confirm,
                  onPressed: () => Navigator.of(dialog).pop(true),
                ),
        ],
      ),
    );
    return sure == true;
  }

  /// Runs [call], showing [done], and refreshes the registration.
  Future<void> _run(Future<void> Function() call, String done) async {
    final s = context.strings.committee;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    setState(() => _busy = true);
    try {
      await call();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on FirebaseFunctionsException catch (e, st) {
      final reason = (e.details as Map?)?['reason'];
      if (reason == 'overCapacity' && mounted) {
        setState(() => _busy = false);
        final over = ((e.details as Map)['over'] as num?)?.toInt() ?? 0;
        // Going over capacity must be confirmed (Req 37, B-12).
        if (await _confirm(
          title: s.overTitle,
          body: s.overBody(over),
          confirm: s.goAhead,
          keep: s.cancel,
        )) {
          return _run(
            () => _act(RegistrationAction.reinstate, confirmOver: true),
            done,
          );
        }
        return;
      }
      if (reason != 'noContact') {
        log('registration action failed', error: e, stackTrace: st);
      }
      messenger.showSnackBar(
        SnackBar(content: Text(reason == 'noContact' ? s.noContact : s.failed)),
      );
    } on Object catch (e, st) {
      log('registration action failed', error: e, stackTrace: st);
      messenger.showSnackBar(SnackBar(content: Text(s.failed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    ref.invalidate(groupRegistrationProvider(_key));
  }

  Future<void> _act(RegistrationAction action, {bool confirmOver = false}) =>
      ref
          .read(memberCallsProvider)
          .manageRegistration(
            eventId: widget.event.id,
            registrationId: _registrationId!,
            action: action,
            confirmOverCapacity: confirmOver,
          );

  String? _registrationId;

  String get _slug =>
      ((widget.event.settings['registration'] as Map?)?['slug'] as String?) ??
      '';

  Future<void> _cancel() async {
    final s = context.strings.committee;
    if (!await _confirm(
      title: s.cancelTitle,
      body: s.cancelBody,
      confirm: s.cancelRegistration,
      keep: s.keep,
      destructive: true,
    )) {
      return;
    }
    await _run(
      () => ref
          .read(memberCallsProvider)
          .cancelRegistrationById(
            slug: _slug,
            registrationId: _registrationId!,
          ),
      s.saved,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.committee;
    final event = widget.event;
    final me = ref.watch(currentUserIdProvider) ?? '';
    if (!event.can(me, 'registrations.manage')) {
      return AdminScaffold(title: s.title, body: const NoAccessView());
    }
    final view = ref.watch(groupRegistrationProvider(_key));
    final Widget body = switch (view) {
      AsyncValue(hasValue: true, :final value) =>
        value == null
            ? _SendLink(event: event, groupId: widget.groupId)
            : _page(value),
      AsyncValue(error: _?) => CpErrorState(
        key: const Key('$_k.error'),
        title: s.loadFailed,
        retryLabel: s.retry,
        retryKey: const Key('$_k.retry'),
        onRetry: () => ref.invalidate(groupRegistrationProvider(_key)),
      ),
      _ => CpLoadingState.rows(
        key: const Key('$_k.loading'),
        semanticLabel: s.title,
      ),
    };
    return AdminScaffold(title: s.title, body: body);
  }

  Widget _page(GroupRegistration r) {
    _registrationId = r.registrationId;
    final s = context.strings.committee;
    final waitlist = context.strings.waitlist;
    final cp = context.cp;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final gu = Localizations.localeOf(context).languageCode == 'gu';
    final zone = widget.event.timeZone;
    String when(DateTime t) =>
        DateFormat.yMMMd(locale).add_jm().format(inEventZone(t, zone));
    final muted = cp.type.bodyMedium.copyWith(color: cp.colors.textMuted);
    final actions = r.actions(review: true);
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
                key: Key('$_k.status.${r.status}'),
                padding: EdgeInsets.all(cp.space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: cp.space.sm,
                  children: [
                    RegistrationStatusTag(status: r.status),
                    if (r.waitlistPosition != null)
                      Text(waitlist.number(r.waitlistPosition!), style: muted),
                    if (r.offerExpiresAt != null)
                      Text(
                        waitlist.offeredUntil(when(r.offerExpiresAt!)),
                        style: muted,
                      ),
                    if (r.submittedAt != null)
                      Text(s.sentOn(when(r.submittedAt!)), style: muted),
                  ],
                ),
              ),
              Wrap(
                spacing: cp.space.sm,
                runSpacing: cp.space.sm,
                children: [
                  for (final a in actions)
                    CpButton.secondary(
                      key: Key('$_k.${a.name}'),
                      label: switch (a) {
                        RegistrationAction.approve => s.approve,
                        RegistrationAction.waitlist => s.waitlist,
                        RegistrationAction.reinstate => s.reinstate,
                      },
                      busy: _busy,
                      onPressed: _busy
                          ? null
                          : () => _run(() => _act(a), s.saved),
                    ),
                  if (r.canResend)
                    CpButton.secondary(
                      key: const Key('$_k.resend'),
                      label: s.resend,
                      icon: CpIcons.authEmailField,
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => ref
                                  .read(memberCallsProvider)
                                  .resendConfirmation(
                                    eventId: widget.event.id,
                                    registrationId: r.registrationId,
                                  ),
                              s.resent,
                            ),
                    ),
                  if (r.canCancel)
                    CpButton.destructive(
                      key: const Key('$_k.cancel'),
                      label: s.cancelRegistration,
                      onPressed: _busy ? null : _cancel,
                    ),
                ],
              ),
              CpSectionHeader(title: s.contactHeading),
              CpCard(
                padding: EdgeInsets.all(cp.space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: cp.space.xs,
                  children: [
                    Text(
                      r.contactName?.isNotEmpty == true
                          ? r.contactName!
                          : context.strings.links.unnamed,
                      key: const Key('$_k.contact'),
                      style: cp.type.titleMedium.copyWith(
                        color: cp.colors.text,
                      ),
                    ),
                    if (r.contactEmail != null)
                      SelectableText(r.contactEmail!, style: muted),
                  ],
                ),
              ),
              if (r.linkedAdults.isNotEmpty) ...[
                CpSectionHeader(title: s.adultsHeading),
                CpCard(
                  child: CpRowGroup(
                    children: [
                      for (final a in r.linkedAdults)
                        CpListRow(
                          leading: CpAvatar(name: a),
                          title: a,
                        ),
                    ],
                  ),
                ),
              ],
              CpSectionHeader(title: s.peopleHeading),
              CpCard(
                child: CpRowGroup(
                  children: [
                    for (final p in r.people)
                      CpListRow(
                        key: Key('$_k.person.${p.id}'),
                        leading: CpAvatar(name: p.name),
                        title: p.name,
                        subtitle: [
                          if (p.waivers.isEmpty)
                            s.noWaivers
                          else
                            for (final w in p.waivers)
                              s.waiverLine(
                                gu && w.title.gu != null
                                    ? w.title.gu!
                                    : w.title.en,
                                w.version,
                              ),
                          if (p.missingWaivers.isNotEmpty) s.missingWaivers,
                        ].join(' · '),
                      ),
                  ],
                ),
              ),
              CpSectionHeader(title: s.logHeading),
              if (r.changes.isEmpty)
                Text(s.noChanges, style: muted)
              else
                CpCard(
                  key: const Key('$_k.log'),
                  child: CpRowGroup(
                    children: [
                      for (final c in r.changes)
                        CpListRow(
                          title: c.action == 'edited'
                              ? s.changedFields(c.fields.join(', '))
                              : s.logAction(c.action),
                          subtitle: s.byWhen(
                            c.by.isEmpty ? s.system : c.by,
                            c.at == null ? '' : when(c.at!),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A group added by hand (#249, Req 5): it has no registration, and
/// `registrations.manage` can email a "complete your registration" link.
class _SendLink extends ConsumerStatefulWidget {
  const _SendLink({required this.event, required this.groupId});

  final EventModel event;
  final String groupId;

  @override
  ConsumerState<_SendLink> createState() => _SendLinkState();
}

class _SendLinkState extends ConsumerState<_SendLink> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _tried = false;

  static final _valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final s = context.strings.committee;
    setState(() => _tried = true);
    if (!_valid.hasMatch(_email.text.trim())) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    setState(() => _busy = true);
    try {
      await ref
          .read(memberCallsProvider)
          .sendCompletionLink(
            eventId: widget.event.id,
            groupId: widget.groupId,
            email: _email.text.trim(),
          );
      messenger.showSnackBar(SnackBar(content: Text(s.linkSent)));
    } on Object catch (e, st) {
      log('sendCompletionLink failed', error: e, stackTrace: st);
      messenger.showSnackBar(SnackBar(content: Text(s.failed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.committee;
    final cp = context.cp;
    return ListView(
      key: const Key('$_k.none'),
      padding: EdgeInsets.all(cp.space.lg),
      children: [
        ContentMaxWidth(
          maxWidth: cp.sizes.phoneColumn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.lg,
            children: [
              AdminNote(s.noRegistration, icon: CpIcons.statusInfo),
              CpSectionHeader(title: s.sendLinkHeading),
              Text(
                s.sendLinkHelp,
                style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
              ),
              CpCard(
                padding: EdgeInsets.all(cp.space.lg),
                child: CpTextField(
                  fieldKey: const Key('$_k.linkEmail'),
                  label: s.linkEmail,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  error: _tried && !_valid.hasMatch(_email.text.trim())
                      ? s.invalidEmail
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              CpButton(
                key: const Key('$_k.sendLink'),
                label: s.sendLink,
                icon: CpIcons.authEmailField,
                busy: _busy,
                expand: true,
                onPressed: _busy ? null : _send,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
