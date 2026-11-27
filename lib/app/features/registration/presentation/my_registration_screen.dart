import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/registration/domain/my_registration.dart';
import 'package:crewpoint_app/app/features/registration/presentation/widgets/waiver_card.dart';

const _k = 'registration.mine';

/// "My registration" for a slug (#242), read through `getMyRegistration`;
/// Retry invalidates it.
final myRegistrationProvider = FutureProvider.autoDispose
    .family<MyRegistrationView, String>(
      (ref, slug) => ref.watch(memberCallsProvider).getMyRegistration(slug),
      retry: (_, _) => null,
    );

/// `/e/:eventSlug/registration` (Spec #233 Req 9, 19, 35; #242), behind
/// the sign-in gate: the registration's status with an icon and colour,
/// when it was sent, the waitlist number, who is in it, and the
/// after-registration note for submitted groups. Without a registration it
/// offers Register. No fee is shown (Req 7).
class MyRegistrationScreen extends ConsumerWidget {
  const MyRegistrationScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings.myRegistration;
    final form = context.strings.registerForm;
    final cp = context.cp;
    final key = slug.toLowerCase();
    final view = ref.watch(myRegistrationProvider(key));
    Widget frame(String title, List<Widget> children) => Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: title,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: () => context.go('/e/$slug'),
      ),
      body: ListView(
        key: const Key('$_k.body'),
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.md,
          cp.space.lg,
          cp.space.xxl,
        ),
        children: [
          ContentMaxWidth(
            maxWidth: cp.sizes.phoneColumn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.lg,
              children: children,
            ),
          ),
        ],
      ),
    );
    return view.when(
      loading: () => frame(s.title, [
        CpLoadingState.rows(
          key: const Key('$_k.loading'),
          semanticLabel: form.loading,
        ),
      ]),
      error: (_, _) => frame(s.title, [
        CpErrorState(
          key: const Key('$_k.error'),
          title: form.failed,
          message: form.failedHelp,
          retryLabel: form.retry,
          retryKey: const Key('$_k.retry'),
          onRetry: () => ref.invalidate(myRegistrationProvider(key)),
        ),
      ]),
      data: (v) {
        final r = v.registration;
        if (r == null) {
          return frame(v.title, [
            CpEmptyState(
              key: const Key('$_k.none'),
              icon: CpIcons.registration,
              title: s.none,
              message: s.noneHelp,
              actionLabel: s.register,
              actionKey: const Key('$_k.register'),
              onAction: () => context.go('/e/$slug/register'),
            ),
          ]);
        }
        final language = Localizations.localeOf(context).languageCode;
        final locale = Localizations.localeOf(context).toLanguageTag();
        final note = v.note;
        return frame(v.title, [
          // A place on offer (#248): Accept or No thanks, before the status.
          if (r.offeredAt(DateTime.now()))
            _OfferCard(slug: slug, view: v, locale: locale),
          _StatusCard(registration: r, view: v, locale: locale),
          CpSectionHeader(title: s.people),
          CpCard(
            key: const Key('$_k.people'),
            child: CpRowGroup(
              children: [
                for (final p in r.people)
                  CpListRow(
                    leading: CpAvatar(name: p.name),
                    title: p.name,
                  ),
              ],
            ),
          ),
          // Waivers still to accept, at any time (#246, W-06).
          if (r.status != 'cancelled' &&
              r.people.any((p) => p.missingWaivers.isNotEmpty) &&
              v.waivers.isNotEmpty)
            _MissingWaivers(slug: slug, view: v),
          if (note != null) ...[
            CpSectionHeader(title: s.note),
            CpCard(
              key: const Key('$_k.note'),
              padding: EdgeInsets.all(cp.space.lg),
              child: SelectableText(
                language == 'gu' && note.gu != null ? note.gu! : note.en,
                style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
              ),
            ),
          ],
          // Before the deadline everything can change; after it, the
          // contact details only (#244, Req 35, 36).
          if (r.status != 'cancelled')
            CpButton(
              key: const Key('$_k.change'),
              label: v.deadline != null && DateTime.now().isAfter(v.deadline!)
                  ? s.changeContact
                  : s.change,
              icon: CpIcons.actionEdit,
              expand: true,
              onPressed: () => context.go('/e/$slug/register'),
            ),
          CpButton.secondary(
            key: const Key('$_k.back'),
            label: s.backToEvent,
            onPressed: () => context.go('/e/$slug'),
          ),
        ]);
      },
    );
  }
}

