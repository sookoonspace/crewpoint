import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/invite.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:share_plus/share_plus.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_colors.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// Bottom sheet showing the event's one active invite (Req 31, 47): a link
/// and QR code that open `/join/:code`, the code itself, the role it carries
/// and when it expires, which the organizer can change (Req 56). The invite
/// is made on the server by `generateInviteCode`, through
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

  /// Whether the viewer holds `roles.manage`, and so may pick the role the
  /// invite carries. Everyone else invites Participants.
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

class _AddMemberSheetState extends ConsumerState<AddMemberSheet> {
  String? _code;
  String? _roleId;
  DateTime? _expiresAt;
  bool _isLoading = true;
  String? _errorMessage;

  /// What the last failed call asked for, so retrying asks again.
  ({String? roleId, bool rotate, DateTime? expiresAt})? _lastAsk;

  @override
  void initState() {
    super.initState();
    // Without `roles.manage`, the invite is always for Participants. With it,
    // opening the sheet keeps whatever role the active invite carries.
    _generateCode(roleId: widget.canChooseRole ? null : 'participant');
  }

  /// Gets the active invite, replacing it when [roleId] differs from its role
  /// or [rotate] is set. [expiresAt] changes when it expires, keeping it.
  Future<void> _generateCode({
    String? roleId,
    bool rotate = false,
    DateTime? expiresAt,
  }) async {
    _lastAsk = (roleId: roleId, rotate: rotate, expiresAt: expiresAt);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final strings = context.strings;
    try {
      final invite = await ref
          .read(memberCallsProvider)
          .generateInviteCode(
            eventId: widget.eventId,
            roleId: roleId ?? _roleId,
            rotate: rotate,
            expiresAt: expiresAt,
          );

      if (mounted) {
        setState(() {
          _code = invite.code;
          _roleId = invite.roleId;
          _expiresAt = invite.expiresAt;
          _isLoading = false;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      log('Generate invite code failed: ${e.code}', error: e, name: 'invite');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = switch (e.code) {
            'permission-denied' => strings.invites.permissionDenied,
            'not-found' => strings.invites.eventGone,
            'failed-precondition' => strings.dashboard.notOpenToInvites,
            'unavailable' || 'deadline-exceeded' => strings.invites.offline,
            _ => strings.invites.failed,
          };
        });
      }
    } catch (e) {
      log('Generate invite code error', error: e, name: 'invite');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = strings.invites.offline;
        });
      }
    }
  }

  void _retry() {
    final ask = _lastAsk;
    _generateCode(
      roleId: ask?.roleId,
      rotate: ask?.rotate ?? false,
      expiresAt: ask?.expiresAt,
    );
  }

  String get _link => inviteLink(_code!);

  void _copyLink() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: _link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.strings.invites.copied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _share() async {
    if (_code == null) return;
    final title = ref.read(eventByIdProvider(widget.eventId))?.title ?? '';
    await SharePlus.instance.share(
      ShareParams(
        text: context.strings.invites.shareText(title, _link, _code!),
      ),
    );
  }

  Future<void> _changeExpiry(Object choice) async {
    final now = DateTime.now();
    DateTime? at;
    if (choice is InviteExpiry) {
      at = inviteExpiryFor(
        choice,
        ref.read(eventByIdProvider(widget.eventId)),
        now,
      );
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: _expiresAt?.toLocal() ?? now,
        firstDate: now,
        lastDate: now.add(const Duration(days: maxInviteDays - 1)),
      );
      if (picked != null) at = expiryOnDate(picked, now);
    }
    if (at != null && mounted) _generateCode(expiresAt: at);
  }

  /// The role the invite carries. Changing it replaces the code.
  Widget _rolePicker(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.roles;
    final roles = [
      for (final role
          in ref.watch(eventRolesProvider(widget.eventId)).value ??
              const <RoleDefinition>[])
        if (!role.isOwner) role,
    ];
    final current = _roleId ?? 'participant';
    final currentRole = roles.where((r) => r.id == current).firstOrNull;
    return CpSelectField(
      fieldKey: const Key('dashboard.invite.role'),
      label: strings.inviteRoleLabel,
      value: currentRole?.name,
      help: strings.inviteRoleHint,
      leadingIcon: CpIcons.shield,
      onTap: () async {
        final picked = await showCpSheet<String>(
          context: context,
          title: strings.inviteRoleLabel,
          builder: (sheet) => CpCard(
            child: CpRowGroup(
              children: [
                for (final role in roles)
                  CpListRow(
                    key: Key('dashboard.invite.role.${role.id}'),
                    title: role.name,
                    trailing: role.id == current
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
        if (picked != null && picked != _roleId && mounted) {
          _generateCode(roleId: picked);
        }
      },
    );
  }

  Widget _expiry(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.invites;
    final event = ref.watch(eventByIdProvider(widget.eventId));
    final expires = _expiresAt;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: cp.space.sm,
      children: [
        if (expires != null)
          Text(
            strings.expires(
              DateFormat.yMMMd().add_jm().format(expires.toLocal()),
            ),
            key: const Key('dashboard.invite.expires'),
            textAlign: TextAlign.center,
            style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
          ),
        PopupMenuButton<Object>(
          key: const Key('dashboard.invite.expiry'),
          tooltip: strings.changeExpiry,
          onSelected: _changeExpiry,
          itemBuilder: (_) => [
            for (final choice in inviteExpiryChoices(event, DateTime.now()))
              PopupMenuItem(
                key: Key('dashboard.invite.expiry.${choice.name}'),
                value: choice,
                child: Text(strings.expiryChoice(choice.name)),
              ),
            PopupMenuItem(
              key: const Key('dashboard.invite.expiry.date'),
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
                      style: cp.type.labelLarge.copyWith(
                        color: cp.colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.invites;
    final muted = cp.type.bodyMedium.copyWith(color: cp.colors.textMuted);
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
              semanticLabel: strings.generating,
              label: strings.generating,
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
                  onPressed: _retry,
                ),
              ],
            )
          else if (_code != null) ...[
            if (widget.canChooseRole) _rolePicker(context),
            Text(strings.shareHint, style: muted, textAlign: TextAlign.center),

            // A QR code needs dark modules on a light ground to scan, in
            // either theme, so these two colours are fixed on purpose.
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
                      _link,
                      size: cp.sizes.qrCode,
                      foreground: CpFixedColors.qrInk,
                      background: CpFixedColors.qrPaper,
                      semanticLabel: strings.qrLabel(_link),
                    ),
              ),
            ),

            CpCard(
              padding: EdgeInsets.all(cp.space.lg),
              child: Column(
                spacing: cp.space.sm,
                children: [
                  Text(
                    strings.linkLabel,
                    style: cp.type.labelLarge.copyWith(
                      color: cp.colors.textMuted,
                    ),
                  ),
                  SelectableText(
                    _link,
                    key: const Key('dashboard.invite.link'),
                    textAlign: TextAlign.center,
                    style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                  ),
                  SizedBox(height: cp.space.xs),
                  Text(
                    strings.codeLabel,
                    style: cp.type.labelLarge.copyWith(
                      color: cp.colors.textMuted,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: cp.space.xl,
                      vertical: cp.space.md,
                    ),
                    decoration: BoxDecoration(
                      color: cp.colors.fill,
                      borderRadius: cp.radii.lg,
                    ),
                    child: Text(
                      _code!,
                      key: const Key('dashboard.invite.code'),
                      style: cp.type.headlineMedium.copyWith(
                        letterSpacing: cp.space.sm,
                        color: cp.colors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _expiry(context),

            Wrap(
              alignment: WrapAlignment.center,
              spacing: cp.space.md,
              runSpacing: cp.space.sm,
              children: [
                CpButton.secondary(
                  key: const Key('dashboard.invite.copy'),
                  label: strings.copyLink,
                  icon: CpIcons.actionCopy,
                  onPressed: _copyLink,
                ),
                CpButton(
                  key: const Key('dashboard.invite.share'),
                  label: strings.share,
                  icon: CpIcons.actionShare,
                  onPressed: _share,
                ),
              ],
            ),

            // Replaces the link and keeps the role and expiry, for one that
            // was shared too widely.
            Column(
              spacing: cp.space.xs,
              children: [
                CpButton.text(
                  key: const Key('dashboard.invite.rotate'),
                  label: strings.rotate,
                  icon: CpIcons.actionRetry,
                  onPressed: () => _generateCode(rotate: true),
                ),
                Text(
                  strings.rotateHint,
                  style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
