import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';

/// Sending an urgent message (Spec #186): a ready-made alert or your own
/// words, then Send alert.
class CriticalAlertModal extends StatefulWidget {
  const CriticalAlertModal({super.key, this.onSend});

  final ValueChanged<String>? onSend;

  static Future<void> show({
    required BuildContext context,
    ValueChanged<String>? onSend,
  }) {
    return showCpSheet<void>(
      context: context,
      title: context.strings.chat.urgentTitle,
      builder: (_) => CriticalAlertModal(onSend: onSend),
    );
  }

  @override
  State<CriticalAlertModal> createState() => _CriticalAlertModalState();
}

class _CriticalAlertModalState extends State<CriticalAlertModal> {
  final _customController = TextEditingController();
  String? _selectedAlert;

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
    final cp = context.cp;
    final strings = context.strings.chat;
    final presets = strings.urgentPresets;
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: cp.space.lg,
      children: [
        CpCard(
          child: CpRowGroup(
            children: [
              for (final (i, text) in presets.indexed)
                _AlertOption(
                  key: Key('chat.urgent.preset.$i'),
                  text: text,
                  isSelected: _selectedAlert == text,
                  onTap: () => setState(() {
                    _selectedAlert = text;
                    _customController.clear();
                  }),
                ),
            ],
          ),
        ),
        CpTextField(
          key: const Key('chat.urgent.custom'),
          label: strings.urgentCustomLabel,
          hint: strings.urgentCustomHint,
          controller: _customController,
          maxLines: 3,
          maxLength: ChatMessageModel.maxTextLength,
          onChanged: (_) => setState(() => _selectedAlert = null),
        ),
        CpButton.destructive(
          key: const Key('chat.urgent.send'),
          label: strings.urgentSend,
          icon: CpIcons.statusUrgent,
          expand: true,
          onPressed: _send,
        ),
      ],
    );
  }
}

/// A ready-made alert, chosen like a radio button.
class _AlertOption extends StatelessWidget {
  const _AlertOption({
    super.key,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: cp.sizes.tapMin),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: cp.space.lg,
                vertical: cp.space.md,
              ),
              child: Row(
                spacing: cp.space.md,
                children: [
                  Icon(
                    isSelected ? CpIcons.radioOn : CpIcons.radioOff,
                    size: cp.sizes.iconMd,
                    color: isSelected ? cp.colors.accent : cp.colors.textMuted,
                  ),
                  Expanded(
                    child: Text(
                      text,
                      style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
