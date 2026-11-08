import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
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

    final users =
        ref.watch(usersByIdProvider(usersByIds(event.memberIds))).value ??
        const {};
    String nameOf(String uid) {
      if (uid == me) return strings.you;
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
      body = const Center(
        child: CircularProgressIndicator(key: Key('transfer.loading')),
      );
    } else if (!canSee) {
      body = const NoAccessView();
    } else {
      final ownerId = event.memberIds.firstWhere(
        event.isOwner,
        orElse: () => event.creatorId,
      );
      body = ContentMaxWidth(
        key: const Key('transfer.body'),
        maxWidth: 720,
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: Breakpoints.screenHorizontalPadding(context),
            vertical: AppSpacing.lg,
          ),
          children: [
            Text(
              strings.currentOwner(nameOf(ownerId)),
              key: const Key('transfer.owner'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
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
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.title), elevation: 0),
      body: body,
    );
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
      return [Text(strings.noOneElse, key: const Key('transfer.empty'))];
    }
    final picked = _picked;
    return [
      Text(strings.pickHeading, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: AppSpacing.xs),
      Text(strings.pickHint, style: Theme.of(context).textTheme.bodySmall),
      RadioGroup<String>(
        groupValue: picked,
        onChanged: (uid) {
          if (!_busy) setState(() => _picked = uid);
        },
        child: Column(
          children: [
            for (final uid in others)
              RadioListTile<String>(
                key: Key('transfer.pick.$uid'),
                value: uid,
                title: Text(nameOf(uid)),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      FilledButton(
        key: const Key('transfer.offer'),
        onPressed: picked == null || _busy
            ? null
            : () => _offer(picked, nameOf(picked)),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: Text(strings.offer),
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
    final strings = context.strings.transfer;
    final theme = Theme.of(context);
    return Card(
      key: const Key('transfer.offerToMe'),
      elevation: 0,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: AppSpacing.md,
          children: [
            Text(
              strings.offerToYou(from),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            Text(
              strings.offerToYouBody(from),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton(
                  key: const Key('transfer.decline'),
                  onPressed: busy ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(88, 48),
                  ),
                  child: Text(strings.decline),
                ),
                FilledButton(
                  key: const Key('transfer.accept'),
                  onPressed: busy ? null : onAccept,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 48),
                  ),
                  child: Text(strings.accept),
                ),
              ],
            ),
          ],
        ),
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
    final strings = context.strings.transfer;
    return Column(
      key: const Key('transfer.waiting'),
      crossAxisAlignment: .stretch,
      spacing: AppSpacing.md,
      children: [
        Text(strings.waiting(name)),
        if (canWithdraw)
          OutlinedButton(
            key: const Key('transfer.withdraw'),
            onPressed: onWithdraw,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(strings.withdraw),
          ),
      ],
    );
  }
}
