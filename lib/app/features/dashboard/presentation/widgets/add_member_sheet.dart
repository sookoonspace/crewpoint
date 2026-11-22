import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/invite.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:share_plus/share_plus.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_colors.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// Bottom sheet listing the event's member invite links (Req 47, 56;
/// Spec #233 Req 15, #238). Each link carries a role, an expiry and,
/// optionally, works for one join only; each shows its state, with copy,
/// share, QR code, a new expiry and turn off. "New link" makes another.
/// An event with no links yet gets a Participant link on opening, so
/// inviting stays one tap. The links live on the server, through
/// [memberCallsProvider].
class AddMemberSheet extends ConsumerStatefulWidget {
  const AddMemberSheet({
    super.key,
    required this.eventId,
    this.memberLabel,
    this.canChooseRole = false,
  });

  final String eventId;

  /// This event's word for members. Null uses the default.
  final String? memberLabel;

  /// Whether the viewer holds `roles.manage`, and so may make links into
  /// any role. Everyone else makes Participant links.
  final bool canChooseRole;

  static Future<void> show({
    required BuildContext context,
    required String eventId,
    String? memberLabel,
    bool canChooseRole = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => AddMemberSheet(
        eventId: eventId,
        memberLabel: memberLabel,
        canChooseRole: canChooseRole,
      ),
    );
  }

  @override
  ConsumerState<AddMemberSheet> createState() => _AddMemberSheetState();
}

/// What the new link form asks for. A null [expiresAt] is the event's
/// usual expiry, which the server works out.
typedef _NewLink = ({String roleId, DateTime? expiresAt, bool singleUse});

class _AddMemberSheetState extends ConsumerState<AddMemberSheet> {
  List<InviteLink> _links = const [];
  bool _isLoading = true;
  String? _errorMessage;

  /// The link being changed, or `new` while one is made.
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _messageFor(Object e) {
    final strings = context.strings;
    if (e is FirebaseFunctionsException) {
      log('Invite links failed: ${e.code}', error: e, name: 'invite');
      return switch (e.code) {
        'permission-denied' => strings.invites.permissionDenied,
        'not-found' => strings.invites.eventGone,
        'failed-precondition' => strings.dashboard.notOpenToInvites,
        'unavailable' || 'deadline-exceeded' => strings.invites.offline,
        _ => strings.invites.failed,
      };
    }
    // Includes a sheet built without a provider scope, and no connection.
    log('Invite links error', error: e, name: 'invite');
    return strings.invites.offline;
  }

