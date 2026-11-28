import 'dart:async';
import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/format/event_time.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/labels/label_resolver.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';
import 'package:crewpoint_app/app/features/participants/presentation/widgets/answer_input.dart';
import 'package:crewpoint_app/app/features/registration/application/event_page_provider.dart';
import 'package:crewpoint_app/app/features/registration/application/my_waiting_provider.dart';
import 'package:crewpoint_app/app/features/registration/application/registration_form_provider.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_form.dart';
import 'package:crewpoint_app/app/features/registration/domain/registration_settings.dart';
import 'package:crewpoint_app/app/features/registration/presentation/widgets/waiver_card.dart';

const _k = 'registration.form';

/// The registration form (`/e/:eventSlug/register`, behind the sign-in gate;
/// Spec #233 Req 2, 16-21, 25, 33; #242): People, each section, Stay,
/// Session choices and Contact as steps, then Review with Edit per step,
/// then Submit and the confirmation or the waitlist number. Problems are
/// checked on Submit, shown beside their fields with a count at the top.
/// A group of one sees no group words. No fee is shown (Req 7).
class RegistrationFormScreen extends ConsumerWidget {
  const RegistrationFormScreen({super.key, required this.slug, this.complete});

  final String slug;

  /// A "complete your registration" link's registration ID (#249).
  final String? complete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings.registerForm;
    final page = context.strings.eventPage;
    final cp = context.cp;
    final key = (slug: slug.toLowerCase(), complete: complete);
    final form = ref.watch(registrationFormProvider(key));
    Widget plain(Widget child) => Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: () => context.go('/e/$slug'),
      ),
      body: SafeArea(child: child),
    );
    return form.when(
      loading: () => plain(
        CpLoadingState.rows(
          key: const Key('$_k.loading'),
          semanticLabel: s.loading,
        ),
      ),
      error: (e, _) {
        final reason = e is FirebaseFunctionsException && e.details is Map
            ? (e.details as Map)['reason']
            : null;
        return plain(switch (reason) {
          'notOpen' => CpEmptyState(
            key: const Key('$_k.notOpen'),
            icon: CpIcons.notOpenYet,
            title: page.notOpen,
            message: page.notOpenHelp,
          ),
          'closed' => CpEmptyState(
            key: const Key('$_k.closed'),
            icon: CpIcons.registrationClosed,
            title: page.closed,
            // How to reach the organizer (Req 35, B-13).
            message: switch (ref.watch(eventPageProvider(key.slug)).value
                ?.contactLine) {
              final line? =>
                Localizations.localeOf(context).languageCode == 'gu' &&
                        line.gu != null
                    ? line.gu
                    : line.en,
              null => null,
            },
          ),
          // A "complete your registration" link (#249) refused.
          'completionEmail' => CpEmptyState(
            key: const Key('$_k.completionEmail'),
            icon: CpIcons.authEmailField,
            title: s.completionEmailTitle,
            message: s.completionEmailBody,
          ),
          'completionUsed' => CpEmptyState(
            key: const Key('$_k.completionUsed'),
            icon: CpIcons.registration,
            title: s.completionUsedTitle,
            message: s.completionUsedBody,
          ),
          'completionNotFound' => CpEmptyState(
            key: const Key('$_k.completionGone'),
            icon: CpIcons.registrationClosed,
            title: s.completionGoneTitle,
            message: s.completionGoneBody,
          ),
          _ => CpErrorState(
            key: const Key('$_k.error'),
            title: s.failed,
            message: s.failedHelp,
            retryLabel: s.retry,
            retryKey: const Key('$_k.retry'),
            onRetry: () => ref.invalidate(registrationFormProvider(key)),
          ),
        });
      },
      data: (spec) => spec.registration != null && !spec.editing
          ? plain(
              CpEmptyState(
                key: const Key('$_k.already'),
                icon: CpIcons.registration,
                title: s.alreadyTitle,
                message: s.alreadyBody,
                actionLabel: s.seeMine,
                actionKey: const Key('$_k.already.mine'),
                onAction: () => context.go('/e/$slug/registration'),
              ),
            )
          : _RegistrationForm(spec: spec, slug: slug, complete: complete),
    );
  }
}

class _RegistrationForm extends ConsumerStatefulWidget {
  const _RegistrationForm({
    required this.spec,
    required this.slug,
    this.complete,
  });

  final String? complete;

  final RegistrationFormSpec spec;
  final String slug;

