import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/cp_button.dart';
import 'package:crewpoint_app/app/core/design/components/cp_sheet_dialog.dart';
import 'package:crewpoint_app/app/core/design/layout/breakpoints.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// What to say before leaving unsaved edits in the detail panel.
@immutable
class CpUnsavedText {
  const CpUnsavedText({
    required this.title,
    required this.body,
    required this.keep,
    required this.discard,
  });

  final String title;
  final String body;
  final String keep;
  final String discard;
}

/// A list and the chosen item's detail (Spec #186 Req 23, Technical
/// Decision 9).
///
/// From 840 px the detail sits in a panel beside the list, or [placeholder]
/// when nothing is chosen; below, the detail is a full page and the list
/// shows alone. The route is the source of truth: a detail route builds
/// this with [detail] set (and the list showing it selected), so back and
/// shared links work, and resizing moves between the split and full pages.
/// Build those routes' pages with [cpListDetailPage].
///
/// Rows choose through [CpListDetail.select], which asks first when the
/// open detail has unsaved edits ([CpUnsavedChanges]).
class CpListDetail extends StatefulWidget {
  const CpListDetail({
    super.key,
    required this.list,
    required this.placeholder,
    required this.unsavedText,
    this.detail,
  });

  final Widget list;

  /// The chosen item, from the route; null when none is.
  final Widget? detail;

  /// Shown in the panel when nothing is chosen, such as "Select a
  /// participant to see details".
  final String placeholder;
  final CpUnsavedText unsavedText;

  /// Whether [context] is wide enough to show list and detail side by side.
  static bool isSplit(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= Breakpoints.mediumMax;

  /// Runs [go] (usually a route change) after asking, when the detail
  /// panel has unsaved edits. [context] must be inside the layout, such as
  /// the row's own; outside a list and detail it just runs [go].
  static Future<void> select(BuildContext context, VoidCallback go) async {
    final state = context.findAncestorStateOfType<_CpListDetailState>();
    if (state == null) {
      go();
      return;
    }
    await state._select(go);
  }

  @override
  State<CpListDetail> createState() => _CpListDetailState();
}

class _CpListDetailState extends State<CpListDetail> {
  bool _dirty = false;

  Future<void> _select(VoidCallback go) async {
    if (_dirty && CpListDetail.isSplit(context)) {
      final text = widget.unsavedText;
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialog) => CpDialog(
          title: text.title,
          message: text.body,
          actions: [
            CpButton.text(
              key: const Key('listDetail.unsaved.keep'),
              label: text.keep,
              onPressed: () => Navigator.of(dialog).pop(false),
            ),
            CpButton.destructive(
              key: const Key('listDetail.unsaved.discard'),
              label: text.discard,
              onPressed: () => Navigator.of(dialog).pop(true),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
      _dirty = false;
    }
    go();
  }

  @override
  Widget build(BuildContext context) {
    final cp = context.cp;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < Breakpoints.mediumMax) {
          return widget.detail ?? widget.list;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: const Key('listDetail.list'),
              width: cp.sizes.listPane,
              child: widget.list,
            ),
            VerticalDivider(
              width: cp.sizes.hairline,
              thickness: cp.sizes.hairline,
              color: cp.colors.border,
            ),
            Expanded(
              key: const Key('listDetail.panel'),
              child:
                  widget.detail ??
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(cp.space.xl),
                      child: Text(
                        widget.placeholder,
                        key: const Key('listDetail.placeholder'),
                        textAlign: TextAlign.center,
                        style: cp.type.bodyMedium.copyWith(
                          color: cp.colors.textMuted,
                        ),
                      ),
                    ),
                  ),
            ),
          ],
        );
      },
    );
  }
}

/// Tells the surrounding [CpListDetail] whether the detail has unsaved
/// edits, so choosing another row asks first.
class CpUnsavedChanges extends StatefulWidget {
  const CpUnsavedChanges({super.key, required this.dirty, required this.child});

  final bool dirty;
  final Widget child;

  @override
  State<CpUnsavedChanges> createState() => _CpUnsavedChangesState();
}

class _CpUnsavedChangesState extends State<CpUnsavedChanges> {
  _CpListDetailState? _host;

  void _report() => _host?._dirty = widget.dirty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _host = context.findAncestorStateOfType<_CpListDetailState>();
    _report();
  }

  @override
  void didUpdateWidget(CpUnsavedChanges old) {
    super.didUpdateWidget(old);
    _report();
  }

  @override
  void dispose() {
    _host?._dirty = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The page for a list or detail route. From 840 px rows change without a
/// page transition, and every row shares [splitKey], so the list keeps its
/// place while the panel changes; narrower, the detail slides in as its own
/// page under [pageKey].
Page<void> cpListDetailPage({
  required BuildContext context,
  required LocalKey pageKey,
  required LocalKey splitKey,
  required Widget child,
  String? name,
}) {
  if (CpListDetail.isSplit(context)) {
    return _InstantPage(key: splitKey, name: name, child: child);
  }
  return MaterialPage<void>(key: pageKey, name: name, child: child);
}

class _InstantPage extends Page<void> {
  const _InstantPage({super.key, super.name, required this.child});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => _InstantRoute(this);
}

/// Shows its page's current child, with no transition. Rows share one page
/// key, so the navigator updates this route in place when the row changes,
/// and the content must come from the page each time it builds.
class _InstantRoute extends PageRoute<void> {
  _InstantRoute(_InstantPage page) : super(settings: page);

  _InstantPage get _page => settings as _InstantPage;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _page.child;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;
}
