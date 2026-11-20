import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/providers.dart';
import 'package:crewpoint_app/app/core/services/callable_errors.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/role_views.dart';
import 'package:crewpoint_app/app/features/dashboard/presentation/roles/roles_screen.dart';

/// The route ID that opens the editor on a new custom role.
const newRoleId = 'new';

/// Matches `MAX_NAME` in `functions/src/events/roles.ts`.
const _maxName = 60;

/// Edits one role's name and permissions, or makes a custom role (Req 26a, 33,
/// route `roles/:roleId`). Only `roles.manage` may save, and the Owner role is
/// read-only.
class RoleEditorScreen extends ConsumerStatefulWidget {
  const RoleEditorScreen({
    super.key,
    required this.event,
    required this.roleId,
  });

  final EventModel event;
  final String roleId;

  @override
  ConsumerState<RoleEditorScreen> createState() => _RoleEditorScreenState();
}

class _RoleEditorScreenState extends ConsumerState<RoleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  Set<String> _permissions = {};

  /// What was loaded, to tell whether anything changed.
  String _savedName = '';
  Set<String> _savedPermissions = {};
  bool _loaded = false;
  bool _busy = false;

  /// Picked once for a new role, so a retry after a failure saves the same
  /// role instead of a second one.
  String? _newId;

  bool get _isNew => widget.roleId == newRoleId;

  bool get _dirty =>
      _name.text.trim() != _savedName ||
      !_setEquals(_permissions, _savedPermissions);

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  void initState() {
    super.initState();
    if (_isNew) _loaded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Fills the form once from [role]. Later changes on the server do not
  /// overwrite what someone is typing.
  void _load(RoleDefinition role) {
    if (_loaded) return;
    _loaded = true;
    _savedName = role.name;
    _savedPermissions = {...role.permissions};
    _name.text = role.name;
    _permissions = {...role.permissions};
  }

  String _idFor(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final short = slug.length > 30 ? slug.substring(0, 30) : slug;
    final suffix = Random().nextInt(1 << 20).toRadixString(36);
    return '${short.isEmpty ? 'role' : short}-$suffix';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final strings = context.strings.roles;
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    final roleId = _isNew ? (_newId ??= _idFor(name)) : widget.roleId;
    setState(() => _busy = true);
    try {
      await ref
          .read(memberCallsProvider)
          .saveEventRole(
            eventId: widget.event.id,
            roleId: roleId,
            name: name,
            permissions: [
              for (final p in RoleCatalogue.current.permissions)
                if (_permissions.contains(p)) p,
            ],
          );
      if (!mounted) return;
      setState(() {
        _savedName = name;
        _savedPermissions = {..._permissions};
      });
      messenger.showSnackBar(SnackBar(content: Text(strings.saved)));
      _close();
    } catch (e, st) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userMessageFor(
              e,
              stackTrace: st,
              strings: context.strings.errors,
              fallback: strings.saveFailed,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Resets an edited preset, or deletes a custom role.
  Future<void> _remove(RoleDefinition role) async {
    final strings = context.strings.roles;
    final confirmed = await confirmAction(
      context,
      title: role.isPreset ? strings.resetTitle : strings.deleteTitle,
      body: role.isPreset ? strings.resetBody : strings.deleteBody,
      action: role.isPreset ? strings.reset : strings.delete,
      confirmKey: const Key('roles.editor.removeConfirm'),
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(memberCallsProvider)
          .deleteEventRole(eventId: widget.event.id, roleId: role.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(role.isPreset ? strings.resetDone : strings.deleted),
        ),
      );
      // Nothing is left to keep.
      setState(() {
        _savedName = _name.text.trim();
        _savedPermissions = {..._permissions};
      });
      _close();
    } catch (e, st) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            userMessageFor(
              e,
              stackTrace: st,
              strings: context.strings.errors,
              fallback: role.isPreset
                  ? strings.saveFailed
                  : strings.deleteFailed,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard/event/${widget.event.id}/roles');
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.roles;
    final me = ref.watch(currentUserIdProvider) ?? '';
    final event = widget.event;

    Widget scaffold(
      Widget body, {
      String? title,
      List<CpTopBarAction> actions = const [],
      Widget? bottom,
    }) => PopScope(
      canPop: !_dirty || _busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context) && mounted) {
          setState(() {
            _savedName = _name.text.trim();
            _savedPermissions = {..._permissions};
          });
          navigator.pop();
        }
      },
      child: AdminScaffold(
        title: title ?? strings.title,
        actions: actions,
        bottom: bottom,
        body: body,
      ),
    );

    if (!canViewRoles(event, me)) return scaffold(const NoAccessView());

    final RoleDefinition? role;
    if (_isNew) {
      role = null;
    } else {
      final roles = ref.watch(eventRolesProvider(event.id));
      if (roles.hasError && !roles.hasValue) {
        return scaffold(
          LoadFailedView(
            onRetry: () => ref.invalidate(eventRolesProvider(event.id)),
          ),
        );
      }
      if (!roles.hasValue) {
        return scaffold(
          CpLoadingState.rows(
            key: const Key('roles.loading'),
            semanticLabel: strings.title,
          ),
        );
      }
      role = roles.value!.where((r) => r.id == widget.roleId).firstOrNull;
      if (role == null) {
        return scaffold(GoneView(message: strings.roleNotFound));
      }
      _load(role);
    }

    final canEdit = event.can(me, 'roles.manage') && !(role?.isOwner ?? false);
    final removable =
        canEdit && role != null && (role.isEdited || !role.isPreset)
        ? role
        : null;
    final cp = context.cp;

    return scaffold(
      title: _isNew ? strings.newRole : role!.name,
      actions: [
        if (removable != null)
          CpTopBarAction(
            key: const Key('roles.editor.remove'),
            tooltip: removable.isPreset ? strings.reset : strings.delete,
            icon: removable.isPreset
                ? CpIcons.actionRetry
                : CpIcons.actionDelete,
            onPressed: () {
              if (!_busy) _remove(removable);
            },
          ),
      ],
      bottom: canEdit
          ? AdminSaveBar(
              child: CpButton(
                key: const Key('roles.editor.save'),
                label: strings.save,
                busy: _busy,
                onPressed: _busy || (!_dirty && !_isNew) ? null : _save,
              ),
            )
          : null,
      Form(
        key: _formKey,
        // A scroll view, not a lazy list, so the name field stays built and
        // is validated even when scrolled out of sight.
        child: SingleChildScrollView(
          key: const Key('roles.editor.body'),
          padding: EdgeInsets.fromLTRB(
            cp.space.lg,
            cp.space.sm,
            cp.space.lg,
            cp.space.xxl,
          ),
          child: ContentMaxWidth(
            maxWidth: cp.sizes.phoneColumn,
            child: Column(
              crossAxisAlignment: .stretch,
              spacing: cp.space.lg,
              children: [
                if (role?.isOwner ?? false)
                  AdminNote(
                    strings.ownerFixed,
                    key: const Key('roles.editor.ownerFixed'),
                    icon: CpIcons.statusInfo,
                  )
                else if (!canEdit)
                  AdminNote(
                    strings.readOnly,
                    key: const Key('roles.readOnly'),
                    icon: CpIcons.lock,
                  ),
                CpCard(
                  padding: EdgeInsets.all(cp.space.lg),
                  child: CpTextField(
                    fieldKey: const Key('roles.editor.name'),
                    label: strings.nameLabel,
                    required: true,
                    controller: _name,
                    onChanged: (_) => setState(() {}),
                    enabled: canEdit && !_busy,
                    maxLength: _maxName,
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return strings.nameRequired;
                      if (name.length > _maxName) {
                        return strings.nameTooLong(_maxName);
                      }
                      return null;
                    },
                  ),
                ),
                CpSectionHeader(title: strings.permissionsHeading),
                for (final group in permissionGroups)
                  ?_group(context, group, enabled: canEdit && !_busy),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One group of permissions as switches in a card, or null when the
  /// catalogue has none in it.
  Widget? _group(BuildContext context, String group, {required bool enabled}) {
    final cp = context.cp;
    final strings = context.strings.roles;
    final inGroup = [
      for (final p in RoleCatalogue.current.permissions)
        if (permissionGroupOf(p) == group) p,
    ];
    if (inGroup.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: cp.space.sm,
      children: [
        Text(
          strings.permissionGroup(group),
          style: cp.type.labelLarge.copyWith(color: cp.colors.textMuted),
        ),
        CpCard(
          padding: EdgeInsets.symmetric(
            horizontal: cp.space.lg,
            vertical: cp.space.xs,
          ),
          child: Column(
            children: [
              for (final p in inGroup)
                CpSwitchRow(
                  key: Key('roles.editor.permission.$p'),
                  title: strings.permission(p),
                  value: _permissions.contains(p),
                  onChanged: enabled
                      ? (on) => setState(() {
                          _permissions = on
                              ? {..._permissions, p}
                              : ({..._permissions}..remove(p));
                        })
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