  @override
  ConsumerState<_RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends ConsumerState<_RegistrationForm> {
  late RegistrationDraft _draft;

  /// A stable key per person card, so removing one keeps the others' text.
  final List<int> _ids = [0];
  int _nextId = 1;
  int _step = 0;
  bool _tried = false;
  bool _busy = false;
  String? _error;
  SubmitResult? _result;
  final ScrollController _scroll = ScrollController();

  /// Edits saved (#244).
  bool _saved = false;

  /// Whether the server holds the latest draft (#243); null before the
  /// first save is tried.
  _SaveState? _saveState;
  Timer? _saveTimer;
  bool _saving = false;
  bool _saveAgain = false;

  /// How long typing must pause before the draft goes to the server.
  static const _quiet = Duration(seconds: 3);

  /// The device's copy of this form: one per event and person (Req 23).
  String get _draftKey {
    final auth = ref.read(authProvider);
    final uid = auth is Authenticated ? auth.user.uid : 'anonymous';
    return 'registration:${_spec.slug}:$uid';
  }

  RegistrationFormSpec get _spec => widget.spec;
  List<FormStep> get _steps => _spec.steps;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    final email = auth is Authenticated ? auth.user.email : '';
    final current = _spec.current;
    if (current != null && _spec.completing) {
      // Completing a group the organizer added (#249): its people to
      // check, sent as a new registration, so no drafts.
      _draft = RegistrationDraft(
        submissionId: const Uuid().v4(),
        people: current.people,
        groupAnswers: current.groupAnswers,
        groupName: current.groupName,
        email: current.email.isEmpty ? email : current.email,
        phone: current.phone,
      );
      _ids
        ..clear()
        ..addAll([for (var i = 0; i < current.people.length; i++) _nextId++]);
      return;
    }
    if (current != null) {
      // Editing a registration (#244): no drafts, the server holds it.
      _draft = current;
      _ids
        ..clear()
        ..addAll([for (var i = 0; i < current.people.length; i++) _nextId++]);
      return;
    }
    _draft = RegistrationDraft(
      submissionId: const Uuid().v4(),
      people: const [PersonEntry()],
      email: email,
    );
    unawaited(_restore());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Reopening the form restores the newer of the device's and the
  /// server's drafts (#243).
  Future<void> _restore() async {
    final device = await ref.read(draftStoreProvider).load(_draftKey);
    if (!mounted) return;
    final onDevice = RegistrationDraft.tryParse(device?['draft']);
    final deviceAt = device?['savedAt'] is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (device!['savedAt'] as num).toInt(),
            isUtc: true,
          )
        : null;
    final onServer = _spec.serverDraft;
    final serverAt = _spec.serverDraftSavedAt;
    final serverNewer =
        onServer != null &&
        (onDevice == null ||
            deviceAt == null ||
            (serverAt != null && serverAt.isAfter(deviceAt)));
    final restored = serverNewer ? onServer : onDevice;
    if (restored == null || restored.people.isEmpty) return;
    setState(() {
      _draft = restored;
      _ids
        ..clear()
        ..addAll([for (var i = 0; i < restored.people.length; i++) _nextId++]);
      if (serverNewer) _saveState = _SaveState.saved;
    });
  }

  void _edit(RegistrationDraft Function(RegistrationDraft) change) {
    setState(() => _draft = change(_draft));
    _changed();
  }

  /// Keeps the answers on the device at once and on the server once typing
  /// pauses (Req 23, 24).
  void _changed() {
    if (_result != null || _saved || _spec.editing || _spec.completing) {
      return;
    }
    unawaited(
      ref.read(draftStoreProvider).save(_draftKey, {
        'draft': _draft.toMap(),
        'savedAt': DateTime.now().toUtc().millisecondsSinceEpoch,
      }),
    );
    _saveTimer?.cancel();
    _saveTimer = Timer(_quiet, () => unawaited(_saveToServer()));
  }

  Future<void> _saveToServer() async {
    _saveTimer?.cancel();
    if (_result != null || _busy) return;
    if (_saving) {
      _saveAgain = true;
      return;
    }
    _saving = true;
    try {
      if (!await ref.read(connectivityProvider).isOnline()) {
        if (mounted) setState(() => _saveState = _SaveState.offline);
        return;
      }
      if (!mounted) return;
      setState(() => _saveState = _SaveState.saving);
      await ref
          .read(memberCallsProvider)
          .saveRegistrationDraft(
            slug: _spec.slug,
            draft: _draft.toMap(),
            savedAt: DateTime.now().toUtc(),
          );
      if (mounted && _result == null) {
        setState(() => _saveState = _SaveState.saved);
      }
    } catch (e, st) {
      log('saveRegistrationDraft failed', error: e, stackTrace: st, name: 'reg');
      if (mounted) setState(() => _saveState = _SaveState.offline);
    } finally {
      _saving = false;
      if (_saveAgain && mounted) {
        _saveAgain = false;
        unawaited(_saveToServer());
      }
    }
  }

  void _editPerson(int i, PersonEntry Function(PersonEntry) change) => _edit(
    (d) => d.copyWith(
      people: [
        for (var j = 0; j < d.people.length; j++)
          j == i ? change(d.people[j]) : d.people[j],
      ],
    ),
  );

  void _go(int step) {
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    // Moving between steps saves at once (Req 24).
    if (_saveTimer?.isActive ?? false) unawaited(_saveToServer());
  }

  List<FormProblem> get _problems => _tried ? _spec.problems(_draft) : const [];

  FormProblem? _problem(String step, String key, {int? person}) => _problems
      .where((p) => p.step == step && p.key == key && p.person == person)
      .firstOrNull;

