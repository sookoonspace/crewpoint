import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/features/chat/application/people_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/member_picker_sheet.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';

/// Transfer ownership (Req 30, route `transfer`). The Owner offers ownership
/// to anyone in the event; the person offered accepts or declines here. Co-
/// owners see who owns it, read-only. An event always has one Owner, and the
/// old owner becomes a Co-owner.
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  String? _picked;
  String? _pickedName;
  bool _busy = false;

  /// Runs [call], then shows [done], or the error. The pick is kept on
  /// failure.
  Future<void> _run(Future<void> Function() call, String done) async {
    final strings = context.strings.transfer;
    final errors = context.strings.errors;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await call();
      if (!mounted) return;
      setState(() => _picked = null);
      // Replaces any earlier message, so the latest result shows at once.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(done)));
    } catch (e, st) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userMessageFor(
              e,
              stackTrace: st,
              strings: errors,
              fallback: strings.failed,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _offer(String toUid, String name) async {
    final strings = context.strings.transfer;
    final confirmed = await confirmAction(
      context,
      title: strings.offerTitle(name),
      body: strings.offerBody,
      action: strings.offer,
      confirmKey: const Key('transfer.offerConfirm'),
    );
    if (!confirmed || !mounted) return;
    final calls = ref.read(memberCallsProvider);
    await _run(
      () => calls.offerOwnership(eventId: widget.event.id, toUid: toUid),
      strings.offered,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.transfer;
    final event = widget.event;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final offerAsync = ref.watch(ownershipOfferProvider(event.id));
    final offer = offerAsync.value;
    final isOwner = event.isOwner(me);
    final offeredToMe = offer?.to == me;
    final canSee = isOwner || offeredToMe || event.can(me, 'roles.manage');

    final ownerId = event.memberIds.firstWhere(
      event.isOwner,
      orElse: () => event.creatorId,
    );
    // Only the people this screen names are read (Req 43a).
    final users =
        ref
            .watch(
              peopleByIdProvider(
                PeopleKey(event.id, [ownerId, ?offer?.from, ?offer?.to]),
              ),
            )
            .value ??
        const {};
    String nameOf(String uid) {
      if (uid == me) return strings.you;
      if (uid == _picked && (_pickedName?.isNotEmpty ?? false)) {
        return _pickedName!;
      }
      final user = users[uid];
      if (user?.displayName?.isNotEmpty ?? false) return user!.displayName!;
      if (user?.email.isNotEmpty ?? false) return user!.email;
      return event.words.one('member');
    }

    final Widget body;
    if (offerAsync.hasError && !offerAsync.hasValue) {
      body = LoadFailedView(
        onRetry: () => ref.invalidate(ownershipOfferProvider(event.id)),
      );
    } else if (!offerAsync.hasValue) {
      body = CpLoadingState.rows(
        key: const Key('transfer.loading'),
        semanticLabel: strings.title,
      );
    } else if (!canSee) {
      body = const NoAccessView();
    } else {
      body = AdminList(
        listKey: const Key('transfer.body'),
        children: [
          CpCard(
            child: CpListRow(
              key: const Key('transfer.owner'),
              leading: CpAvatar(name: nameOf(ownerId)),
              title: strings.currentOwner(nameOf(ownerId)),
            ),
          ),
          if (offeredToMe && offer != null)
            _OfferToMe(
              from: nameOf(offer.from),
              busy: _busy,
              onAccept: () => _run(
                () => ref
                    .read(memberCallsProvider)
                    .acceptOwnership(eventId: event.id),
                strings.accepted,
              ),
              onDecline: () => _run(
                () => ref
                    .read(memberCallsProvider)
                    .cancelOwnershipOffer(eventId: event.id),
                strings.declined,
              ),
            )
          else if (offer != null)
            _Waiting(
              name: nameOf(offer.to),
              canWithdraw: isOwner && !_busy,
              onWithdraw: () => _run(
                () => ref
                    .read(memberCallsProvider)
                    .cancelOwnershipOffer(eventId: event.id),
                strings.withdrawn,
              ),
            )
          else if (isOwner)
            ..._picker(context, me, nameOf),
        ],
      );
    }

    return AdminScaffold(title: strings.title, body: body);
  }

  List<Widget> _picker(
    BuildContext context,
    String me,
    String Function(String) nameOf,
  ) {
    final strings = context.strings.transfer;
    final others = [
      for (final uid in widget.event.memberIds)
        if (uid != me) uid,
    ];
    if (others.isEmpty) {
      return [
        AdminNote(
          strings.noOneElse,
          key: const Key('transfer.empty'),
          icon: CpIcons.statusInfo,
        ),
      ];
    }
    final picked = _picked;
    final cp = context.cp;
    return [
      CpSectionHeader(title: strings.pickHeading),
      AdminNote(strings.pickHint),
      // Chosen by name search, so a large event never lists everyone
      // (Req 43a).
      if (picked != null)
        CpCard(
          child: CpListRow(
            key: const Key('transfer.picked'),
            leading: CpAvatar(name: nameOf(picked)),
            title: nameOf(picked),
          ),
        ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: CpButton.secondary(
          key: const Key('transfer.choose'),
          icon: CpIcons.memberAdd,
          label: context.strings.memberPicker.chooseOne(
            widget.event.words.one('member'),
          ),
          onPressed: _busy
              ? null
              : () async {
                  final person = await MemberPickerSheet.pickOne(
                    context,
                    eventId: widget.event.id,
                    words: widget.event.words,
                    exclude: {me},
                  );
                  if (person == null || !mounted) return;
                  setState(() {
                    _picked = person.uid;
                    _pickedName = person.displayName;
                  });
                },
        ),
      ),
      SizedBox(height: cp.space.xs),
      CpButton(
        key: const Key('transfer.offer'),
        label: strings.offer,
        expand: true,
        busy: _busy,
        onPressed: picked == null || _busy
            ? null
            : () => _offer(picked, nameOf(picked)),
      ),
    ];
  }
}

class _OfferToMe extends StatelessWidget {
  const _OfferToMe({
    required this.from,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final String from;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.transfer;
    return Container(
      key: const Key('transfer.offerToMe'),
      padding: EdgeInsets.all(cp.space.lg),
      decoration: BoxDecoration(
        color: cp.colors.accentSoft,
        borderRadius: cp.radii.md,
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: cp.space.md,
        children: [
          Row(
            spacing: cp.space.sm,
            children: [
              Icon(
                CpIcons.owner,
                size: cp.sizes.iconMd,
                color: cp.colors.accent,
              ),
              Expanded(
                child: Text(
                  strings.offerToYou(from),
                  style: cp.type.titleMedium.copyWith(color: cp.colors.text),
                ),
              ),
            ],
          ),
          Text(
            strings.offerToYouBody(from),
            style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: cp.space.sm,
            runSpacing: cp.space.sm,
            children: [
              CpButton.secondary(
                key: const Key('transfer.decline'),
                label: strings.decline,
                onPressed: busy ? null : onDecline,
              ),
              CpButton(
                key: const Key('transfer.accept'),
                label: strings.accept,
                busy: busy,
                onPressed: busy ? null : onAccept,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({
    required this.name,
    required this.canWithdraw,
    required this.onWithdraw,
  });

  final String name;
  final bool canWithdraw;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.transfer;
    return Column(
      key: const Key('transfer.waiting'),
      crossAxisAlignment: .stretch,
      spacing: cp.space.md,
      children: [
        AdminNote(strings.waiting(name), icon: CpIcons.statusDue),
        if (canWithdraw)
          CpButton.secondary(
            key: const Key('transfer.withdraw'),
            label: strings.withdraw,
            expand: true,
            onPressed: onWithdraw,
          ),
      ],
    );
  }
}
