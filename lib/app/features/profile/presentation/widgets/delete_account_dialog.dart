import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/destructive_button.dart';

/// Multi-step account deletion dialog requiring password confirmation.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key, this.onConfirm});

  final ValueChanged<String>? onConfirm;

  static Future<void> show({
    required BuildContext context,
    ValueChanged<String>? onConfirm,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteAccountDialog(onConfirm: onConfirm),
    );
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  int _step = 0;
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _step == 0 ? 'Delete Account?' : 'Confirm Deletion',
        style: const TextStyle(color: AppColors.terracotta),
      ),
      content: _step == 0
          ? const Text(
              'This will permanently delete all your data, '
              'including events, tasks, messages, and expenses. '
              'This action cannot be undone.',
            )
          : Column(
              mainAxisSize: .min,
              spacing: AppSpacing.lg,
              children: [
                const Text('Enter your password to confirm deletion.'),
                CustomTextField(
                  hintText: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_step == 0)
          TextButton(
            onPressed: () => setState(() => _step = 1),
            child: const Text(
              'Continue',
              style: TextStyle(color: AppColors.terracotta),
            ),
          )
        else
          SizedBox(
            width: 140,
            child: DestructiveButton(
              label: 'Delete Forever',
              onPressed: () {
                final password = _passwordController.text.trim();
                if (password.isEmpty) return;
                widget.onConfirm?.call(password);
                Navigator.of(context).pop();
              },
            ),
          ),
      ],
    );
  }
}