  Future<void> _submit() async {
    final problems = _spec.problems(_draft);
    if (problems.isNotEmpty) {
      setState(() => _tried = true);
      _go(_steps.indexWhere((s) => s.id == problems.first.step));
      return;
    }
    final s = context.strings.registerForm;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Submitting needs a connection; it is never queued (Req 25).
    if (!await ref.read(connectivityProvider).isOnline()) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = s.offline;
          _saveState = _SaveState.offline;
        });
      }
      return;
    }
    _saveTimer?.cancel();
    try {
      if (_spec.editing) {
        await ref
            .read(memberCallsProvider)
            .updateRegistration(_spec.toSubmitMap(_draft));
        if (!mounted) return;
        setState(() => _saved = true);
        return;
      }
      final result = await ref
          .read(memberCallsProvider)
          .submitRegistration({
            ..._spec.toSubmitMap(_draft),
            'completeRegistrationId': ?widget.complete,
          });
      if (!mounted) return;
      setState(() => _result = result);
      // Home lists a group waiting for a place (#292).
      ref.invalidate(myWaitingRegistrationsProvider);
      await ref.read(draftStoreProvider).clear(_draftKey);
    } catch (e, st) {
      log('registration save failed', error: e, stackTrace: st, name: 'reg');
      if (!mounted) return;
      final reason = e is FirebaseFunctionsException && e.details is Map
          ? (e.details as Map)['reason']
          : null;
      // No room, or closed: the server's words (Req 32a, 35).
      setState(
        () => _error = switch (reason) {
          'noRoom' || 'closed' => (e as FirebaseFunctionsException).message,
          _ => null,
        } ?? s.submitFailed,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.registerForm;
    final cp = context.cp;
    final result = _result;
    if (result != null) {
      return _ResultView(result: result, spec: _spec, slug: widget.slug);
    }
    if (_saved) {
      return Scaffold(
        backgroundColor: cp.colors.background,
        body: SafeArea(
          child: CpEmptyState(
            key: const Key('$_k.result.saved'),
            icon: CpIcons.statusDone,
            title: s.changesSaved,
            message: s.changesSavedBody,
            actionLabel: s.seeMine,
            actionKey: const Key('$_k.result.mine'),
            onAction: () => context.go('/e/${widget.slug}/registration'),
          ),
        ),
      );
    }
    final step = _steps[_step];
    final last = _step == _steps.length - 1;
    final problems = _problems;
    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: _spec.title,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading: () =>
            _step == 0 ? context.go('/e/${widget.slug}') : _go(_step - 1),
      ),
      bottomNavigationBar: CpSaveBar(
        child: Row(
          spacing: cp.space.sm,
          children: [
            if (_step > 0)
              Expanded(
                child: CpButton.secondary(
                  key: const Key('$_k.back'),
                  label: s.back,
                  expand: true,
                  onPressed: _busy ? null : () => _go(_step - 1),
                ),
              ),
            Expanded(
              child: last
                  ? CpButton(
                      key: const Key('$_k.submit'),
                      label: _spec.editing ? s.saveChanges : s.submit,
                      busy: _busy,
                      expand: true,
                      onPressed: _busy ? null : _submit,
                    )
                  : CpButton(
                      key: const Key('$_k.next'),
                      label: s.next,
                      expand: true,
                      onPressed: () => _go(_step + 1),
                    ),
            ),
          ],
        ),
      ),
      body: ListView(
        key: const Key('$_k.body'),
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(
          cp.space.lg,
          cp.space.md,
          cp.space.lg,
          cp.space.xxl,
        ),
        children: [
          ContentMaxWidth(
            maxWidth: cp.sizes.phoneColumn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: cp.space.lg,
              children: [
                Text(
                  s.stepOf(_step + 1, _steps.length),
                  key: const Key('$_k.progress'),
                  style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
                ),
                if (_saveState case final state?) _SaveIndicator(state),
                if (problems.isNotEmpty)
                  Row(
                    key: const Key('$_k.problems'),
                    spacing: cp.space.sm,
                    children: [
                      Icon(
                        CpIcons.statusError,
                        size: cp.sizes.iconMd,
                        color: cp.colors.overdue,
                      ),
                      Expanded(
                        child: Text(
                          s.problems(problems.length),
                          style: cp.type.titleSmall.copyWith(
                            color: cp.colors.overdue,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_error != null) CpFieldError(_error!),
                // After the deadline: contact details only (Req 35, B-13).
                if (_spec.editable == FormEditable.contact)
                  _ContactOnlyNote(contactLine: _spec.contactLine),
                ..._stepBody(context, step),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _groupWord(BuildContext context) =>
      LabelResolver(_spec.labels).one('group');

  /// A person's name, or "Person N" while it is empty.
  String _personName(BuildContext context, int i) {
    final name = _draft.people[i].name.trim();
    return name.isEmpty ? context.strings.registerForm.person(i + 1) : name;
  }

  List<Widget> _stepBody(BuildContext context, FormStep step) {
    final s = context.strings.registerForm;
    final cp = context.cp;
    Widget heading(String text) => Semantics(
      header: true,
      child: Text(
        text,
        style: cp.type.titleLarge.copyWith(color: cp.colors.text),
      ),
    );
    switch (step.id) {
      case FormStep.people:
        final noPeople = _problem(FormStep.people, 'noPeople');
        return [
          heading(s.peopleTitle),
          if (noPeople != null) CpFieldError(s.noPeople),
          for (var i = 0; i < _draft.people.length; i++)
            _PersonCard(
              key: ValueKey('person-${_ids[i]}'),
              index: i,
              spec: _spec,
              person: _draft.people[i],
              canRemove: _draft.people.length > 1,
              nameError: _problem(FormStep.people, 'name', person: i) == null
                  ? null
                  : s.nameRequired,
              ageError:
                  _problem(FormStep.people, 'birthDate', person: i) != null
                  ? s.birthDateRequired
                  : _problem(FormStep.people, 'age', person: i) != null
                  ? s.ageRequired
                  : null,
              onChanged: (change) => _editPerson(i, change),
              onRemove: () {
                setState(() {
                  _ids.removeAt(i);
                  _draft = _draft.copyWith(
                    people: [..._draft.people]..removeAt(i),
                  );
                });
                _changed();
              },
            ),
          CpButton.secondary(
            key: const Key('$_k.addPerson'),
            label: s.addPerson,
            icon: CpIcons.actionAdd,
            onPressed: () {
              setState(() {
                _ids.add(_nextId++);
                _draft = _draft.copyWith(
                  people: [..._draft.people, const PersonEntry()],
                );
              });
              _changed();
            },
          ),
          // A group of one sees no group words (Req 2).
          if (_draft.people.length > 1)
            CpCard(
              padding: EdgeInsets.all(cp.space.lg),
              child: _GroupNameField(
                label: s.groupName(_groupWord(context)),
                value: _draft.groupName,
                onChanged: (v) => _edit((d) => d.copyWith(groupName: v)),
              ),
            ),
        ];
      case FormStep.stay:
        return [
          heading(s.stayTitle),
          Text(
            s.stayHelp,
            style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
          ),
          for (var i = 0; i < _draft.people.length; i++)
            _StayCard(
              key: Key('$_k.stay.$i'),
              index: i,
              title: _personName(context, i),
              spec: _spec,
              person: _draft.people[i],
              error: _problem(FormStep.stay, 'departureAt', person: i) == null
                  ? null
                  : s.leavingBeforeArriving,
              onChanged: (change) => _editPerson(i, change),
            ),
        ];
      case FormStep.sessions:
        return [
          heading(s.sessionsTitle),
          for (var i = 0; i < _draft.people.length; i++)
            _SessionsCard(
              key: Key('$_k.sessions.$i'),
              index: i,
              title: _personName(context, i),
              spec: _spec,
              person: _draft.people[i],
              error: _problem(FormStep.sessions, 'signUps', person: i) == null
                  ? null
                  : s.oneAtATime,
              onChanged: (signUps) =>
                  _editPerson(i, (p) => p.copyWith(signUps: signUps)),
              onOptOuts: (optOuts) =>
                  _editPerson(i, (p) => p.copyWith(optOuts: optOuts)),
            ),
        ];
      case FormStep.waivers:
        final language = Localizations.localeOf(context).languageCode;
        final applying = [
          for (final w in _spec.waivers)
            (
              waiver: w,
              people: [
                for (var i = 0; i < _draft.people.length; i++)
                  if (_spec
                      .waiversFor(_draft.people[i])
                      .any((x) => x.id == w.id))
                    i,
              ],
            ),
        ].where((a) => a.people.isNotEmpty).toList();
        return [
          heading(s.waiversTitle),
          Text(
            applying.isEmpty ? s.noWaivers : s.waiversHelp,
            style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
          ),
          for (final a in applying)
            WaiverCard(
              key: Key('$_k.waiver.${a.waiver.id}'),
              keyPrefix: '$_k.waiver.${a.waiver.id}',
              waiver: a.waiver,
              language: language,
              people: [
                for (final i in a.people)
                  WaiverPersonRow(
                    index: i,
                    name: _personName(context, i),
                    isChild: _spec.categoryOf(_draft.people[i])?.isChild ?? false,
                    accepted: _draft.people[i].acceptWaivers.contains(
                      a.waiver.id,
                    ),
                    missing:
                        _problem(FormStep.waivers, a.waiver.id, person: i) !=
                        null,
                  ),
              ],
              onAccept: (i, on) => _editPerson(
                i,
                (p) => p.copyWith(
                  acceptWaivers: on
                      ? {...p.acceptWaivers, a.waiver.id}
                      : ({...p.acceptWaivers}..remove(a.waiver.id)),
                ),
              ),
            ),
        ];
      case FormStep.contact:
        return [
          heading(s.contactTitle),
          _ContactCard(
            email: _draft.email,
            phone: _draft.phone,
            emailError: _problem(FormStep.contact, 'email') == null
                ? null
                : s.emailInvalid,
            onEmail: (v) => _edit((d) => d.copyWith(email: v)),
            onPhone: (v) => _edit((d) => d.copyWith(phone: v)),
          ),
          // Asked once, with the registration (Req 31).
          if (!_spec.editing) ...[
            CpSectionHeader(title: s.consentTitle),
            CpCard(
              padding: EdgeInsets.all(cp.space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: cp.space.md,
                children: [
                  Text(
                    s.consentHelp,
                    style: cp.type.bodySmall.copyWith(
                      color: cp.colors.textMuted,
                    ),
                  ),
                  CpSwitchRow(
                    key: const Key('$_k.consent.email'),
                    title: s.consentEmail,
                    value: _draft.consentEmail,
                    onChanged: (v) =>
                        _edit((d) => d.copyWith(consentEmail: v)),
                  ),
                  CpSwitchRow(
                    key: const Key('$_k.consent.sms'),
                    title: s.consentSms,
                    value: _draft.consentSms,
                    onChanged: (v) => _edit((d) => d.copyWith(consentSms: v)),
                  ),
                ],
              ),
            ),
          ],
        ];
      case FormStep.review:
        return [
          heading(s.reviewTitle),
          Text(
            s.reviewHelp,
            style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
          ),
          for (var i = 0; i < _steps.length - 1; i++)
            _ReviewCard(
              key: Key('$_k.review.${_steps[i].id}'),
              title: _stepTitle(context, _steps[i]),
              editKey: Key('$_k.review.${_steps[i].id}.edit'),
              onEdit: () => _go(i),
              rows: _reviewRows(context, _steps[i]),
            ),
        ];
      default:
        final section = step.section!;
        final language = Localizations.localeOf(context).languageCode;
        final questions = _spec.questionsIn(section);
        final groupQuestions = questions
            .where((q) => q.scope == FieldScope.group)
            .where((q) => _spec.shows(q, _draft))
            .toList();
        return [
          heading(_localName(section.name, language)),
          if (groupQuestions.isNotEmpty)
            CpCard(
              padding: EdgeInsets.all(cp.space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: cp.space.lg,
                children: [
                  for (final q in groupQuestions)
                    AnswerInput(
                      key: Key('$_k.group.${q.id}'),
                      field: q,
                      value: _draft.groupAnswers[q.id],
                      keyPrefix: '$_k.group',
                      showError: _problem(step.id, q.id) != null,
                      onChanged: (v) => _edit(
                        (d) => d.copyWith(
                          groupAnswers: {...d.groupAnswers, q.id: v},
                        ),
                      ),
                    ),
                ],
              ),
            ),
          for (var i = 0; i < _draft.people.length; i++)
            if (questions.any(
              (q) =>
                  q.scope == FieldScope.participant &&
                  _spec.shows(q, _draft, person: _draft.people[i]),
            ))
              CpCard(
                key: Key('$_k.answers.$i'),
                padding: EdgeInsets.all(cp.space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: cp.space.lg,
                  children: [
                    Text(
                      _personName(context, i),
                      style: cp.type.titleMedium.copyWith(
                        color: cp.colors.text,
                      ),
                    ),
                    for (final q in questions)
                      if (q.scope == FieldScope.participant &&
                          _spec.shows(q, _draft, person: _draft.people[i]))
                        AnswerInput(
                          key: Key('$_k.answer.$i.${q.id}'),
                          field: q,
                          value: _draft.people[i].answers[q.id],
                          keyPrefix: '$_k.answer.$i',
                          showError: _problem(step.id, q.id, person: i) != null,
                          onChanged: (v) => _editPerson(
                            i,
                            (p) => p.copyWith(answers: {...p.answers, q.id: v}),
                          ),
                        ),
                  ],
                ),
              ),
        ];
    }
  }

  String _localName(LocalText name, String language) =>
      language == 'gu' && name.gu != null ? name.gu! : name.en;

  String _stepTitle(BuildContext context, FormStep step) {
    final s = context.strings.registerForm;
    return switch (step.id) {
      FormStep.people => s.peopleTitle,
      FormStep.stay => s.stayTitle,
      FormStep.sessions => s.sessionsTitle,
      FormStep.waivers => s.waiversTitle,
      FormStep.contact => s.contactTitle,
      _ => _localName(
        step.section!.name,
        Localizations.localeOf(context).languageCode,
      ),
    };
  }

  String _answerText(BuildContext context, Object? value) {
    final s = context.strings.registerForm;
    return switch (value) {
      null || '' => s.notAnswered,
      true => s.yes,
      false => s.no,
      final List<Object?> list when list.isEmpty => s.notAnswered,
      final List<Object?> list => list.join(', '),
      _ => '$value',
    };
  }

  List<(String, String)> _reviewRows(BuildContext context, FormStep step) {
    final s = context.strings.registerForm;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String day(DateTime? d) => d == null
        ? s.notAnswered
        : DateFormat.yMMMEd(
            locale,
          ).add_jm().format(inEventZone(d, _spec.timeZone));
    final people = _draft.people;
    switch (step.id) {
      case FormStep.people:
        return [
          for (var i = 0; i < people.length; i++)
            (
              _personName(context, i),
              _spec.has(RegistrationBlock.ageOnly)
                  ? '${s.age}: ${people[i].age ?? s.notAnswered}'
                  : '${s.birthDate}: ${people[i].birthDate ?? s.notAnswered}',
            ),
          for (var i = 0; i < people.length; i++)
            (
              '${_personName(context, i)}: ${s.photoConsent}',
              switch (people[i].photoConsent) {
                true => s.yes,
                false => s.no,
                null => s.notAnswered,
              },
            ),
          if (people.length > 1 && _draft.groupName.trim().isNotEmpty)
            (s.groupName(_groupWord(context)), _draft.groupName.trim()),
        ];
      case FormStep.stay:
        return [
          for (var i = 0; i < people.length; i++)
            (
              _personName(context, i),
              '${s.arriving}: ${day(people[i].arrivalAt)} · '
                  '${s.leaving}: ${day(people[i].departureAt)}',
            ),
        ];
      case FormStep.sessions:
        final titles = {
          for (final c in _spec.choices)
            for (final session in c) session.id: session.title,
          for (final session in _spec.attending) session.id: session.title,
        };
        return [
          for (var i = 0; i < people.length; i++) ...[
            (
              _personName(context, i),
              _answerText(context, [
                for (final id in people[i].signUps) titles[id] ?? id,
              ]),
            ),
            if (people[i].optOuts.isNotEmpty)
              (
                '${_personName(context, i)}: ${s.notAttending}',
                [for (final id in people[i].optOuts) titles[id] ?? id].join(', '),
              ),
          ],
        ];
      case FormStep.waivers:
        final language = Localizations.localeOf(context).languageCode;
        return [
          for (var i = 0; i < people.length; i++)
            for (final w in _spec.waiversFor(people[i]))
              (
                '${_personName(context, i)}: ${_localName(w.title, language)}',
                people[i].acceptWaivers.contains(w.id)
                    ? s.waiverAccepted
                    : s.waiverNotAccepted,
              ),
        ];
      case FormStep.contact:
        return [
          (s.email, _answerText(context, _draft.email.trim())),
          if (_draft.phone.trim().isNotEmpty) (s.phone, _draft.phone.trim()),
          if (!_spec.editing) ...[
            (s.consentEmail, _draft.consentEmail ? s.yes : s.no),
            (s.consentSms, _draft.consentSms ? s.yes : s.no),
          ],
        ];
      default:
        final questions = _spec.questionsIn(step.section!);
        return [
          for (final q in questions)
            if (q.scope == FieldScope.group && _spec.shows(q, _draft))
              (q.label, _answerText(context, _draft.groupAnswers[q.id])),
          for (var i = 0; i < people.length; i++)
            for (final q in questions)
              if (q.scope == FieldScope.participant &&
                  _spec.shows(q, _draft, person: people[i]))
                (
                  '${_personName(context, i)}: ${q.label}',
                  _answerText(context, people[i].answers[q.id]),
                ),
        ];
    }
  }
}

/// One person's name and birth date, or age (Req 17 People).
class _PersonCard extends StatefulWidget {
  const _PersonCard({
    super.key,
    required this.index,
    required this.spec,
    required this.person,
    required this.canRemove,
    required this.nameError,
    required this.ageError,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final RegistrationFormSpec spec;
  final PersonEntry person;
  final bool canRemove;
  final String? nameError;
  final String? ageError;
  final ValueChanged<PersonEntry Function(PersonEntry)> onChanged;
  final VoidCallback onRemove;

  @override
  State<_PersonCard> createState() => _PersonCardState();
}

class _PersonCardState extends State<_PersonCard> {
  late final _name = TextEditingController(text: widget.person.name);
  late final _age = TextEditingController(
    text: widget.person.age?.toString() ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.registerForm;
    final cp = context.cp;
    final i = widget.index;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final born = DateTime.tryParse(widget.person.birthDate ?? '');
    final now = DateTime.now();
    final asksAge = widget.spec.has(RegistrationBlock.ageOnly);
    final asksBirth = widget.spec.has(RegistrationBlock.people) && !asksAge;
    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.person(i + 1),
                  style: cp.type.titleMedium.copyWith(color: cp.colors.text),
                ),
              ),
              if (widget.canRemove)
                CpButton.text(
                  key: Key('$_k.person.$i.remove'),
                  label: s.removePerson,
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          CpTextField(
            fieldKey: Key('$_k.person.$i.name'),
            label: s.name,
            controller: _name,
            required: true,
            textInputAction: TextInputAction.next,
            error: widget.nameError,
            onChanged: (v) => widget.onChanged((p) => p.copyWith(name: v)),
          ),
          if (asksBirth)
            CpDateField(
              fieldKey: Key('$_k.person.$i.birthDate'),
              label: s.birthDate,
              help: s.birthDateHelp,
              placeholder: s.chooseDate,
              required: true,
              value: born,
              error: widget.ageError,
              format: DateFormat.yMMMd(locale).format,
              firstDate: DateTime(now.year - 120),
              lastDate: now,
              onChanged: (day) {
                if (day == null) return;
                final iso =
                    '${day.year.toString().padLeft(4, '0')}-'
                    '${day.month.toString().padLeft(2, '0')}-'
                    '${day.day.toString().padLeft(2, '0')}';
                widget.onChanged((p) => p.copyWith(birthDate: iso));
              },
            ),
          if (asksAge)
            CpTextField(
              fieldKey: Key('$_k.person.$i.age'),
              label: s.age,
              controller: _age,
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              error: widget.ageError,
              onChanged: (v) {
                final age = int.tryParse(v);
                // Everything else kept, the person's ID included (#244).
                widget.onChanged(
                  (p) => p.copyWith(age: age, clearAge: age == null),
                );
              },
            ),
          // Photos and videos (Spec #233 Req 30, #247): unanswered until
          // chosen; whoever fills the form answers for a child.
          CpChoiceChips<bool>(
            key: Key('$_k.person.$i.photo'),
            label: s.photoConsent,
            help: s.photoConsentHelp,
            choices: [
              CpChoice(true, s.yes, key: Key('$_k.person.$i.photo.yes')),
              CpChoice(false, s.no, key: Key('$_k.person.$i.photo.no')),
            ],
            selected: {?widget.person.photoConsent},
            onChanged: (picked) {
              if (picked.isEmpty) return;
              widget.onChanged((p) => p.copyWith(photoConsent: picked.first));
            },
          ),
        ],
      ),
    );
  }
}

class _GroupNameField extends StatefulWidget {
  const _GroupNameField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_GroupNameField> createState() => _GroupNameFieldState();
}

class _GroupNameFieldState extends State<_GroupNameField> {
  late final _text = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CpTextField(
    fieldKey: const Key('$_k.groupName'),
    label: widget.label,
    controller: _text,
    onChanged: widget.onChanged,
  );
}

/// Arrival and departure for one person, in the event's time zone (Req 17
/// Stay; #244, B-02): a day, then its time. A day alone arrives at its
/// start and leaves at its end.
class _StayCard extends StatelessWidget {
  const _StayCard({
    super.key,
    required this.index,
    required this.title,
    required this.spec,
    required this.person,
    required this.error,
    required this.onChanged,
  });

  final int index;
  final String title;
  final RegistrationFormSpec spec;
  final PersonEntry person;
  final String? error;
  final ValueChanged<PersonEntry Function(PersonEntry)> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.registerForm;
    final cp = context.cp;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final zone = spec.timeZone;
    final start = spec.startDate ?? DateTime.now();
    final end = spec.endDate ?? start;
    DateTime? local(DateTime? d) => d == null ? null : inEventZone(d, zone);
    DateTime at(DateTime day, TimeOfDay time) => eventLocalToUtc(
      day.year,
      day.month,
      day.day,
      zone,
      hour: time.hour,
      minute: time.minute,
    );

    Widget moment({
      required String which,
      required String dayLabel,
      required String timeLabel,
      required DateTime? value,
      required TimeOfDay dayDefault,
      required PersonEntry Function(PersonEntry, DateTime?) set,
      String? error,
    }) {
      final shown = local(value);
      final time = shown == null
          ? dayDefault
          : TimeOfDay(hour: shown.hour, minute: shown.minute);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.sm,
        children: [
          CpDateField(
            fieldKey: Key('$_k.stay.$index.$which'),
            clearKey: Key('$_k.stay.$index.$which.clear'),
            label: dayLabel,
            placeholder: s.chooseDate,
            clearLabel: s.removePerson,
            value: shown,
            error: error,
            format: DateFormat.yMMMEd(locale).format,
            firstDate: start.subtract(const Duration(days: 30)),
            lastDate: end.add(const Duration(days: 30)),
            onChanged: (day) =>
                onChanged((p) => set(p, day == null ? null : at(day, time))),
          ),
          if (shown != null)
            CpSelectField(
              fieldKey: Key('$_k.stay.$index.$which.time'),
              label: timeLabel,
              value: MaterialLocalizations.of(context).formatTimeOfDay(time),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: time,
                );
                if (picked != null) {
                  onChanged((p) => set(p, at(shown, picked)));
                }
              },
            ),
        ],
      );
    }

    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          Text(
            title,
            style: cp.type.titleMedium.copyWith(color: cp.colors.text),
          ),
          moment(
            which: 'arrival',
            dayLabel: s.arriving,
            timeLabel: s.arrivalTime,
            value: person.arrivalAt,
            dayDefault: const TimeOfDay(hour: 0, minute: 0),
            set: (p, v) => v == null
                ? p.copyWith(clearArrival: true)
                : p.copyWith(arrivalAt: v),
          ),
          moment(
            which: 'departure',
            dayLabel: s.leaving,
            timeLabel: s.leavingTime,
            value: person.departureAt,
            dayDefault: const TimeOfDay(hour: 23, minute: 59),
            error: error,
            set: (p, v) => v == null
                ? p.copyWith(clearDeparture: true)
                : p.copyWith(departureAt: v),
          ),
        ],
      ),
    );
  }
}

