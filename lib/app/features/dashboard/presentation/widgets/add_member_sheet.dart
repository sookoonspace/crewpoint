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
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/loading_animation.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
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
    final strings = context.strings.roles;
    final roles = [
      for (final role
          in ref.watch(eventRolesProvider(widget.eventId)).value ??
              const <RoleDefinition>[])
        if (!role.isOwner) role,
    ];
    final current = _roleId ?? 'participant';
    return Column(
      crossAxisAlignment: .stretch,
      spacing: AppSpacing.xs,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('dashboard.invite.role'),
          isExpanded: true,
          initialValue: roles.any((r) => r.id == current) ? current : null,
          decoration: InputDecoration(labelText: strings.inviteRoleLabel),
          items: [
            for (final role in roles)
              DropdownMenuItem(
                key: Key('dashboard.invite.role.${role.id}'),
                value: role.id,
                child: Text(role.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (roleId) {
            if (roleId != null && roleId != _roleId) {
              _generateCode(roleId: roleId);
            }
          },
        ),
        Text(
          strings.inviteRoleHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _expiry(BuildContext context) {
    final strings = context.strings.invites;
    final theme = Theme.of(context);
    final event = ref.watch(eventByIdProvider(widget.eventId));
    final expires = _expiresAt;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      children: [
        if (expires != null)
          Text(
            strings.expires(
              DateFormat.yMMMd().add_jm().format(expires.toLocal()),
            ),
            key: const Key('dashboard.invite.expires'),
            style: theme.textTheme.bodyMedium,
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
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.calendar,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      strings.changeExpiry,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
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
    final strings = context.strings.invites;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.viewPaddingOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: AppSpacing.lg,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            context.strings.dashboard.inviteLabel(
              widget.memberLabel ?? const LabelResolver({}).other('member'),
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Column(
                key: const Key('dashboard.invite.loading'),
                spacing: AppSpacing.md,
                children: [const LoadingAnimation(), Text(strings.generating)],
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Column(
                spacing: AppSpacing.lg,
                children: [
                  Icon(
                    AppIcons.wifiOff,
                    size: 48,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  Text(
                    _errorMessage!,
                    key: const Key('dashboard.invite.error'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    key: const Key('dashboard.invite.retry'),
                    onPressed: _retry,
                    child: Text(strings.retry),
                  ),
                ],
              ),
            )
          else if (_code != null) ...[
            if (widget.canChooseRole) _rolePicker(context),
            Text(
              strings.shareHint,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),

            // A QR code needs dark modules on a light ground to scan, in
            // either theme, so these two colours are fixed on purpose.
            Center(
              child: Container(
                key: const Key('dashboard.invite.qr'),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.borderLg,
                  border: Border.all(color: colorScheme.outline),
                ),
                child: ref
                    .watch(qrRendererProvider)
                    .render(
                      _link,
                      size: 200,
                      foreground: Colors.black,
                      background: Colors.white,
                      semanticLabel: strings.qrLabel(_link),
                    ),
              ),
            ),

            Text(
              strings.linkLabel,
              style: theme.textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
            SelectableText(
              _link,
              key: const Key('dashboard.invite.link'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),

            Text(
              strings.codeLabel,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Text(
                  _code!,
                  key: const Key('dashboard.invite.code'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    letterSpacing: 8,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),

            _expiry(context),

            OverflowBar(
              alignment: MainAxisAlignment.center,
              spacing: AppSpacing.md,
              overflowSpacing: AppSpacing.sm,
              overflowAlignment: OverflowBarAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const Key('dashboard.invite.copy'),
                  onPressed: _copyLink,
                  icon: const Icon(AppIcons.actionCopy, size: 18),
                  label: Text(strings.copyLink),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                ),
                FilledButton.icon(
                  key: const Key('dashboard.invite.share'),
                  onPressed: _share,
                  icon: Icon(AppIcons.actionShare, size: 18),
                  label: Text(strings.share),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ),

            // Replaces the link and keeps the role and expiry, for one that
            // was shared too widely.
            TextButton(
              key: const Key('dashboard.invite.rotate'),
              onPressed: () => _generateCode(rotate: true),
              child: Text(strings.rotate),
            ),
            Text(
              strings.rotateHint,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
