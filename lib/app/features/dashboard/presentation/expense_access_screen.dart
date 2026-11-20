import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/expense_access.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/member.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/widgets/chosen_people_list.dart';

/// Who can see expenses (Req 38, 38d; route `settings/expenses`). Anyone with
/// `event.manage` chooses Everyone, Only people involved, or Selected roles
/// and people. Saving goes through `setExpenseAccess`, which recalculates
/// everyone's access on the server and records the change.
class ExpenseAccessScreen extends ConsumerStatefulWidget {
  const ExpenseAccessScreen({super.key, required this.event});

  final EventModel event;

  @override
  ConsumerState<ExpenseAccessScreen> createState() =>
      _ExpenseAccessScreenState();
}

class _ExpenseAccessScreenState extends ConsumerState<ExpenseAccessScreen> {
  late ExpenseAccess _saved;
  late ExpenseAccess _choice;
  bool _busy = false;
  String? _error;

  bool get _dirty => _choice != _saved;

  @override
  void initState() {
    super.initState();
    _saved = widget.event.expenseAccess;
    _choice = _saved;
  }

  /// Whether [member]'s roles already read every expense, whatever the
  /// option, so they are not offered and never lose access.
  static bool _roleReadsAll(MemberModel member, List<RoleDefinition> roles) {
    final granted = computePermissions(member.roleIds, roles);
    return granted.contains('money.read') ||
        granted.contains('expenses.readAll');
  }

  static bool _roleDefinitionReadsAll(RoleDefinition role) =>
      role.permissions.contains('money.read') ||
      role.permissions.contains('expenses.readAll');

  /// How many people see every expense now and would not after saving.
  int _losing(List<MemberModel> members, List<RoleDefinition> roles) => [
    for (final m in members)
      if (m.permissions.contains('expenses.readAll') &&
          !_roleReadsAll(m, roles) &&
          !_choice.readsAll(m.uid, m.roleIds))
        m,
  ].length;