  /// Lists the links; with none yet, makes a Participant link.
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final calls = ref.read(memberCallsProvider);
      var links = await calls.listInviteLinks(widget.eventId);
      if (links.isEmpty) {
        links = [
          await calls.createInviteLink(
            eventId: widget.eventId,
            roleId: 'participant',
          ),
        ];
      }
      if (mounted) {
        setState(() {
          _links = links;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _messageFor(e);
        });
      }
    }
  }

  /// Runs [change] on one link, showing a failure without losing the list.
  Future<void> _change(
    String busy,
    Future<InviteLink> Function() change, {
    String? done,
  }) async {
    setState(() => _busy = busy);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final link = await change();
      if (!mounted) return;
      setState(() {
        final i = _links.indexWhere((l) => l.code == link.code);
        _links = i < 0
            ? [link, ..._links]
            : [..._links.take(i), link, ..._links.skip(i + 1)];
      });
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(_messageFor(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  List<RoleDefinition> get _roles => [
    for (final role
        in ref.watch(eventRolesProvider(widget.eventId)).value ??
            const <RoleDefinition>[])
      if (!role.isOwner) role,
  ];

  String _roleName(String roleId) =>
      _roles.where((r) => r.id == roleId).firstOrNull?.name ??
      RoleCatalogue.current.presets
          .where((r) => r.id == roleId)
          .firstOrNull
          ?.name ??
      roleId;

  Future<void> _newLink() async {
    final event = ref.read(eventByIdProvider(widget.eventId));
    final picked = await showCpSheet<_NewLink>(
      context: context,
      title: context.strings.invites.newLinkTitle,
      builder: (_) => _NewLinkForm(
        roles: widget.canChooseRole
            ? _roles
            : _roles.where((r) => r.id == 'participant').toList(),
        event: event,
      ),
    );
    if (picked == null || !mounted) return;
    await _change(
      'new',
      () => ref
          .read(memberCallsProvider)
          .createInviteLink(
            eventId: widget.eventId,
            roleId: picked.roleId,
            expiresAt: picked.expiresAt,
            singleUse: picked.singleUse,
          ),
    );
  }

  void _copy(InviteLink link) {
    Clipboard.setData(ClipboardData(text: inviteLink(link.code)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.strings.invites.copied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _share(InviteLink link) async {
    final title = ref.read(eventByIdProvider(widget.eventId))?.title ?? '';
    await SharePlus.instance.share(
      ShareParams(
        text: context.strings.invites.shareText(
          title,
          inviteLink(link.code),
          link.code,
        ),
      ),
    );
  }

  Future<void> _showQr(InviteLink link) => showCpSheet<void>(
    context: context,
    title: _roleName(link.roleId),
    builder: (_) => _QrCode(url: inviteLink(link.code)),
  );

  Future<void> _changeExpiry(InviteLink link, Object choice) async {
    final at = await _pickExpiry(
      context,
      choice,
      ref.read(eventByIdProvider(widget.eventId)),
      link.expiresAt,
    );
    if (at == null || !mounted) return;
    await _change(
      link.code,
      () => ref
          .read(memberCallsProvider)
          .setInviteLinkExpiry(
            eventId: widget.eventId,
            code: link.code,
            expiresAt: at,
          ),
    );
  }

  Future<void> _turnOff(InviteLink link) async {
    final strings = context.strings.invites;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => CpDialog(
        title: strings.turnOffTitle,
        message: strings.turnOffMessage,
        actions: [
          CpButton.text(
            key: const Key('dashboard.invite.turnOff.cancel'),
            label: strings.cancel,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
          CpButton.destructive(
            key: const Key('dashboard.invite.turnOff.confirm'),
            label: strings.turnOff,
            icon: CpIcons.inviteOff,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _change(
      link.code,
      () => ref
          .read(memberCallsProvider)
          .turnOffInviteLink(eventId: widget.eventId, code: link.code),
      done: strings.turnedOff,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.invites;
    final muted = cp.type.bodyMedium.copyWith(color: cp.colors.textMuted);
    final now = DateTime.now();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        cp.space.lg,
        0,
        cp.space.lg,
        MediaQuery.viewPaddingOf(context).bottom + cp.space.xl,
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: cp.space.lg,
        children: [
          Semantics(
            header: true,
            child: Text(
              context.strings.dashboard.inviteLabel(
                widget.memberLabel ?? const LabelResolver({}).other('member'),
              ),
              textAlign: TextAlign.center,
              style: cp.type.titleLarge.copyWith(color: cp.colors.text),
            ),
          ),
          if (_isLoading)
            CpLoadingState(
              key: const Key('dashboard.invite.loading'),
              semanticLabel: strings.loading,
              label: strings.loading,
            )
          else if (_errorMessage != null)
            Column(
              spacing: cp.space.md,
              children: [
                Icon(
                  CpIcons.wifiOff,
                  size: cp.sizes.iconXl,
                  color: cp.colors.textMuted,
                ),
                Text(
                  _errorMessage!,
                  key: const Key('dashboard.invite.error'),
                  style: muted,
                  textAlign: TextAlign.center,
                ),
                CpButton.secondary(
                  key: const Key('dashboard.invite.retry'),
                  label: strings.retry,
                  icon: CpIcons.actionRetry,
                  onPressed: _load,
                ),
              ],
            )
          else ...[
            Text(strings.shareHint, style: muted, textAlign: TextAlign.center),
            CpButton(
              key: const Key('dashboard.invite.new'),
              label: strings.newLink,
              icon: CpIcons.actionAdd,
              busy: _busy == 'new',
              onPressed: _busy == null ? _newLink : null,
            ),
            if (_links.isEmpty)
              Text(
                strings.noLinks,
                key: const Key('dashboard.invite.empty'),
                style: muted,
                textAlign: TextAlign.center,
              ),
            for (final link in usableFirst(_links, now))
              _LinkCard(
                key: Key('dashboard.invite.${link.code}'),
                link: link,
                roleName: _roleName(link.roleId),
                now: now,
                expiryChoices: inviteExpiryChoices(
                  ref.watch(eventByIdProvider(widget.eventId)),
                  now,
                ),
                busy: _busy == link.code,
                onCopy: () => _copy(link),
                onShare: () => _share(link),
                onQr: () => _showQr(link),
                onExpiry: (choice) => _changeExpiry(link, choice),
                onTurnOff: () => _turnOff(link),
              ),
          ],
        ],
      ),
    );
  }
}

/// The date an expiry choice ends on: a preset, or a day picked from a
/// calendar starting at [current]. Null when nothing was picked.
Future<DateTime?> _pickExpiry(
  BuildContext context,
  Object choice,
  EventModel? event,
  DateTime? current,
) async {
  final now = DateTime.now();
  if (choice is InviteExpiry) return inviteExpiryFor(choice, event, now);
  final picked = await showDatePicker(
    context: context,
    initialDate: current != null && current.isAfter(now)
        ? current.toLocal()
        : now,
    firstDate: now,
    lastDate: now.add(const Duration(days: maxInviteDays - 1)),
  );
  return picked == null ? null : expiryOnDate(picked, now);
}

String _when(DateTime at) => DateFormat.yMMMd().add_jm().format(at.toLocal());

/// One invite link: its role and state, the link and code, its expiry,
/// whether it is single use and how often it was used, and, while it works,
/// its actions. Keys start `dashboard.invite.<code>`.
class _LinkCard extends StatelessWidget {
  const _LinkCard({
    super.key,
    required this.link,
    required this.roleName,
    required this.now,
    required this.expiryChoices,
    required this.busy,
    required this.onCopy,
    required this.onShare,
    required this.onQr,
    required this.onExpiry,
    required this.onTurnOff,
  });

  final InviteLink link;
  final String roleName;
  final DateTime now;
  final List<InviteExpiry> expiryChoices;
  final bool busy;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onQr;
  final ValueChanged<Object> onExpiry;
  final VoidCallback onTurnOff;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.invites;
    final state = link.stateAt(now);
    final active = state == InviteLinkState.active;
    final k = 'dashboard.invite.${link.code}';
    final muted = cp.type.bodySmall.copyWith(color: cp.colors.textMuted);
    final expires = link.expiresAt;
    final String? expiryLine = switch (state) {
      InviteLinkState.active =>
        expires == null ? strings.noExpiry : strings.expires(_when(expires)),
      InviteLinkState.expired when expires != null => strings.expiredOn(
        _when(expires),
      ),
      _ => null,
    };
    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: cp.space.sm,
        children: [
          Wrap(
            spacing: cp.space.sm,
            runSpacing: cp.space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                roleName,
                key: Key('$k.role'),
                style: cp.type.titleMedium.copyWith(color: cp.colors.text),
              ),
              CpTag(
                key: Key('$k.state'),
                label: strings.state(state.name),
                tone: active ? CpTagTone.accent : CpTagTone.quiet,
                icon: switch (state) {
                  InviteLinkState.active => CpIcons.statusDone,
                  InviteLinkState.used => CpIcons.inviteUsed,
                  InviteLinkState.expired => CpIcons.statusDue,
                  InviteLinkState.off => CpIcons.inviteOff,
                },
              ),
            ],
          ),
          if (active) ...[
            Text(
              strings.linkLabel,
              style: cp.type.labelLarge.copyWith(color: cp.colors.textMuted),
            ),
            SelectableText(
              inviteLink(link.code),
              key: Key('$k.link'),
              style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
            ),
            Text(
              strings.codeLabel,
              style: cp.type.labelLarge.copyWith(color: cp.colors.textMuted),
            ),
          ],
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: cp.space.lg,
              vertical: cp.space.sm,
            ),
            decoration: BoxDecoration(
              color: cp.colors.fill,
              borderRadius: cp.radii.lg,
            ),
            child: Text(
              link.code,
              key: Key('$k.code'),
              style: (active ? cp.type.headlineMedium : cp.type.titleMedium)
                  .copyWith(
                    letterSpacing: cp.space.sm,
                    color: active ? cp.colors.text : cp.colors.textMuted,
                  ),
            ),
          ),
          if (expiryLine != null)
            Text(expiryLine, key: Key('$k.expires'), style: muted),
          Text(
            link.singleUse ? strings.singleUse : strings.manyUse,
            key: Key('$k.use'),
            style: muted,
          ),
          Text(strings.uses(link.uses), key: Key('$k.uses'), style: muted),
          if (active)
            Wrap(
              spacing: cp.space.sm,
              runSpacing: cp.space.sm,
              children: [
                CpButton.secondary(
                  key: Key('$k.copy'),
                  label: strings.copyLink,
                  icon: CpIcons.actionCopy,
                  onPressed: onCopy,
                ),
                CpButton.secondary(
                  key: Key('$k.share'),
                  label: strings.share,
                  icon: CpIcons.actionShare,
                  onPressed: onShare,
                ),
                CpButton.text(
                  key: Key('$k.qr'),
                  label: strings.showQr,
                  icon: CpIcons.inviteQr,
                  onPressed: onQr,
                ),
                _ExpiryMenu(
                  key: Key('$k.expiry'),
                  menuKey: '$k.expiry',
                  choices: expiryChoices,
                  onSelected: onExpiry,
                  enabled: !busy,
                ),
                CpButton.text(
                  key: Key('$k.turnOff'),
                  label: strings.turnOff,
                  icon: CpIcons.inviteOff,
                  busy: busy,
                  onPressed: busy ? null : onTurnOff,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// "Change expiry": the presets that apply, then a date of one's own.
class _ExpiryMenu extends StatelessWidget {
  const _ExpiryMenu({
    super.key,
    required this.menuKey,
    required this.choices,
    required this.onSelected,
    required this.enabled,
  });

  final String menuKey;
  final List<InviteExpiry> choices;
  final ValueChanged<Object> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.invites;
    return PopupMenuButton<Object>(
      tooltip: strings.changeExpiry,
      enabled: enabled,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final choice in choices)
          PopupMenuItem(
            key: Key('$menuKey.${choice.name}'),
            value: choice,
            child: Text(strings.expiryChoice(choice.name)),
          ),
        PopupMenuItem(
          key: Key('$menuKey.date'),
          value: 'date',
          child: Text(strings.pickDate),
        ),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: cp.sizes.tapMin),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: cp.space.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: cp.space.xs,
            children: [
              Icon(
                CpIcons.calendar,
                size: cp.sizes.iconSm,
                color: cp.colors.accent,
              ),
              Flexible(
                child: Text(
                  strings.changeExpiry,
                  style: cp.type.labelLarge.copyWith(color: cp.colors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A link's QR code. It needs dark modules on a light ground to scan in
/// either theme, so these two colours are fixed on purpose.
class _QrCode extends ConsumerWidget {
  const _QrCode({required this.url});

  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    return Column(
      spacing: cp.space.md,
      children: [
        Center(
          child: Container(
            key: const Key('dashboard.invite.qr'),
            padding: EdgeInsets.all(cp.space.md),
            decoration: BoxDecoration(
              color: CpFixedColors.qrPaper,
              borderRadius: cp.radii.lg,
              border: Border.all(
                color: cp.colors.border,
                width: cp.sizes.hairline,
              ),
            ),
            child: ref
                .watch(qrRendererProvider)
                .render(
                  url,
                  size: cp.sizes.qrCode,
                  foreground: CpFixedColors.qrInk,
                  background: CpFixedColors.qrPaper,
                  semanticLabel: context.strings.invites.qrLabel(url),
                ),
          ),
        ),
        SelectableText(
          url,
          textAlign: TextAlign.center,
          style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
        ),
      ],
    );
  }
}

/// The new link form: the role (one choice for someone without
/// `roles.manage`), the expiry, and single use. Pops a [_NewLink].
class _NewLinkForm extends StatefulWidget {
  const _NewLinkForm({required this.roles, required this.event});

  final List<RoleDefinition> roles;
  final EventModel? event;

  @override
  State<_NewLinkForm> createState() => _NewLinkFormState();
}

class _NewLinkFormState extends State<_NewLinkForm> {
  String _roleId = 'participant';

  /// Null is the event's usual expiry.
  DateTime? _expiresAt;
  String? _expiryLabel;
  bool _singleUse = false;

  RoleDefinition? get _role =>
      widget.roles.where((r) => r.id == _roleId).firstOrNull;

  Future<void> _pickRole() async {
    final cp = context.cp;
    final picked = await showCpSheet<String>(
      context: context,
      title: context.strings.roles.inviteRoleLabel,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            for (final role in widget.roles)
              CpListRow(
                key: Key('dashboard.invite.role.${role.id}'),
                title: role.name,
                trailing: role.id == _roleId
                    ? Icon(
                        CpIcons.statusDone,
                        size: cp.sizes.iconMd,
                        color: cp.colors.accent,
                      )
                    : const SizedBox.shrink(),
                onTap: () => Navigator.of(sheet).pop(role.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _roleId = picked);
  }

  Future<void> _pickExpiryChoice() async {
    final strings = context.strings.invites;
    final now = DateTime.now();
    final picked = await showCpSheet<Object>(
      context: context,
      title: strings.expiryLabel,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            CpListRow(
              key: const Key('dashboard.invite.new.expiry.default'),
              title: strings.expiryDefault,
              onTap: () => Navigator.of(sheet).pop('default'),
            ),
            for (final choice in inviteExpiryChoices(widget.event, now))
              CpListRow(
                key: Key('dashboard.invite.new.expiry.${choice.name}'),
                title: strings.expiryChoice(choice.name),
                onTap: () => Navigator.of(sheet).pop(choice),
              ),
            CpListRow(
              key: const Key('dashboard.invite.new.expiry.date'),
              title: strings.pickDate,
              onTap: () => Navigator.of(sheet).pop('date'),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked == 'default') {
      setState(() {
        _expiresAt = null;
        _expiryLabel = null;
      });
      return;
    }
    final at = await _pickExpiry(context, picked, widget.event, _expiresAt);
    if (at == null || !mounted) return;
    setState(() {
      _expiresAt = at;
      _expiryLabel = picked is InviteExpiry
          ? strings.expiryChoice(picked.name)
          : _when(at);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.invites;
    final roleStrings = context.strings.roles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.lg,
      children: [
        CpCard(
          padding: EdgeInsets.all(cp.space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.md,
            children: [
              if (widget.roles.length > 1)
                CpSelectField(
                  fieldKey: const Key('dashboard.invite.new.role'),
                  label: roleStrings.inviteRoleLabel,
                  value: _role?.name,
                  help: roleStrings.inviteRoleHint,
                  leadingIcon: CpIcons.shield,
                  onTap: _pickRole,
                ),
              CpSelectField(
                fieldKey: const Key('dashboard.invite.new.expiry'),
                label: strings.expiryLabel,
                value: _expiryLabel ?? strings.expiryDefault,
                leadingIcon: CpIcons.calendar,
                onTap: _pickExpiryChoice,
              ),
              CpSwitchRow(
                switchKey: const Key('dashboard.invite.new.singleUse'),
                title: strings.singleUse,
                help: strings.singleUseHelp,
                value: _singleUse,
                onChanged: (v) => setState(() => _singleUse = v),
              ),
            ],
          ),
        ),
        CpButton(
          key: const Key('dashboard.invite.new.create'),
          label: strings.create,
          icon: CpIcons.actionAdd,
          expand: true,
          onPressed: () => Navigator.of(context).pop<_NewLink>((
            roleId: _roleId,
            expiresAt: _expiresAt,
            singleUse: _singleUse,
          )),
        ),
      ],
    );
  }
}
