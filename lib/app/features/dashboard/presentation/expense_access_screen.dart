import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/constants/app_spacing.dart';
import 'package:crewpoint_app/app/core/constants/breakpoints.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/widgets/primary_button.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/chat/application/users_by_id_provider.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/expense_access.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/member.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';

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
        builder: (dialog) => AlertDialog(
          key: const Key('expenses.access.narrowWarning'),
          title: Text(strings.narrowTitle),
          content: Text(strings.narrowBody(losing)),
          actions: [
            TextButton(
              key: const Key('expenses.access.narrowCancel'),
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(context.strings.roles.cancel),
            ),
            TextButton(
              key: const Key('expenses.access.narrowConfirm'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(strings.narrowConfirm),
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

    Widget scaffold(Widget body) => PopScope(
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
      child: Scaffold(
        appBar: AppBar(title: Text(strings.title), elevation: 0),
        body: body,
      ),
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
        const Center(
          child: CircularProgressIndicator(key: Key('expenses.access.loading')),
        ),
      );
    }
    final memberList = members.value!;
    final roleList = roles.value!;
    final names = ref.watch(usersByIdProvider(event.id)).value ?? const {};
    String nameOf(String uid) {
      if (uid == me) return context.strings.roles.you;
      final name = names[uid]?.displayName;
      return (name != null && name.isNotEmpty) ? name : uid;
    }

    String roleName(String id, String fallback) =>
        roleList.where((r) => r.id == id).firstOrNull?.name ?? fallback;
    // Roles and people who already see every expense are not offered.
    final pickableRoles = [
      for (final r in roleList)
        if (!_roleDefinitionReadsAll(r)) r,
    ];
    final pickablePeople = [
      for (final m in memberList)
        if (!_roleReadsAll(m, roleList)) m,
    ]..sort((a, b) => nameOf(a.uid).compareTo(nameOf(b.uid)));
    final nobody =
        _choice.mode == ExpenseAccessMode.selected &&
        _choice.roleIds.isEmpty &&
        _choice.uids.isEmpty;
    final enabled = !_busy;
    final theme = Theme.of(context);

    RadioListTile<ExpenseAccessMode> option(
      ExpenseAccessMode mode,
      String title,
      String help,
    ) => RadioListTile<ExpenseAccessMode>(
      key: Key('expenses.access.option.${mode.name}'),
      contentPadding: EdgeInsets.zero,
      value: mode,
      enabled: enabled,
      title: Text(title),
      subtitle: Text(help),
    );

    return scaffold(
      SingleChildScrollView(
        key: const Key('expenses.access.body'),
        padding: EdgeInsets.symmetric(
          horizontal: Breakpoints.screenHorizontalPadding(context),
          vertical: AppSpacing.lg,
        ),
        child: ContentMaxWidth(
          maxWidth: 560,
          child: RadioGroup<ExpenseAccessMode>(
            key: const Key('expenses.access.options'),
            groupValue: _choice.mode,
            onChanged: (m) {
              if (m == null || !enabled) return;
              setState(
                () => _choice = ExpenseAccess(
                  mode: m,
                  roleIds: _choice.roleIds,
                  uids: _choice.uids,
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.sm,
              children: [
                Text(strings.intro, style: theme.textTheme.bodyMedium),
                option(
                  ExpenseAccessMode.everyone,
                  strings.everyone,
                  strings.everyoneHelp,
                ),
                if (_choice.mode == ExpenseAccessMode.everyone)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xl),
                    child: SwitchListTile(
                      key: const Key('expenses.access.includeNonContributors'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        strings.includeNonContributors(
                          roleName('observer', 'Observers'),
                          roleName('vendor', 'Vendors'),
                        ),
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
                if (_choice.mode == ExpenseAccessMode.selected) ...[
                  if (nobody)
                    Text(
                      strings.nobodyNote,
                      key: const Key('expenses.access.nobody'),
                      style: theme.textTheme.bodySmall,
                    ),
                  Text(strings.rolesHeading, style: theme.textTheme.titleSmall),
                  if (pickableRoles.isEmpty) Text(strings.nothingToPick),
                  for (final role in pickableRoles)
                    CheckboxListTile(
                      key: Key('expenses.access.role.${role.id}'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(role.name),
                      value: _choice.roleIds.contains(role.id),
                      onChanged: enabled
                          ? (on) => _toggle(_choice.roleIds, role.id, on!, true)
                          : null,
                    ),
                  Text(
                    strings.peopleHeading,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (pickablePeople.isEmpty) Text(strings.nothingToPick),
                  for (final m in pickablePeople)
                    CheckboxListTile(
                      key: Key('expenses.access.person.${m.uid}'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(nameOf(m.uid)),
                      value: _choice.uids.contains(m.uid),
                      onChanged: enabled
                          ? (on) => _toggle(_choice.uids, m.uid, on!, false)
                          : null,
                    ),
                ],
                if (_error != null)
                  Text(
                    _error!,
                    key: const Key('expenses.access.error'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                PrimaryButton(
                  key: const Key('expenses.access.save'),
                  label: strings.save,
                  isLoading: _busy,
                  onPressed: _dirty ? () => _save(memberList, roleList) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