/// One person's session choices (Req 17, W-01): a switch for a session on
/// its own, chips for sessions at the same time (one, or none).
class _SessionsCard extends StatelessWidget {
  const _SessionsCard({
    super.key,
    required this.index,
    required this.title,
    required this.spec,
    required this.person,
    required this.error,
    required this.onChanged,
    required this.onOptOuts,
  });

  final int index;
  final String title;
  final RegistrationFormSpec spec;
  final PersonEntry person;
  final String? error;
  final ValueChanged<Set<String>> onChanged;
  final ValueChanged<Set<String>> onOptOuts;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.registerForm;
    final cp = context.cp;
    final locale = Localizations.localeOf(context).toLanguageTag();
    String when(ChoiceSession session) => DateFormat.MMMEd(
      locale,
    ).add_jm().format(inEventZone(session.startAt, spec.timeZone));
    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          Text(
            title,
            style: cp.type.titleMedium.copyWith(color: cp.colors.text),
          ),
          if (error != null) CpFieldError(error!),
          for (final choice in spec.choices)
            if (choice.length == 1)
              CpSwitchRow(
                key: Key('$_k.session.$index.${choice.single.id}'),
                title: choice.single.title,
                help: when(choice.single),
                value: person.signUps.contains(choice.single.id),
                onChanged: (on) => onChanged(
                  on
                      ? {...person.signUps, choice.single.id}
                      : ({...person.signUps}..remove(choice.single.id)),
                ),
              )
            else
              CpChoiceChips<String>(
                key: Key('$_k.choice.$index.${choice.first.id}'),
                label: when(choice.first),
                help: s.eitherOr,
                choices: [
                  for (final session in choice)
                    CpChoice(
                      session.id,
                      session.title,
                      key: Key('$_k.session.$index.${session.id}'),
                    ),
                ],
                selected: {
                  for (final session in choice)
                    if (person.signUps.contains(session.id)) session.id,
                },
                onChanged: (picked) => onChanged({
                  ...person.signUps.difference({
                    for (final session in choice) session.id,
                  }),
                  ...picked,
                }),
              ),
          // Sessions everyone attends: turned off, the person opts out
          // and is not counted (#244, B-03).
          if (spec.attending.isNotEmpty) ...[
            Text(
              s.attendingTitle,
              style: cp.type.titleSmall.copyWith(color: cp.colors.text),
            ),
            Text(
              s.attendingHelp,
              style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
            ),
            for (final session in spec.attending)
              CpSwitchRow(
                key: Key('$_k.attending.$index.${session.id}'),
                title: session.title,
                help: when(session),
                value: !person.optOuts.contains(session.id),
                onChanged: (on) => onOptOuts(
                  on
                      ? ({...person.optOuts}..remove(session.id))
                      : {...person.optOuts, session.id},
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ContactCard extends StatefulWidget {
  const _ContactCard({
    required this.email,
    required this.phone,
    required this.emailError,
    required this.onEmail,
    required this.onPhone,
  });

  final String email;
  final String phone;
  final String? emailError;
  final ValueChanged<String> onEmail;
  final ValueChanged<String> onPhone;

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  late final _email = TextEditingController(text: widget.email);
  late final _phone = TextEditingController(text: widget.phone);

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.registerForm;
    final cp = context.cp;
    return CpCard(
      padding: EdgeInsets.all(cp.space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: cp.space.md,
        children: [
          CpTextField(
            fieldKey: const Key('$_k.email'),
            label: s.email,
            help: s.emailHelp,
            controller: _email,
            required: true,
            keyboardType: TextInputType.emailAddress,
            error: widget.emailError,
            onChanged: widget.onEmail,
          ),
          CpTextField(
            fieldKey: const Key('$_k.phone'),
            label: s.phone,
            controller: _phone,
            keyboardType: TextInputType.phone,
            onChanged: widget.onPhone,
          ),
        ],
      ),
    );
  }
}

/// One step's answers on the review page, with Edit (Req 20).
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    super.key,
    required this.title,
    required this.editKey,
    required this.onEdit,
    required this.rows,
  });

