import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/core/widgets/content_max_width.dart';

/// Shown in place of a screen the viewer has no permission for. Rules refuse
/// the data anyway; this explains why there is nothing to see.
class NoAccessView extends StatelessWidget {
  const NoAccessView({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.roles;
    return CpEmptyState(
      key: const Key('roles.noAccess'),
      icon: CpIcons.lock,
      title: strings.noAccessTitle,
      message: strings.noAccessBody,
    );
  }
}

/// Shown when data could not be read, with a retry.
class LoadFailedView extends StatelessWidget {
  const LoadFailedView({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings.roles;
    return CpErrorState(
      key: const Key('roles.loadFailed'),
      icon: CpIcons.wifiOff,
      title: strings.loadFailed,
      retryLabel: strings.retry,
      retryKey: const Key('roles.retry'),
      onRetry: onRetry,
    );
  }
}

/// A short centred message, such as a role or member that no longer exists.
class GoneView extends StatelessWidget {
  const GoneView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => CpEmptyState(
    key: const Key('roles.gone'),
    icon: CpIcons.statusError,
    title: message,
  );
}

/// The admin screens' frame (Spec #186): the top bar with back, then
/// [body] on the background colour.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.bottom,
    this.onBack,
  });

  final String title;
  final Widget body;
  final List<CpTopBarAction> actions;

  /// A save bar under the body, such as a form's Save.
  final Widget? bottom;

  /// Replaces the plain back, such as one that asks about unsaved changes.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final navigator = Navigator.of(context);
    return Scaffold(
      backgroundColor: cp.colors.background,
      appBar: CpTopBar(
        title: title,
        leadingTooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onLeading:
            onBack ?? (navigator.canPop() ? () => navigator.maybePop() : null),
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: bottom,
    );
  }
}

/// A scrolling admin page: [children] in the phone column with the
/// standard gaps between them.
class AdminList extends StatelessWidget {
  const AdminList({super.key, required this.children, this.listKey});

  final List<Widget> children;
  final Key? listKey;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return ListView(
      key: listKey,
      padding: EdgeInsets.fromLTRB(
        cp.space.lg,
        cp.space.sm,
        cp.space.lg,
        cp.space.xxl,
      ),
      children: [
        ContentMaxWidth(
          maxWidth: cp.sizes.phoneColumn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: cp.space.lg,
            children: children,
          ),
        ),
      ],
    );
  }
}

/// A form's Save at the bottom of the screen, as on the Person form.
class AdminSaveBar extends StatelessWidget {
  const AdminSaveBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CpSaveBar(child: child);
}

/// Muted help under a screen's title or above a section.
class AdminNote extends StatelessWidget {
  const AdminNote(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    final label = Text(
      text,
      style: cp.type.bodyMedium.copyWith(color: cp.colors.textMuted),
    );
    if (icon == null) return label;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: cp.space.sm,
      children: [
        Icon(icon, size: cp.sizes.iconMd, color: cp.colors.textMuted),
        Expanded(child: label),
      ],
    );
  }
}

/// Asks before leaving a form with unsaved changes. True means leave.
Future<bool> confirmDiscard(BuildContext context) async {
  final strings = context.strings.roles;
  final leave = await showDialog<bool>(
    context: context,
    builder: (dialog) => CpDialog(
      title: strings.discardTitle,
      message: strings.discardBody,
      actions: [
        CpButton.text(
          key: const Key('roles.discard.keep'),
          label: strings.keepEditing,
          onPressed: () => Navigator.of(dialog).pop(false),
        ),
        CpButton.destructive(
          key: const Key('roles.discard.confirm'),
          label: strings.discard,
          onPressed: () => Navigator.of(dialog).pop(true),
        ),
      ],
    ),
  );
  return leave ?? false;
}

/// Asks to confirm a destructive step. True means go ahead.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  required Key confirmKey,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => CpDialog(
      title: title,
      message: body,
      actions: [
        CpButton.text(
          label: context.strings.roles.cancel,
          onPressed: () => Navigator.of(dialog).pop(false),
        ),
        CpButton.destructive(
          key: confirmKey,
          label: action,
          onPressed: () => Navigator.of(dialog).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
