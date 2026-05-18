import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/widgets/custom_text_field.dart';
import 'package:crewpoint_app/app/core/widgets/destructive_button.dart';

class CriticalAlertModal extends StatefulWidget {
  const CriticalAlertModal({super.key, this.onSend});

  final ValueChanged<String>? onSend;

  static Future<void> show({
    required BuildContext context,
    ValueChanged<String>? onSend,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CriticalAlertModal(onSend: onSend),
    );
  }

  @override
  State<CriticalAlertModal> createState() => _CriticalAlertModalState();
}

class _CriticalAlertModalState extends State<CriticalAlertModal> {
  final _customController = TextEditingController();
  String? _selectedAlert;

  static const _predefinedAlerts = [
    'Emergency - Everyone stop and check in',
    'Meeting point changed - Check details',
    'Weather alert - Take shelter',
    'Schedule changed - Check new times',
  ];

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _send() {
    final message = _selectedAlert ?? _customController.text.trim();
    if (message.isEmpty) return;
    widget.onSend?.call(message);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        spacing: AppSpacing.lg,
        children: [
          Row(
            spacing: AppSpacing.sm,
            children: [
              const Icon(AppIcons.statusUrgent, color: AppColors.terracotta),
              Text(
                'Send Critical Alert',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          ...List.generate(
            _predefinedAlerts.length,
            (index) => _AlertOption(
              text: _predefinedAlerts[index],
              isSelected: _selectedAlert == _predefinedAlerts[index],
              onTap: () => setState(() {
                _selectedAlert = _predefinedAlerts[index];
                _customController.clear();
              }),
            ),
          ),
          CustomTextField(
            hintText: 'Or type a custom alert...',
            controller: _customController,
            onChanged: (_) => setState(() => _selectedAlert = null),
          ),
          DestructiveButton(label: 'Send Alert', onPressed: _send),
        ],
      ),
    );
  }
}

class _AlertOption extends StatelessWidget {
  const _AlertOption({
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.terracottaLight.withValues(alpha: 0.15)
              : null,
          border: Border.all(
            color: isSelected ? AppColors.terracotta : AppColors.lightGrey,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