  final String title;
  final Key editKey;
  final VoidCallback onEdit;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.registerForm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CpSectionHeader(
          title: title,
          actionLabel: s.edit,
          actionKey: editKey,
          onAction: onEdit,
        ),
        CpCard(
          child: CpRowGroup(
            children: [
              for (final (label, value) in rows)
                CpListRow(title: label, subtitle: value),
            ],
          ),
        ),
      ],
    );
  }
}

/// After Submit (Req 20, 25, 33): registered, sent for review, or on the
/// waitlist with its number, then "my registration" or the event.
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.spec,
    required this.slug,
  });

  final SubmitResult result;
  final RegistrationFormSpec spec;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.registerForm;
    final cp = context.cp;
    final (icon, title, body) = switch (result.status) {
      'waitlisted' => (
        CpIcons.placesFull,
        s.waitlistedTitle(result.waitlistPosition ?? 0),
        s.waitlistedBody,
      ),
      'pending' => (CpIcons.statusDoing, s.pendingTitle, s.pendingBody),
      _ => (
        CpIcons.statusDone,
        s.registeredTitle,
        s.registeredBody(spec.title),
      ),
    };
    return Scaffold(
      backgroundColor: cp.colors.background,
      body: SafeArea(
        child: CpEmptyState(
          key: Key('$_k.result.${result.status}'),
          icon: icon,
          title: title,
          message: body,
          actionLabel: s.seeMine,
          actionKey: const Key('$_k.result.mine'),
          onAction: () => context.go('/e/$slug/registration'),
        ),
      ),
    );
  }
}

