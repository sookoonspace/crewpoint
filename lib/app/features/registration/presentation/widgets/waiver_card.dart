import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';
import 'package:crewpoint_app/app/features/registration/domain/waivers.dart';

/// One person a waiver applies to, on a [WaiverCard].
@immutable
class WaiverPersonRow {
  const WaiverPersonRow({
    required this.index,
    required this.name,
    required this.isChild,
    required this.accepted,
    this.missing = false,
  });

  /// Which person, passed back through [WaiverCard.onAccept].
  final int index;
  final String name;

  /// A child's acceptance is as parent or guardian (Req 27).
  final bool isChild;
  final bool accepted;

  /// A required waiver not accepted, shown as an error (Req 29).
  final bool missing;
}

/// A waiver to read and accept for each person it applies to (Spec #233
/// Req 26-29; #246): its title, whether it is required, its text behind
/// "Read the waiver", and a switch per person.
class WaiverCard extends StatefulWidget {
  const WaiverCard({
    super.key,
    required this.keyPrefix,
    required this.waiver,
    required this.language,
    required this.people,
    required this.onAccept,
  });

  final String keyPrefix;
  final Waiver waiver;

  /// `en` or `gu`, for the waiver's own words.
  final String language;
  final List<WaiverPersonRow> people;
  final void Function(int index, bool accepted) onAccept;

  @override
  State<WaiverCard> createState() => _WaiverCardState();
}

class _WaiverCardState extends State<WaiverCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = context.strings.registerForm;
    final cp = context.cp;
    final w = widget.waiver;
    final gu = widget.language == 'gu';
    final title = gu && w.title.gu != null ? w.title.gu! : w.title.en;
    final text = gu && w.text.gu != null ? w.text.gu! : w.text.en;
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
          Wrap(
            spacing: cp.space.sm,
            runSpacing: cp.space.xs,
            children: [
              if (w.required)
                CpTag(
                  label: s.waiverRequired,
                  icon: CpIcons.statusInfo,
                ),
              CpTag(label: s.waiverVersion(w.version), tone: CpTagTone.quiet),
            ],
          ),
          if (!w.required)
            Text(
              s.waiverLater,
              style: cp.type.bodySmall.copyWith(color: cp.colors.textMuted),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: CpButton.text(
              key: Key('${widget.keyPrefix}.read'),
              label: _open ? s.hideWaiver : s.readWaiver,
              icon: CpIcons.terms,
              onPressed: () => setState(() => _open = !_open),
            ),
          ),
          if (_open)
            Container(
              key: Key('${widget.keyPrefix}.text'),
              padding: EdgeInsets.all(cp.space.md),
              decoration: BoxDecoration(
                color: cp.colors.fill,
                borderRadius: cp.radii.md,
              ),
              child: SelectableText(
                text,
                style: cp.type.bodyMedium.copyWith(color: cp.colors.text),
              ),
            ),
          for (final p in widget.people) ...[
            CpSwitchRow(
              key: Key('${widget.keyPrefix}.accept.${p.index}'),
              title: p.isChild ? s.acceptAsGuardian(p.name) : s.acceptFor(p.name),
              value: p.accepted,
              onChanged: (on) => widget.onAccept(p.index, on),
            ),
            if (p.missing) CpFieldError(s.waiverNeeded),
          ],
        ],
      ),
    );
  }
}