  Future<void> _save(
    List<MemberModel> members,
    List<RoleDefinition> roles,
  ) async {
    final strings = context.strings.expenseAccess;
    final losing = _losing(members, roles);
    if (losing > 0) {
      final go = await showDialog<bool>(
        context: context,
        builder: (dialog) => CpDialog(
          key: const Key('expenses.access.narrowWarning'),
          title: strings.narrowTitle,
          message: strings.narrowBody(losing),
          actions: [
            CpButton.text(
              key: const Key('expenses.access.narrowCancel'),
              label: context.strings.roles.cancel,
              onPressed: () => Navigator.of(dialog).pop(false),
            ),
            CpButton.destructive(
              key: const Key('expenses.access.narrowConfirm'),
              label: strings.narrowConfirm,
              onPressed: () => Navigator.of(dialog).pop(true),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final choice = _choice;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(memberCallsProvider)
          .setExpenseAccess(eventId: widget.event.id, access: choice);
      if (!mounted) return;
      setState(() => _saved = choice);
      messenger.showSnackBar(SnackBar(content: Text(strings.saved)));
    } catch (e, st) {
      if (!mounted) return;
      setState(
        () => _error = userMessageFor(
          e,
          stackTrace: st,
          strings: context.strings.errors,
          fallback: strings.saveFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(List<String> list, String id, bool on, bool isRole) {
    final next = [...list.where((x) => x != id), if (on) id];
    setState(
      () => _choice = isRole
          ? _choice.copyWith(roleIds: next)
          : _choice.copyWith(uids: next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.expenseAccess;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final event = widget.event;

    Widget scaffold(Widget body, {Widget? bottom}) => PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (await confirmDiscard(context) && mounted) {
          setState(() => _choice = _saved);
          if (router.canPop()) {
            router.pop();
          } else {
            router.go('/dashboard/event/${event.id}/settings');
          }
        }
      },
      child: AdminScaffold(title: strings.title, body: body, bottom: bottom),
    );

    if (!event.can(me, 'event.manage')) return scaffold(const NoAccessView());

    final members = ref.watch(eventMembersProvider(event.id));
    final roles = ref.watch(eventRolesProvider(event.id));
    if ((members.hasError && !members.hasValue) ||
        (roles.hasError && !roles.hasValue)) {
      return scaffold(
        LoadFailedView(
          onRetry: () {
            ref.invalidate(eventMembersProvider(event.id));
            ref.invalidate(eventRolesProvider(event.id));
          },
        ),
      );
    }
    if (!members.hasValue || !roles.hasValue) {
      return scaffold(
        CpLoadingState.rows(
          key: const Key('expenses.access.loading'),
          semanticLabel: strings.title,
        ),
      );
    }
    final memberList = members.value!;
    final roleList = roles.value!;

    String roleName(String id, String fallback) =>
        roleList.where((r) => r.id == id).firstOrNull?.name ?? fallback;
    // Roles and people who already see every expense are not offered.
    final pickableRoles = [
      for (final r in roleList)
        if (!_roleDefinitionReadsAll(r)) r,
    ];
    final readsAll = {
      for (final m in memberList)
        if (_roleReadsAll(m, roleList)) m.uid,
    };
    final nobody =
        _choice.mode == ExpenseAccessMode.selected &&
        _choice.roleIds.isEmpty &&
        _choice.uids.isEmpty;
    final enabled = !_busy;
    final cp = context.cp;

    void pick(ExpenseAccessMode? m) {
      if (m == null || !enabled) return;
      setState(
        () => _choice = ExpenseAccess(
          mode: m,
          roleIds: _choice.roleIds,
          uids: _choice.uids,
        ),
      );
    }

    Widget option(ExpenseAccessMode mode, String title, String help) =>
        _AccessOption(
          key: Key('expenses.access.option.${mode.name}'),
          mode: mode,
          title: title,
          help: help,
          enabled: enabled,
          onTap: () => pick(mode),
        );

    Widget switches(List<Widget> rows) => CpCard(
      padding: EdgeInsets.symmetric(
        horizontal: cp.space.lg,
        vertical: cp.space.xs,
      ),
      child: Column(children: rows),
    );

    return scaffold(
      bottom: AdminSaveBar(
        child: CpButton(
          key: const Key('expenses.access.save'),
          label: strings.save,
          busy: _busy,
          onPressed: _dirty && !_busy
              ? () => _save(memberList, roleList)
              : null,
        ),
      ),
      RadioGroup<ExpenseAccessMode>(
        key: const Key('expenses.access.options'),
        groupValue: _choice.mode,
        onChanged: pick,
        child: AdminList(
          listKey: const Key('expenses.access.body'),
          children: [
            AdminNote(strings.intro),
            CpCard(
              child: CpRowGroup(
                children: [
                  option(
                    ExpenseAccessMode.everyone,
                    strings.everyone,
                    strings.everyoneHelp,
                  ),
                  option(
                    ExpenseAccessMode.involved,
                    strings.involved,
                    strings.involvedHelp,
                  ),
                  option(
                    ExpenseAccessMode.selected,
                    strings.selected,
                    strings.selectedHelp,
                  ),
                ],
              ),
            ),
            if (_choice.mode == ExpenseAccessMode.everyone)
              switches([
                CpSwitchRow(
                  key: const Key('expenses.access.includeNonContributors'),
                  title: strings.includeNonContributors(
                    roleName('observer', 'Observers'),
                    roleName('vendor', 'Vendors'),
                  ),
                  value: _choice.includeNonContributors,
                  onChanged: enabled
                      ? (on) => setState(
                          () => _choice = ExpenseAccess.everyone(
                            includeNonContributors: on,
                          ),
                        )
                      : null,
                ),
              ]),
            if (_choice.mode == ExpenseAccessMode.selected) ...[
              if (nobody)
                AdminNote(
                  strings.nobodyNote,
                  key: const Key('expenses.access.nobody'),
                  icon: CpIcons.statusInfo,
                ),
              CpSectionHeader(title: strings.rolesHeading),
              if (pickableRoles.isEmpty)
                AdminNote(strings.nothingToPick)
              else
                switches([
                  for (final role in pickableRoles)
                    CpSwitchRow(
                      key: Key('expenses.access.role.${role.id}'),
                      title: role.name,
                      value: _choice.roleIds.contains(role.id),
                      onChanged: enabled
                          ? (on) => _toggle(_choice.roleIds, role.id, on, true)
                          : null,
                    ),
                ]),
              CpSectionHeader(title: strings.peopleHeading),
              // Chosen by name search, so a large event never lists
              // everyone (Req 43a).
              ChosenPeopleList(
                eventId: event.id,
                words: event.words,
                keyPrefix: 'expenses.access.person',
                chosen: _choice.uids.toSet(),
                exclude: readsAll,
                enabled: enabled,
                onChanged: (uids) => setState(
                  () => _choice = _choice.copyWith(uids: uids.toList()..sort()),
                ),
              ),
            ],
            if (_error != null)
              KeyedSubtree(
                key: const Key('expenses.access.error'),
                child: CpFieldError(_error!),
              ),
          ],
        ),
      ),
    );
  }
}

/// One choice of who sees expenses: a radio, its name and what it means.
/// The radio follows the [RadioGroup] above it.
class _AccessOption extends StatelessWidget {
  const _AccessOption({
    super.key,
    required this.mode,
    required this.title,
    required this.help,
    required this.enabled,
    required this.onTap,
  });

  final ExpenseAccessMode mode;
  final String title;
  final String help;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return MergeSemantics(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: cp.sizes.rowMinHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: cp.space.sm,
                vertical: cp.space.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio<ExpenseAccessMode>(
                    value: mode,
                    enabled: enabled,
                    activeColor: cp.colors.accent,
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: cp.space.md,
                        right: cp.space.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: cp.space.xs / 2,
                        children: [
                          Text(
                            title,
                            style: cp.type.titleSmall.copyWith(
                              color: cp.colors.text,
                            ),
                          ),
                          Text(
                            help,
                            style: cp.type.bodySmall.copyWith(
                              color: cp.colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