enum _SaveState { saving, saved, offline }

/// "Saved", "Saving" or "Not saved yet: no connection" at the top of the
/// form (Req 24), with an icon and colour together (Req 71).
class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator(this.state);

  final _SaveState state;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.registerForm;
    final cp = context.cp;
    final (icon, color, text) = switch (state) {
      _SaveState.saved => (CpIcons.statusDone, cp.colors.accent, s.saved),
      _SaveState.saving => (CpIcons.statusDoing, cp.colors.textMuted, s.saving),
      _SaveState.offline => (CpIcons.cloudOff, cp.colors.due, s.notSaved),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        key: Key('$_k.saveState.${state.name}'),
        spacing: cp.space.xs,
        children: [
          Icon(icon, size: cp.sizes.iconSm, color: color),
          Expanded(
            child: Text(
              text,
              style: cp.type.bodySmall.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// After the deadline (Req 35, B-13): only contact details can change, and
/// how to reach the organizer for anything else.
class _ContactOnlyNote extends StatelessWidget {
  const _ContactOnlyNote({required this.contactLine});

  final LocalText? contactLine;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.registerForm;
    final cp = context.cp;
    final language = Localizations.localeOf(context).languageCode;
    final line = contactLine == null
        ? null
        : language == 'gu' && contactLine!.gu != null
        ? contactLine!.gu!
        : contactLine!.en;
    return CpCard(
      key: const Key('$_k.contactOnly'),
      padding: EdgeInsets.all(cp.space.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: cp.space.sm,
        children: [
          Icon(
            CpIcons.registrationClosed,
            size: cp.sizes.iconMd,
            color: cp.colors.textMuted,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: cp.space.xs,
              children: [
                Text(
                  s.contactOnly,
                  style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                ),
                if (line != null)
                  Text(
                    line,
                    key: const Key('$_k.contactLine'),
                    style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
