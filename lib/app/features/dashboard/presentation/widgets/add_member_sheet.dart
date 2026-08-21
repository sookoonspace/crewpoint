import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/loading_animation.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';

/// Callable signature for the `generateInviteCode` Cloud Function. Mirrors
/// `MarkTaskCompleteCall` in `TaskRepository` — the seam exists so widget
/// tests can pump this sheet without touching Firebase.
typedef GenerateInviteCodeCall = Future<String?> Function(String eventId);

/// Bottom sheet that generates and displays a join code for inviting members.
/// Code generation is server-side via generateInviteCode Cloud Function.
class AddMemberSheet extends StatefulWidget {
  const AddMemberSheet({
    super.key,
    required this.eventId,
    this.generateInviteCode,
  });

  final String eventId;

  /// Test seam. Defaults to the real `generateInviteCode` callable.
  final GenerateInviteCodeCall? generateInviteCode;

  static Future<void> show({
    required BuildContext context,
    required String eventId,
    GenerateInviteCodeCall? generateInviteCode,
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
        generateInviteCode: generateInviteCode,
      ),
    );
  }

  @override
  State<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<AddMemberSheet> {
  String? _code;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  Future<void> _generateCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final generate = widget.generateInviteCode ?? _callGenerateInviteCode;
      final code = await generate(widget.eventId);

      if (mounted) {
        setState(() {
          _code = code;
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

  /// Real callable — the default for [AddMemberSheet.generateInviteCode].
  static Future<String?> _callGenerateInviteCode(String eventId) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'generateInviteCode',
    );
    final result = await callable.call<Map<String, dynamic>>({
      'eventId': eventId,
    });
    return result.data['code'] as String?;
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
            'Invite Members',
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
                    onPressed: _generateCode,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          else if (_code != null) ...[
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

            TextButton(
              onPressed: _generateCode,
              child: const Text('Generate New Code'),
            ),
          ],
        ],
      ),
    );
  }
}
