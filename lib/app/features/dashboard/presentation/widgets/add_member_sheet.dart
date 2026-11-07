import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:share_plus/share_plus.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/loading_animation.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';

/// Bottom sheet showing the event's one active invite (Req 31). The code is
/// made on the server by `generateInviteCode`, through [memberCallsProvider].
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
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Without `roles.manage`, the invite is always for Participants. With it,
    // opening the sheet keeps whatever role the active invite carries.
    _generateCode(roleId: widget.canChooseRole ? null : 'participant');
  }

  /// Gets the active invite, replacing it when [roleId] differs from its role
  /// or [rotate] is set.
  Future<void> _generateCode({String? roleId, bool rotate = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final strings = context.strings.dashboard;
    try {
      final invite = await ref
          .read(memberCallsProvider)
          .generateInviteCode(
            eventId: widget.eventId,
            roleId: roleId ?? _roleId,
            rotate: rotate,
          );

      if (mounted) {
        setState(() {
          _code = invite.code;
          _roleId = invite.roleId;
          _isLoading = false;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      log('Generate invite code failed: ${e.code}', error: e, name: 'invite');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = switch (e.code) {
            'permission-denied' => 'Only admins can generate invite codes.',
            'not-found' => 'Event not found.',
            'failed-precondition' => strings.notOpenToInvites,
            _ => 'Failed to generate code. Please try again.',
          };
        });
      }
    } catch (e) {
      log('Generate invite code error', error: e, name: 'invite');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Requires an internet connection to generate a secure join code.';
        });
      }
    }
  }

  void _copyCode() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: _code!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard'),
        backgroundColor: AppColors.sage,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareCode() async {
    if (_code == null) return;
    await SharePlus.instance.share(
      ShareParams(text: 'Join my event on CrewPoint! Use code: $_code'),
    );
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
          initialValue: roles.any((r) => r.id == current) ? current : null,
          decoration: InputDecoration(labelText: strings.inviteRoleLabel),
          items: [
            for (final role in roles)
              DropdownMenuItem(
                key: Key('dashboard.invite.role.${role.id}'),
                value: role.id,
                child: Text(role.name),
              ),
          ],
          onChanged: (roleId) {
            if (roleId != null && roleId != _roleId) {
              _generateCode(roleId: roleId);
            }
          },
        ),
        Text(strings.inviteRoleHint, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Every colour below comes from the scheme so the sheet moves with the
    // theme. The light-mode values are unchanged: `surfaceContainerHighest`
    // *is* `offWhite`, `outline` *is* `lightGrey`, and `onSurface` *is*
    // `charcoal` in `AppTheme.light()`.
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.viewPaddingOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: .min,
        spacing: AppSpacing.lg,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text(
            context.strings.dashboard.inviteLabel(
              widget.memberLabel ?? const LabelResolver({}).other('member'),
            ),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Column(
                spacing: AppSpacing.md,
                children: [LoadingAnimation(), Text('Generating code...')],
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    key: const Key('dashboard.invite.retry'),
                    onPressed: _generateCode,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          else if (_code != null) ...[
            if (widget.canChooseRole) _rolePicker(context),
            Text(
              'Share this code with people you want to invite',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),

            // Code display
            GestureDetector(
              onTap: _copyCode,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.xl,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Text(
                  _code!,
                  key: const Key('dashboard.invite.code'),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    letterSpacing: 10,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),

            Text(
              'Tap code to copy \u2022 Expires in 24 hours',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            // Action buttons
            Row(
              spacing: AppSpacing.md,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyCode,
                    icon: const Icon(AppIcons.actionCopy, size: 18),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                      side: BorderSide(color: colorScheme.outline),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.borderLg,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PrimaryButton(label: 'Share', onPressed: _shareCode),
                ),
              ],
            ),

            // Replaces the code and keeps the role, for a code that may have
            // leaked.
            TextButton(
              key: const Key('dashboard.invite.rotate'),
              onPressed: () => _generateCode(rotate: true),
              child: const Text('Generate New Code'),
            ),
          ],
        ],
      ),
    );
  }
}
