import 'package:flutter/material.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/member_picker_sheet.dart';

/// The task's assignee. Tapping opens the paged, searchable member picker
/// (Req 43a), so a large event never lists everyone; the clear button
/// leaves the task unassigned.
///
/// [selectedName] is the name already known for [selected], such as the
/// current assignee's. An assignee who has left the event shows as
/// "(no longer in event)" until they are changed or cleared, and cannot be
/// picked again, because the picker lists only people still in the event.
class AssigneePicker extends StatelessWidget {
  const AssigneePicker({
    super.key,
    required this.eventId,
    required this.words,
    required this.selected,
    required this.onChanged,
    this.selectedName,
    this.selectedLeft = false,
  });

  final String eventId;
  final LabelResolver words;
  final String? selected;
  final String? selectedName;
  final bool selectedLeft;

  /// The new assignee and their name, or nulls when cleared.
  final void Function(String? uid, String? name) onChanged;

  String _label(String uid) {
    final name = selectedName;
    if (name != null && name.isNotEmpty) return name;
    return uid.length > 10 ? '${uid.substring(0, 10)}…' : uid;
  }

  Future<void> _pick(BuildContext context) async {
    final person = await MemberPickerSheet.pickOne(
      context,
      eventId: eventId,
      words: words,
    );
    if (person == null) return;
    onChanged(person.uid, person.displayName);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.memberPicker;
    final uid = selected;
    return CpSelectField(
      label: strings.assignee,
      fieldKey: const Key('tasks.create.assignee'),
      leadingIcon: CpIcons.member,
      value: uid == null
          ? null
          : selectedLeft
          ? strings.leftEvent(_label(uid))
          : _label(uid),
      placeholder: strings.unassigned,
      onTap: () => _pick(context),
      clearLabel: strings.clearAssignee,
      clearKey: const Key('tasks.create.assignee.clear'),
      onClear: () => onChanged(null, null),
    );
  }
}
