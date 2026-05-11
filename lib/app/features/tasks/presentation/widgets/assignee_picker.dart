import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_colors.dart';
import 'package:crewpoint_app/app/core/constants/app_radius.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';

/// Picks an assignee from a list of member UIDs.
///
/// Display names hydrate via `usersByIdProvider` upstream and arrive here as
/// the `displayNames` map. UIDs without an entry fall back to a truncated
/// preview (`abcdefghij…`).
class AssigneePicker extends StatelessWidget {
  const AssigneePicker({
    super.key,
    required this.memberIds,
    required this.selected,
    required this.onChanged,
    this.displayNames = const {},
    this.orphanAssigneeId,
  });

  final List<String> memberIds;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final Map<String, String> displayNames;

  /// Optional UID of an assignee no longer in `memberIds` (left the event).
  /// Rendered as a disabled item at the bottom of the dropdown labeled
  /// `<name> (no longer in event)`. Once cleared, cannot be re-selected.
  final String? orphanAssigneeId;

  String _label(String uid) {
    final name = displayNames[uid];
    if (name != null && name.isNotEmpty) return name;
    return uid.length > 10 ? '${uid.substring(0, 10)}…' : uid;
  }

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
            if (orphanAssigneeId != null &&
                !memberIds.contains(orphanAssigneeId))
              DropdownMenuItem<String?>(
                value: orphanAssigneeId,
                enabled: false,
                child: Text(
                  '${_label(orphanAssigneeId!)} (no longer in event)',
                  style: const TextStyle(
                    color: AppColors.mediumGrey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
