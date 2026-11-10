import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/link_request.dart';

/// Accounts waiting to be linked (Req 46, route `people/links`). Their
/// verified email matched more than one adult, or only children, so an
/// organizer picks who they are, or says it is not a match. Needs
/// `participants.edit` and `participants.readPrivate`, because each request
/// shows an email.
class LinkRequestsScreen extends ConsumerWidget {
  const LinkRequestsScreen({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.links;
    final me = ref.watch(currentUserIdProvider) ?? '';
    Widget scaffold(Widget body) => Scaffold(
      appBar: AppBar(title: Text(strings.title), elevation: 0),
      body: body,
    );
    if (!event.can(me, 'participants.edit') ||
        !event.can(me, 'participants.readPrivate')) {
      return scaffold(const NoAccessView());
    }
    final requests = ref.watch(linkRequestsProvider(event.id));
    if (requests.hasError && !requests.hasValue) {
      return scaffold(
        LoadFailedView(
          onRetry: () => ref.invalidate(linkRequestsProvider(event.id)),
        ),
      );
    }
    if (!requests.hasValue) {
      return scaffold(
        const Center(
          child: CircularProgressIndicator(key: Key('links.loading')),
        ),
      );
    }
    final items = requests.value!;
    final padding = Breakpoints.screenHorizontalPadding(context);
    return scaffold(
      ListView(
        key: const Key('links.list'),
        padding: EdgeInsets.fromLTRB(
          padding,
          AppSpacing.lg,
          padding,
          AppSpacing.xxxl,
        ),
        children: [
          ContentMaxWidth(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.md,
              children: [
                Text(strings.intro),
                Text(
                  strings.offline,
                  key: const Key('links.online'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      strings.empty,
                      key: const Key('links.empty'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                else
                  for (final r in items)
                    _RequestCard(
                      key: Key('links.request.${r.uid}'),
                      event: event,
                      request: r,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({super.key, required this.event, required this.request});

  final EventModel event;
  final LinkRequest request;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  /// `p:<participantId>` or `g:<groupId>`.
  String? _choice;
  bool _busy = false;
  bool _failed = false;

  Future<void> _resolve({bool dismiss = false}) async {
    final strings = context.strings.links;
    final messenger = ScaffoldMessenger.of(context);
    final choice = _choice;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await ref
          .read(memberCallsProvider)
          .resolveLinkRequest(
            eventId: widget.event.id,
            uid: widget.request.uid,
            participantId: !dismiss && choice!.startsWith('p:')
                ? choice.substring(2)
                : null,
            groupId: !dismiss && choice!.startsWith('g:')
                ? choice.substring(2)
                : null,
            dismiss: dismiss,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(dismiss ? strings.dismissedDone : strings.linkedDone),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.links;
    final theme = Theme.of(context);
    final r = widget.request;
    final id = r.uid;
    final people = ref.watch(
      participantsByIdProvider((
        eventId: widget.event.id,
        ids: r.participantIds.join(','),
      )),
    );
    final groups = ref.watch(
      groupsByIdProvider((eventId: widget.event.id, ids: r.groupIds.join(','))),
    );
    final found = people.value ?? const {};
    final adults = [
      for (final pid in r.participantIds)
        if (found[pid] case final p? when !p.isChild) p,
    ];
    final children = [
      for (final pid in r.participantIds)
        if (found[pid] case final p? when p.isChild) p,
    ];
    final groupNames = groups.value ?? const {};

    final options = <Widget>[
      for (final p in adults)
        RadioListTile<String>(
          key: Key('links.$id.pick.${p.id}'),
          value: 'p:${p.id}',
          title: Text(p.name.isEmpty ? strings.unnamed : p.name),
          subtitle: p.groupId == null
              ? null
              : Text(groupNames[p.groupId]?.name ?? ''),
          contentPadding: EdgeInsets.zero,
        ),
      if (adults.isEmpty)
        for (final gid in r.groupIds)
          RadioListTile<String>(
            key: Key('links.$id.group.$gid'),
            value: 'g:$gid',
            title: Text(
              strings.asAdultOf(
                groupNames[gid]?.name ?? widget.event.words.one('group'),
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.sm,
          children: [
            Text(
              strings.accountLine(r.name, r.email),
              style: theme.textTheme.titleMedium,
            ),
            if (people.isLoading && !people.hasValue)
              const LinearProgressIndicator()
            else ...[
              Text(
                adults.isEmpty ? strings.onlyChildren : strings.pickRecord,
                style: theme.textTheme.bodyMedium,
              ),
              for (final c in children)
                Text(
                  '${c.name} · ${strings.childTag}',
                  key: Key('links.$id.child.${c.id}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              RadioGroup<String>(
                groupValue: _choice,
                onChanged: (v) {
                  if (!_busy) setState(() => _choice = v);
                },
                child: Column(children: options),
              ),
            ],
            if (_failed)
              Text(
                strings.linkFailed,
                key: Key('links.$id.error'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: AppSpacing.sm,
              overflowSpacing: AppSpacing.sm,
              children: [
                TextButton(
                  key: Key('links.$id.dismiss'),
                  onPressed: _busy ? null : () => _resolve(dismiss: true),
                  child: Text(strings.notAMatch),
                ),
                FilledButton(
                  key: Key('links.$id.link'),
                  onPressed: _busy || _choice == null ? null : _resolve,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(strings.link),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
