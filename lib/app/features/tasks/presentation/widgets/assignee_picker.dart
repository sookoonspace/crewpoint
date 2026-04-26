import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

/// Picks an assignee from a list of member UIDs.
///
/// V1: shows truncated UIDs. Display-name hydration arrives with the
/// `usersByIdProvider` planned for Phase 7.
class AssigneePicker extends StatelessWidget {
  const AssigneePicker({
    super.key,
    required this.memberIds,
    required this.selected,
    required this.onChanged,
  });

  final List<String> memberIds;
  final String? selected;
  final ValueChanged<String?> onChanged;

  String _label(String uid) =>
      uid.length > 10 ? '${uid.substring(0, 10)}…' : uid;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Assignee',
        prefixIcon: Icon(Icons.person_outline),
        border: OutlineInputBorder(borderRadius: AppRadius.borderLg),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 0,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          key: const Key('tasks.create.assignee'),
          isExpanded: true,
          value: selected,
          hint: const Text(
            'Unassigned',
            style: TextStyle(color: AppColors.mediumGrey),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Unassigned'),
            ),
            for (final id in memberIds)
              DropdownMenuItem<String?>(value: id, child: Text(_label(id))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
