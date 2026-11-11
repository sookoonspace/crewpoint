import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
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
    final strings = context.strings.memberPicker;
    final words = widget.words;
    final theme = Theme.of(context);
    final me = ref.watch(currentUserIdProvider);
    final hasMore = _last?.hasMore ?? false;

    String label(AppUser person) {
      final name = person.displayName?.trim() ?? '';
      final shown = name.isEmpty ? strings.noName : name;
      return person.uid == me ? strings.you(shown) : shown;
    }

    final Widget? status;
    if (_failed) {
      status = Column(
        key: const Key('members.picker.error'),
        spacing: AppSpacing.sm,
        children: [
          Text(strings.loadFailed, textAlign: TextAlign.center),
          TextButton.icon(
            key: const Key('members.picker.retry'),
            onPressed: () => _load(reset: _people.isEmpty),
            icon: const Icon(AppIcons.actionRetry),
            label: Text(strings.retry),
          ),
        ],
      );
    } else if (_loading) {
      status = const Center(
        key: Key('members.picker.loading'),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_people.isEmpty) {
      status = Text(
        _search.text.trim().isEmpty
            ? strings.noneYet(words.other('member'))
            : strings.noneFound(words.other('member')),
        key: const Key('members.picker.empty'),
        textAlign: TextAlign.center,
      );
    } else if (hasMore) {
      status = Center(
        child: TextButton(
          key: const Key('members.picker.more'),
          onPressed: () => _load(reset: false),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(strings.showMore),
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                widget.multi
                    ? strings.chooseMany(words.other('member'))
                    : strings.chooseOne(words.one('member')),
                style: theme.textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                key: const Key('members.picker.search'),
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(AppIcons.actionSearch),
                  hintText: strings.search(words.other('member')),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                key: const Key('members.picker.list'),
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: _people.length + (status == null ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index == _people.length) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: status,
                    );
                  }
                  final person = _people[index];
                  final key = Key('members.picker.row.${person.uid}');
                  if (!widget.multi) {
                    return ListTile(
                      key: key,
                      minTileHeight: 48,
                      leading: const Icon(AppIcons.navProfile),
                      title: Text(label(person)),
                      onTap: () => Navigator.of(context).pop(person),
                    );
                  }
                  return CheckboxListTile(
                    key: key,
                    value: _chosen.contains(person.uid),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(label(person)),
                    onChanged: (on) => setState(
                      () => on == true
                          ? _chosen.add(person.uid)
                          : _chosen.remove(person.uid),
                    ),
                  );
                },
              ),
            ),
            if (widget.multi)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FilledButton(
                  key: const Key('members.picker.done'),
                  onPressed: () => Navigator.of(context).pop(_chosen),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(strings.done(_chosen.length)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
