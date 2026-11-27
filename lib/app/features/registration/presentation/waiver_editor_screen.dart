import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/registration/application/waivers_provider.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';
import 'package:crewpoint_app/app/features/registration/domain/waivers.dart';

const _k = 'registration.waiver';

/// Who [w] applies to, in a few words, for settings rows.
String waiverAppliesText(
  WaiverAppliesTo w, {
  required List<EventCategory> categories,
  required Map<String, String> sessionTitles,
  required RegistrationSettingsStrings strings,
}) => switch (w.kind) {
  'category' => strings.appliesOnly(
    categories.where((c) => c.id == w.id).firstOrNull?.name ?? '',
  ),
  'session' => strings.appliesSignedUp(sessionTitles[w.id] ?? ''),
  _ => strings.appliesEveryone,
};

/// `settings/registration/waivers/:waiverId` (Spec #233 Req 26, 28; #246),
/// `new` to add one: the title and text in English and Gujarati, who it
/// applies to, and whether it is required and asked again after a change.
/// Saves through `MemberCalls.saveWaiver`, with `event.manage`.
class WaiverEditorScreen extends ConsumerStatefulWidget {
  const WaiverEditorScreen({
    super.key,
    required this.event,
    required this.waiverId,
  });

  final EventModel event;

  /// The waiver's ID, or `new`.
  final String waiverId;

  @override
  ConsumerState<WaiverEditorScreen> createState() => _WaiverEditorScreenState();
}

class _WaiverEditorScreenState extends ConsumerState<WaiverEditorScreen> {
  final _title = TextEditingController();
  final _titleGu = TextEditingController();
  final _text = TextEditingController();
  final _textGu = TextEditingController();
  String _kind = 'everyone';
  String? _targetId;
  bool _required = false;
  bool _requireLatest = true;
  bool _loaded = false;
  bool _busy = false;
  bool _tried = false;

  bool get _isNew => widget.waiverId == 'new';

  @override
  void dispose() {
    _title.dispose();
    _titleGu.dispose();
    _text.dispose();
    _textGu.dispose();
    super.dispose();
  }

  void _load(Waiver? w) {
    if (_loaded) return;
    _loaded = true;
    if (w == null) return;
    _title.text = w.title.en;
    _titleGu.text = w.title.gu ?? '';
    _text.text = w.text.en;
    _textGu.text = w.text.gu ?? '';
    _kind = w.appliesTo.kind;
    _targetId = w.appliesTo.id;
    _required = w.required;
    _requireLatest = w.requireLatest;
  }

  WaiverAppliesTo? get _appliesTo => switch (_kind) {
    'category' when _targetId != null => WaiverAppliesTo.category(_targetId!),
    'session' when _targetId != null => WaiverAppliesTo.session(_targetId!),
    'everyone' => const WaiverAppliesTo.everyone(),
    _ => null,
  };

  LocalText _local(TextEditingController en, TextEditingController gu) =>
      LocalText(
        en.text.trim(),
        gu: gu.text.trim().isEmpty ? null : gu.text.trim(),
      );

