import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/participants/application/roster_controller.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/link_request.dart';

/// Accounts waiting to be linked (Req 46, route `people/links`). Their
/// verified email or phone matched more than one adult, or only children,
/// so an organizer picks who they are, or says it is not a match. Needs
/// `participants.edit` and `participants.readPrivate`, because each request
/// shows an email or phone.
class LinkRequestsScreen extends ConsumerWidget {
  const LinkRequestsScreen({super.key, required this.event});

  final EventModel event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.links;
    final me = ref.watch(currentUserIdProvider) ?? '';
    Widget scaffold(Widget body) =>
        AdminScaffold(title: strings.title, body: body);
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
        CpLoadingState.rows(
          key: const Key('links.loading'),
          semanticLabel: strings.title,
        ),
      );
    }
    final items = requests.value!;
    return scaffold(
      AdminList(
        listKey: const Key('links.list'),
        children: [
          AdminNote(strings.intro),
          AdminNote(
            strings.offline,
            key: const Key('links.online'),
            icon: CpIcons.wifiOff,
          ),
          if (items.isEmpty)
            CpCard(
              child: CpListRow(
                key: const Key('links.empty'),
                leading: Icon(
                  CpIcons.statusDoneOutline,
                  size: context.cp.sizes.iconMd,
                  color: context.cp.colors.textMuted,
                ),
                title: strings.empty,
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

    final cp = context.cp;
    Widget option(String value, Key key, String title, {String? subtitle}) {
      final chosen = _choice == value;
      return CpListRow(
        key: key,
        title: title,
        subtitle: subtitle,
        selected: chosen,
        trailing: chosen
            ? Icon(
                CpIcons.statusDone,
                size: cp.sizes.iconMd,
                color: cp.colors.accent,
              )
            : const SizedBox.shrink(),
        onTap: _busy ? null : () => setState(() => _choice = value),
      );
    }

    final options = <Widget>[
      for (final p in adults)
        option(
          'p:${p.id}',
          Key('links.$id.pick.${p.id}'),
          p.name.isEmpty ? strings.unnamed : p.name,
          subtitle: p.groupId == null ? null : groupNames[p.groupId]?.name,
        ),
      if (adults.isEmpty)
        for (final gid in r.groupIds)
          option(
            'g:$gid',
            Key('links.$id.group.$gid'),
            strings.asAdultOf(
              groupNames[gid]?.name ?? widget.event.words.one('group'),
            ),
          ),
    ];
    final muted = cp.type.bodyMedium.copyWith(color: cp.colors.textMuted);

    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          Row(
            spacing: cp.space.md,
            children: [
              CpAvatar(name: r.name ?? r.contact),
              Expanded(
                child: Text(
                  strings.accountLine(r.name, r.contact),
                  style: cp.type.titleMedium.copyWith(color: cp.colors.text),
                ),
              ),
            ],
          ),
          if (people.isLoading && !people.hasValue)
            LinearProgressIndicator(color: cp.colors.accent)
          else ...[
            Text(
              adults.isEmpty ? strings.onlyChildren : strings.pickRecord,
              style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
            ),
            if (children.isNotEmpty)
              Wrap(
                spacing: cp.space.sm,
                runSpacing: cp.space.sm,
                children: [
                  for (final c in children)
                    Text(
                      '${c.name} · ${strings.childTag}',
                      key: Key('links.$id.child.${c.id}'),
                      style: muted,
                    ),
                ],
              ),
            if (options.isNotEmpty)
              Semantics(
                container: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: cp.colors.border),
                    borderRadius: cp.radii.md,
                  ),
                  child: ClipRRect(
                    borderRadius: cp.radii.md,
                    child: CpRowGroup(children: options),
                  ),
                ),
              ),
          ],
          if (_failed)
            CpFieldError(strings.linkFailed, key: Key('links.$id.error')),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: cp.space.sm,
            runSpacing: cp.space.sm,
            children: [
              CpButton.text(
                key: Key('links.$id.dismiss'),
                label: strings.notAMatch,
                onPressed: _busy ? null : () => _resolve(dismiss: true),
              ),
              CpButton(
                key: Key('links.$id.link'),
                label: strings.link,
                busy: _busy,
                onPressed: _choice == null ? null : _resolve,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
