import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_dropdown.dart';

/// Picks an assignee from a list of member UIDs.
///
/// Public API is unchanged — `memberIds`, `displayNames`, `orphanAssigneeId`,
/// `selected`, `onChanged`, and the canonical `Key('tasks.create.assignee')`
/// all behave identically. Internals now delegate to `AppDropdown<String?>`
/// (built on `DropdownButtonFormField`) so this picker rides the form kit's
/// styling + keyboard navigation + Form integration.
///
/// The disabled "(no longer in event)" orphan row is still rendered when
/// `orphanAssigneeId` is non-null and absent from `memberIds`.
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
    final orphan = orphanAssigneeId;
    final hasOrphan = orphan != null && !memberIds.contains(orphan);
    return AppDropdown<String?>(
      key: const Key('tasks.create.assignee'),
      labelText: 'Assignee',
      hintText: 'Unassigned',
      prefixIcon: const Icon(AppIcons.navProfile),
      value: selected,
      onChanged: onChanged,
      items: [
        const AppDropdownItem<String?>(value: null, label: 'Unassigned'),
        for (final id in memberIds)
          AppDropdownItem<String?>(value: id, label: _label(id)),
        if (hasOrphan)
          AppDropdownItem<String?>(
            value: orphan,
            label: '${_label(orphan)} (no longer in event)',
            enabled: false,
          ),
      ],
    );
  }
}
