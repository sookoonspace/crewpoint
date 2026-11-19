import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/crew.dart';

/// Picks a task's crew (Req 72), or none, from a sheet. [crewWord] is the
/// event's word for a crew. A crew deleted since the task was saved shows
/// as none.
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

  Future<void> _pick(BuildContext context, String? known) async {
    final none = context.strings.crews.noCrew(crewWord);
    final cp = context.cp;
    final tick = Icon(
      CpIcons.check,
      size: cp.sizes.iconMd,
      color: cp.colors.accent,
    );
    // The sheet returns '' for no crew, and null when dismissed.
    final picked = await showCpSheet<String>(
      context: context,
      title: crewWord,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            CpListRow(
              key: const Key('tasks.create.crew.none'),
              title: none,
              selected: known == null,
              trailing: known == null ? tick : const SizedBox(),
              onTap: () => Navigator.of(sheet).pop(''),
            ),
            for (final crew in crews)
              CpListRow(
                key: Key('tasks.create.crew.${crew.id}'),
                title: crew.name,
                selected: known == crew.id,
                trailing: known == crew.id ? tick : const SizedBox(),
                onTap: () => Navigator.of(sheet).pop(crew.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    onChanged(picked.isEmpty ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final known = crews.where((c) => c.id == selected).firstOrNull;
    return CpSelectField(
      label: crewWord,
      fieldKey: const Key('tasks.create.crew'),
      leadingIcon: CpIcons.members,
      value: known?.name,
      placeholder: context.strings.crews.noCrew(crewWord),
      onTap: () => _pick(context, known?.id),
    );
  }
}