/// The status with an icon and colour together (Req 71), when it was
/// sent, and what happens next for pending and waitlisted groups.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.registration,
    required this.view,
    required this.locale,
  });

  final MyRegistration registration;
  final MyRegistrationView view;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.myRegistration;
    final cp = context.cp;
    final r = registration;
    final (label, icon, tone, help) = switch (r.status) {
      'submitted' => (s.submitted, CpIcons.statusDone, CpTagTone.accent, null),
      'pending' => (
        s.pending,
        CpIcons.statusDoing,
        CpTagTone.quiet,
        s.pendingHelp,
      ),
      'waitlisted' => (
        s.waitlisted(r.waitlistPosition ?? 0),
        CpIcons.placesFull,
        CpTagTone.quiet,
        s.waitlistHelp,
      ),
      'cancelled' => (s.cancelled, CpIcons.inviteOff, CpTagTone.quiet, null),
      _ => (s.draft, CpIcons.statusTodo, CpTagTone.quiet, null),
    };
    final sent = r.submittedAt == null
        ? null
        : DateFormat.yMMMEd(
            locale,
          ).format(inEventZone(r.submittedAt!, view.timeZone));
    return CpCard(
      key: Key('$_k.status.${r.status}'),
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: cp.space.sm,
        children: [
          if (r.groupName.isNotEmpty && r.people.length > 1)
            Text(
              r.groupName,
              style: cp.type.titleMedium.copyWith(color: cp.colors.text),
            ),
          CpTag(label: label, icon: icon, tone: tone),
          if (sent != null)
            Text(
              s.sentOn(sent),
              style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
            ),
          if (help != null)
            Text(
              help,
              style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
            ),
        ],
      ),
    );
  }
}

/// The waivers people in the registration still need, each with a switch
/// per person and one Accept (#246, W-06), through `acceptWaivers`.
class _MissingWaivers extends ConsumerStatefulWidget {
  const _MissingWaivers({required this.slug, required this.view});

  final String slug;
  final MyRegistrationView view;

  @override
  ConsumerState<_MissingWaivers> createState() => _MissingWaiversState();
}

class _MissingWaiversState extends ConsumerState<_MissingWaivers> {
  /// Ticked acceptances, as `(person index, waiver ID)`.
  final _ticked = <(int, String)>{};
  bool _busy = false;
  bool _nothingTicked = false;