  Future<void> _save() async {
    final s = context.strings.registrationSettings;
    setState(() => _tried = true);
    final appliesTo = _appliesTo;
    if (_title.text.trim().isEmpty ||
        _text.text.trim().isEmpty ||
        appliesTo == null) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(memberCallsProvider)
          .saveWaiver(
            eventId: widget.event.id,
            waiverId: _isNew ? null : widget.waiverId,
            title: _local(_title, _titleGu),
            text: _local(_text, _textGu),
            appliesTo: appliesTo,
            required: _required,
            requireLatest: _requireLatest,
          );
      messenger.showSnackBar(SnackBar(content: Text(s.waiverSaved)));
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/dashboard/event/${widget.event.id}/settings/registration');
      }
    } on Object catch (e, st) {
      log('saveWaiver failed', error: e, stackTrace: st);
      messenger.showSnackBar(SnackBar(content: Text(s.waiverSaveFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickKind(
    RegistrationSettingsStrings s,
    List<({String kind, String label})> kinds,
  ) async {
    final picked = await _pick(s.appliesTo, [
      for (final k in kinds) (id: k.kind, label: k.label),
    ], _kind);
    if (picked != null && picked != _kind) {
      setState(() {
        _kind = picked;
        _targetId = null;
      });
    }
  }

  Future<String?> _pick(
    String title,
    List<({String id, String label})> options,
    String? chosen,
  ) {
    final cp = context.cp;
    final s = context.strings.registrationSettings;
    return showCpSheet<String>(
      context: context,
      title: title,
      builder: (sheet) => CpCard(
        child: CpRowGroup(
          children: [
            for (final o in options)
              CpListRow(
                key: Key('$_k.option.${o.id}'),
                title: o.label,
                trailing: o.id == chosen
                    ? Icon(
                        CpIcons.statusDone,
                        size: cp.sizes.iconMd,
                        color: cp.colors.accent,
                        semanticLabel: s.chosen,
                      )
                    : null,
                onTap: () => Navigator.of(sheet).pop(o.id),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.registrationSettings;
    final cp = context.cp;
    final event = widget.event;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final title = _isNew ? s.newWaiver : s.editWaiver;
    if (!event.can(me, 'event.manage')) {
      return AdminScaffold(title: title, body: const NoAccessView());
    }
    final waivers = ref.watch(eventWaiversProvider(event.id));
    if (!_isNew && !waivers.hasValue) {
      return AdminScaffold(
        title: title,
        body: waivers.hasError
            ? CpErrorState(
                key: const Key('$_k.error'),
                title: s.waiverSaveFailed,
                retryLabel: context.strings.registerForm.retry,
                onRetry: () => ref.invalidate(eventWaiversProvider(event.id)),
              )
            : CpLoadingState.rows(
                key: const Key('$_k.loading'),
                semanticLabel: title,
              ),
      );
    }
    final existing = waivers.value
        ?.where((w) => w.id == widget.waiverId)
        .firstOrNull;
    _load(existing);

    final words = event.words;
    final categories = categoriesOf(event.settings);
    final sessions = ref.watch(sessionListProvider(event.id)).value ?? const [];
    final kinds = [
      (kind: 'everyone', label: s.appliesEveryone),
      if (categories.isNotEmpty)
        (
          kind: 'category',
          label: s.appliesToCategory(words.one('category').toLowerCase()),
        ),
      if (sessions.isNotEmpty)
        (
          kind: 'session',
          label: s.appliesToSession(words.one('session').toLowerCase()),
        ),
    ];
    final targets = switch (_kind) {
      'category' => [for (final c in categories) (id: c.id, label: c.name)],
      'session' => [for (final x in sessions) (id: x.id, label: x.title)],
      _ => const <({String id, String label})>[],
    };
    final targetLabel = targets
        .where((t) => t.id == _targetId)
        .firstOrNull
        ?.label;

    return AdminScaffold(
      title: title,
      bottom: AdminSaveBar(
        child: CpButton(
          key: const Key('$_k.save'),
          label: s.save,
          busy: _busy,
          onPressed: _busy ? null : _save,
        ),
      ),
      body: AdminList(
        listKey: const Key('$_k.body'),
        children: [
          ContentMaxWidth(
            maxWidth: cp.sizes.phoneColumn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.lg,
              children: [
                if (existing != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: CpTag(
                      label: s.waiverVersion(existing.version),
                      tone: CpTagTone.quiet,
                    ),
                  ),
                CpCard(
                  padding: EdgeInsets.all(cp.space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: cp.space.lg,
                    children: [
                      CpTextField(
                        fieldKey: const Key('$_k.title'),
                        label: s.waiverTitle,
                        controller: _title,
                        required: true,
                        maxLength: 200,
                        error: _tried && _title.text.trim().isEmpty
                            ? s.titleNeeded
                            : null,
                        onChanged: (_) => setState(() {}),
                      ),
                      CpTextField(
                        fieldKey: const Key('$_k.titleGu'),
                        label: s.waiverTitleGu,
                        controller: _titleGu,
                        maxLength: 200,
                      ),
                      CpTextField(
                        fieldKey: const Key('$_k.text'),
                        label: s.waiverText,
                        help: s.waiverTextHelp,
                        controller: _text,
                        required: true,
                        maxLines: 10,
                        maxLength: 20000,
                        keyboardType: TextInputType.multiline,
                        error: _tried && _text.text.trim().isEmpty
                            ? s.textNeeded
                            : null,
                        onChanged: (_) => setState(() {}),
                      ),
                      CpTextField(
                        fieldKey: const Key('$_k.textGu'),
                        label: s.waiverTextGu,
                        controller: _textGu,
                        maxLines: 10,
                        maxLength: 20000,
                        keyboardType: TextInputType.multiline,
                      ),
                    ],
                  ),
                ),
                CpCard(
                  padding: EdgeInsets.all(cp.space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: cp.space.lg,
                    children: [
                      CpSelectField(
                        fieldKey: const Key('$_k.appliesTo'),
                        label: s.appliesTo,
                        value: kinds
                            .where((k) => k.kind == _kind)
                            .firstOrNull
                            ?.label,
                        onTap: () => _pickKind(s, kinds),
                      ),
                      if (_kind != 'everyone')
                        CpSelectField(
                          fieldKey: const Key('$_k.target'),
                          label: _kind == 'category'
                              ? words.one('category')
                              : words.one('session'),
                          value: targetLabel,
                          required: true,
                          error: _tried && targetLabel == null
                              ? s.choiceNeeded
                              : null,
                          onTap: () async {
                            final picked = await _pick(
                              s.appliesTo,
                              targets,
                              _targetId,
                            );
                            if (picked != null) {
                              setState(() => _targetId = picked);
                            }
                          },
                        ),
                      CpSwitchRow(
                        key: const Key('$_k.required'),
                        title: s.waiverIsRequired,
                        help: s.waiverIsRequiredHelp,
                        value: _required,
                        onChanged: (v) => setState(() => _required = v),
                      ),
                      CpSwitchRow(
                        key: const Key('$_k.requireLatest'),
                        title: s.requireLatest,
                        help: s.requireLatestHelp,
                        value: _requireLatest,
                        onChanged: (v) => setState(() => _requireLatest = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
