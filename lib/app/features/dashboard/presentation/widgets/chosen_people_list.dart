import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/chat/application/people_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/member_picker_sheet.dart';

/// The people chosen for something, such as a crew or a group's adults,
/// with "Choose people" opening the paged member picker (Req 43a). Only the
/// chosen people's names are read, so a large event never loads everyone.
/// Each row's Remove takes that person off.
///
/// Rows are keyed `$keyPrefix.$uid`, their Remove `$keyPrefix.$uid.remove`,
/// and the button `$keyPrefix.choose`.
class ChosenPeopleList extends ConsumerWidget {
  const ChosenPeopleList({
    super.key,
    required this.eventId,
    required this.words,
    required this.chosen,
    required this.onChanged,
    required this.keyPrefix,
    this.exclude = const {},
    this.enabled = true,
    this.emptyText,
  });

  final String eventId;
  final LabelResolver words;
  final Set<String> chosen;
  final ValueChanged<Set<String>> onChanged;
  final String keyPrefix;

  /// People who may not be chosen, left out of the picker.
  final Set<String> exclude;
  final bool enabled;

  /// Shown when nobody is chosen.
  final String? emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cp = context.cp;
    final strings = context.strings.memberPicker;
    final me = ref.watch(currentUserIdProvider);
    final people =
        ref.watch(peopleByIdProvider(PeopleKey(eventId, chosen))).value ??
        const {};
    String nameOf(String uid) {
      final name = people[uid]?.displayName?.trim() ?? '';
      final shown = name.isEmpty ? strings.noName : name;
      return uid == me ? strings.you(shown) : shown;
    }

    final rows = chosen.toList()
      ..sort(
        (a, b) => nameOf(a).toLowerCase().compareTo(nameOf(b).toLowerCase()),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.sm,
      children: [
        if (rows.isEmpty && emptyText != null)
          Text(
            emptyText!,
            key: Key('$keyPrefix.empty'),
            style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
          ),
        if (rows.isNotEmpty)
          CpCard(
            child: CpRowGroup(
              children: [
                for (final uid in rows)
                  CpListRow(
                    key: Key('$keyPrefix.$uid'),
                    leading: CpAvatar(
                      name: nameOf(uid),
                      size: CpAvatarSize.small,
                    ),
                    title: nameOf(uid),
                    trailing: IconButton(
                      key: Key('$keyPrefix.$uid.remove'),
                      tooltip: strings.removePerson(nameOf(uid)),
                      onPressed: enabled
                          ? () => onChanged({...chosen}..remove(uid))
                          : null,
                      icon: Icon(
                        CpIcons.actionClose,
                        size: cp.sizes.iconMd,
                        color: cp.colors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: CpButton.secondary(
            key: Key('$keyPrefix.choose'),
            icon: CpIcons.memberAdd,
            label: strings.choosePeople,
            onPressed: enabled
                ? () async {
                    final picked = await MemberPickerSheet.pickMany(
                      context,
                      eventId: eventId,
                      words: words,
                      initial: chosen,
                      exclude: exclude,
                    );
                    if (picked != null) onChanged(picked);
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
