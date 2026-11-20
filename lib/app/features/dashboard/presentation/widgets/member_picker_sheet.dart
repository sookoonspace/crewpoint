import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/features/auth/domain/models/app_user.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';

/// Picks people in an event a page at a time, searching by the start of a
/// name (Req 43a), so a large event never loads everyone. One person with
/// [pickOne], or several with [pickMany].
class MemberPickerSheet extends ConsumerStatefulWidget {
  const MemberPickerSheet({
    super.key,
    required this.eventId,
    required this.words,
    this.multi = false,
    this.initial = const {},
    this.exclude = const {},
  });

  final String eventId;
  final LabelResolver words;
  final bool multi;

  /// Already chosen, when picking several.
  final Set<String> initial;

  /// Left out of the list, such as people already added.
  final Set<String> exclude;

  /// The person chosen, or null when the sheet is closed without choosing.
  static Future<AppUser?> pickOne(
    BuildContext context, {
    required String eventId,
    required LabelResolver words,
    Set<String> exclude = const {},
  }) async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          MemberPickerSheet(eventId: eventId, words: words, exclude: exclude),
    );
    return result is AppUser ? result : null;
  }

  /// Everyone chosen, starting from [initial], or null when the sheet is
  /// closed without pressing Done.
  static Future<Set<String>?> pickMany(
    BuildContext context, {
    required String eventId,
    required LabelResolver words,
    Set<String> initial = const {},
    Set<String> exclude = const {},
  }) async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MemberPickerSheet(
        eventId: eventId,
        words: words,
        multi: true,
        initial: initial,
        exclude: exclude,
      ),
    );
    return result is Set<String> ? result : null;
  }

  @override
  ConsumerState<MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends ConsumerState<MemberPickerSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  final List<AppUser> _people = [];
  MemberPage? _last;
  bool _loading = true;
  bool _failed = false;
  late final Set<String> _chosen = {...widget.initial};

  /// Bumped on each new search, so a slow answer to an old one is dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _people.clear();
        _last = null;
      }
    });
    try {
      final page = await ref
          .read(userRepositoryProvider)
          .fetchMemberPage(
            widget.eventId,
            search: _search.text,
            after: reset ? null : _last,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _people.addAll(
          page.people.where((p) => !widget.exclude.contains(p.uid)),
        );
        _last = page;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _load(reset: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final strings = context.strings.memberPicker;
    final words = widget.words;
    final me = ref.watch(currentUserIdProvider);
    final hasMore = _last?.hasMore ?? false;
    final muted = cp.type.bodyMedium.copyWith(color: cp.colors.textMuted);

    String label(AppUser person) {
      final name = person.displayName?.trim() ?? '';
      final shown = name.isEmpty ? strings.noName : name;
      return person.uid == me ? strings.you(shown) : shown;
    }

    final Widget? status;
    if (_failed) {
      status = Column(
        key: const Key('members.picker.error'),
        spacing: cp.space.sm,
        children: [
          CpFieldError(strings.loadFailed),
          CpButton.text(
            key: const Key('members.picker.retry'),
            label: strings.retry,
            onPressed: () => _load(reset: _people.isEmpty),
          ),
        ],
      );
    } else if (_loading) {
      status = Center(
        key: const Key('members.picker.loading'),
        child: SizedBox.square(
          dimension: cp.sizes.iconLg,
          child: CircularProgressIndicator(
            strokeWidth: cp.sizes.hairline * 2,
            color: cp.colors.accent,
          ),
        ),
      );
    } else if (_people.isEmpty) {
      status = Text(
        _search.text.trim().isEmpty
            ? strings.noneYet(words.other('member'))
            : strings.noneFound(words.other('member')),
        key: const Key('members.picker.empty'),
        textAlign: TextAlign.center,
        style: muted,
      );
    } else if (hasMore) {
      status = Center(
        child: CpButton.text(
          key: const Key('members.picker.more'),
          label: strings.showMore,
          onPressed: () => _load(reset: false),
        ),
      );
    } else {
      status = null;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                cp.space.lg,
                0,
                cp.space.lg,
                cp.space.md,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  widget.multi
                      ? strings.chooseMany(words.other('member'))
                      : strings.chooseOne(words.one('member')),
                  style: cp.type.titleLarge.copyWith(color: cp.colors.text),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: cp.space.lg),
              child: CpSearchField(
                fieldKey: const Key('members.picker.search'),
                controller: _search,
                hint: strings.search(words.other('member')),
                onChanged: _onSearch,
              ),
            ),
            Flexible(
              child: ListView.builder(
                key: const Key('members.picker.list'),
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(vertical: cp.space.sm),
                itemCount: _people.length + (status == null ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index == _people.length) {
                    return Padding(
                      padding: EdgeInsets.all(cp.space.md),
                      child: status,
                    );
                  }
                  final person = _people[index];
                  final key = Key('members.picker.row.${person.uid}');
                  if (!widget.multi) {
                    return CpListRow(
                      key: key,
                      leading: CpAvatar(
                        name: label(person),
                        size: CpAvatarSize.small,
                      ),
                      title: label(person),
                      trailing: const SizedBox.shrink(),
                      onTap: () => Navigator.of(context).pop(person),
                    );
                  }
                  final on = _chosen.contains(person.uid);
                  void toggle() => setState(
                    () => on
                        ? _chosen.remove(person.uid)
                        : _chosen.add(person.uid),
                  );
                  return CpListRow(
                    key: key,
                    leading: Checkbox(
                      value: on,
                      activeColor: cp.colors.accent,
                      onChanged: (_) => toggle(),
                    ),
                    title: label(person),
                    trailing: const SizedBox.shrink(),
                    selected: on,
                    onTap: toggle,
                  );
                },
              ),
            ),
            if (widget.multi)
              Padding(
                padding: EdgeInsets.all(cp.space.lg),
                child: CpButton(
                  key: const Key('members.picker.done'),
                  label: strings.done(_chosen.length),
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(_chosen),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