  Future<void> _accept() async {
    final s = context.strings.myRegistration;
    if (_ticked.isEmpty) {
      setState(() => _nothingTicked = true);
      return;
    }
    final people = widget.view.registration!.people;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _nothingTicked = false;
    });
    try {
      await ref.read(memberCallsProvider).acceptWaivers(
        slug: widget.slug,
        acceptances: [
          for (final (i, waiverId) in _ticked)
            (participantId: people[i].id, waiverId: waiverId),
        ],
      );
      messenger.showSnackBar(SnackBar(content: Text(s.waiversAccepted)));
      ref.invalidate(myRegistrationProvider(widget.slug.toLowerCase()));
    } on Object catch (e, st) {
      log('acceptWaivers failed', error: e, stackTrace: st);
      messenger.showSnackBar(SnackBar(content: Text(s.acceptFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.myRegistration;
    final cp = context.cp;
    final language = Localizations.localeOf(context).languageCode;
    final people = widget.view.registration!.people;
    return Column(
      key: const Key('$_k.waivers'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.md,
      children: [
        CpSectionHeader(title: s.waiversTitle),
        Text(
          s.waiversHelp,
          style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
        ),
        for (final w in widget.view.waivers)
          if (people.any((p) => p.missingWaivers.contains(w.id)))
            WaiverCard(
              key: Key('$_k.waiver.${w.id}'),
              keyPrefix: '$_k.waiver.${w.id}',
              waiver: w,
              language: language,
              people: [
                for (final (i, p) in people.indexed)
                  if (p.missingWaivers.contains(w.id))
                    WaiverPersonRow(
                      index: i,
                      name: p.name,
                      isChild: p.isChild,
                      accepted: _ticked.contains((i, w.id)),
                    ),
              ],
              onAccept: (i, on) => setState(() {
                on ? _ticked.add((i, w.id)) : _ticked.remove((i, w.id));
                _nothingTicked = false;
              }),
            ),
        if (_nothingTicked) CpFieldError(s.nothingTicked),
        CpButton(
          key: const Key('$_k.acceptWaivers'),
          label: s.acceptWaivers,
          icon: CpIcons.statusDone,
          busy: _busy,
          expand: true,
          onPressed: _busy ? null : _accept,
        ),
      ],
    );
  }
}

/// "A place is available for your group until …" with Accept and No
/// thanks (Spec #233 Req 32; #248), through `respondToOffer`. No thanks
/// asks first, because it takes the group off the waitlist for good.
class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({
    required this.slug,
    required this.view,
    required this.locale,
  });

  final String slug;
  final MyRegistrationView view;
  final String locale;

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  bool _busy = false;

  Future<void> _answer(bool accept) async {
    final s = context.strings.myRegistration;
    if (!accept) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (dialog) => CpDialog(
          title: s.declineTitle,
          message: s.declineBody,
          actions: [
            CpButton.text(
              key: const Key('$_k.offer.keep'),
              label: s.keepPlace,
              onPressed: () => Navigator.of(dialog).pop(false),
            ),
            CpButton.destructive(
              key: const Key('$_k.offer.declineConfirm'),
              label: s.noThanks,
              onPressed: () => Navigator.of(dialog).pop(true),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(memberCallsProvider)
          .respondToOffer(slug: widget.slug, accept: accept);
      messenger.showSnackBar(
        SnackBar(content: Text(accept ? s.offerAccepted : s.offerDeclined)),
      );
    } on FirebaseFunctionsException catch (e, st) {
      final reason = (e.details as Map?)?['reason'];
      if (reason != 'expired' && reason != 'noOffer') {
        log('respondToOffer failed', error: e, stackTrace: st);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            reason == 'expired' || reason == 'noOffer'
                ? s.offerExpired
                : s.offerFailed,
          ),
        ),
      );
    } on Object catch (e, st) {
      log('respondToOffer failed', error: e, stackTrace: st);
      messenger.showSnackBar(SnackBar(content: Text(s.offerFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    ref.invalidate(myRegistrationProvider(widget.slug.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.myRegistration;
    final cp = context.cp;
    final v = widget.view;
    final until = DateFormat.yMMMEd(widget.locale)
        .add_jm()
        .format(inEventZone(v.registration!.offerExpiresAt!, v.timeZone));
    return CpCard(
      key: const Key('$_k.offer'),
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: CpTag(label: s.offerTitle, icon: CpIcons.statusDone),
          ),
          Text(
            s.offerBody(v.words.one('group').toLowerCase(), until),
            style: cp.type.bodyLarge.copyWith(color: cp.colors.text),
          ),
          CpButton(
            key: const Key('$_k.offer.accept'),
            label: s.accept,
            icon: CpIcons.statusDone,
            busy: _busy,
            expand: true,
            onPressed: _busy ? null : () => _answer(true),
          ),
          CpButton.secondary(
            key: const Key('$_k.offer.decline'),
            label: s.noThanks,
            expand: true,
            onPressed: _busy ? null : () => _answer(false),
          ),
        ],
      ),
    );
  }
}
