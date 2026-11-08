import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/forms/app_dropdown.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/crew.dart';

/// Picks a task's crew (Req 72), or none. [crewWord] is the event's word for
/// a crew. A crew deleted since the task was saved shows as none.
class CrewPicker extends StatelessWidget {
  const CrewPicker({
    super.key,
    required this.crews,
    required this.selected,
    required this.onChanged,
    required this.crewWord,
  });

  final List<CrewModel> crews;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final String crewWord;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.crews;
    final known = crews.any((c) => c.id == selected) ? selected : null;
    return AppDropdown<String?>(
      key: const Key('tasks.create.crew'),
      labelText: crewWord,
      hintText: strings.noCrew(crewWord),
      prefixIcon: const Icon(AppIcons.members),
      value: known,
      onChanged: onChanged,
      items: [
        AppDropdownItem<String?>(value: null, label: strings.noCrew(crewWord)),
        for (final crew in crews)
          AppDropdownItem<String?>(value: crew.id, label: crew.name),
      ],
    );
  }
}
