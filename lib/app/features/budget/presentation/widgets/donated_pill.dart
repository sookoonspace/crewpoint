import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/cp_icons.dart';
import 'package:crewpoint_app/app/core/i18n/app_strings.dart';

/// A small tag on an expense logged with "Donate this cost" on. A donation
/// leaves every balance at zero (the payer covers it), so without the tag
/// the row would read like an ordinary shared cost.
class DonatedPill extends StatelessWidget {
  const DonatedPill({super.key});

  @override
  Widget build(BuildContext context) => CpTag(
    key: const Key('budget.expense.donatedPill'),
    label: context.strings.budget.donated,
    icon: CpIcons.volunteerActivism,
  );
}
