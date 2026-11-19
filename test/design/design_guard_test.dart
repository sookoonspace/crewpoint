// The design guard (Spec #186 Req 16, ledger L18): outside
// lib/app/core/design/, code takes colours, fonts, sizes and visual widgets
// from the design system, never its own.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'design_guard.dart';

/// Files that still break a rule because their screen has not moved to the
/// design system yet (Technical Decision 3). Each migration Work Item removes
/// its files; #208 empties the list. A file not listed here that breaks a
/// rule fails the test, and so does a listed file that no longer breaks any.
const notYetMigrated = <String>{
  'lib/app/core/router/app_router.dart',
  'lib/app/core/widgets/balance_tile.dart',
  'lib/app/core/widgets/conversation_tile.dart',
  'lib/app/core/widgets/destructive_button.dart',
  'lib/app/core/widgets/empty_state_placeholder.dart',
  'lib/app/core/widgets/event_guard.dart',
  'lib/app/core/widgets/form_card_shell.dart',
  'lib/app/core/widgets/forms/app_date_field.dart',
  'lib/app/core/widgets/forms/app_dropdown.dart',
  'lib/app/core/widgets/forms/app_text_field.dart',
  'lib/app/core/widgets/module_guard.dart',
  'lib/app/core/widgets/network_image_with_placeholder.dart',
  'lib/app/core/widgets/primary_button.dart',
  'lib/app/core/widgets/reserved_checkmark_chip.dart',
  'lib/app/core/widgets/segmented_filter_bar.dart',
  'lib/app/core/widgets/settings_row.dart',
  'lib/app/core/widgets/skeletons.dart',
  'lib/app/core/widgets/stat_triplet.dart',
  'lib/app/core/widgets/status_badge.dart',
  'lib/app/features/auth/presentation/widgets/email_auth_form.dart',
  'lib/app/features/auth/presentation/widgets/email_unverified_banner.dart',
  'lib/app/features/auth/presentation/widgets/social_auth_buttons.dart',
  'lib/app/features/budget/presentation/budget_ledger_screen.dart',
  'lib/app/features/budget/presentation/budget_screen.dart',
  'lib/app/features/budget/presentation/event_budget_page.dart',
  'lib/app/features/budget/presentation/widgets/debt_tile.dart',
  'lib/app/features/budget/presentation/widgets/donated_pill.dart',
  'lib/app/features/budget/presentation/widgets/expense_modal.dart',
  'lib/app/features/budget/presentation/widgets/expense_tile.dart',
  'lib/app/features/budget/presentation/widgets/receipt_viewer.dart',
  'lib/app/features/budget/presentation/widgets/recent_expense_tile.dart',
  'lib/app/features/budget/presentation/widgets/settle_sheet.dart',
  'lib/app/features/budget/presentation/widgets/settle_up_fallback_sheet.dart',
  'lib/app/features/chat/presentation/chat_screen.dart',
  'lib/app/features/chat/presentation/event_chat_page.dart',
  'lib/app/features/chat/presentation/widgets/critical_alert_modal.dart',
  'lib/app/features/chat/presentation/widgets/dispute_sheet.dart',
  'lib/app/features/chat/presentation/widgets/message_bubble.dart',
  'lib/app/features/counts/presentation/counts_screen.dart',
  'lib/app/features/dashboard/presentation/create_event_screen.dart',
  'lib/app/features/dashboard/presentation/edit_event_screen.dart',
  'lib/app/features/dashboard/presentation/event_settings_screen.dart',
  'lib/app/features/dashboard/presentation/expense_access_screen.dart',
  'lib/app/features/dashboard/presentation/join_screen.dart',
  'lib/app/features/dashboard/presentation/member_management_screen.dart',
  'lib/app/features/dashboard/presentation/roles/crews_screen.dart',
  'lib/app/features/dashboard/presentation/roles/member_detail_screen.dart',
  'lib/app/features/dashboard/presentation/roles/role_editor_screen.dart',
  'lib/app/features/dashboard/presentation/roles/role_views.dart',
  'lib/app/features/dashboard/presentation/roles/roles_screen.dart',
  'lib/app/features/dashboard/presentation/roles/transfer_screen.dart',
  'lib/app/features/dashboard/presentation/setup_checklist_screen.dart',
  'lib/app/features/dashboard/presentation/template_picker_screen.dart',
  'lib/app/features/dashboard/presentation/widgets/add_member_sheet.dart',
  'lib/app/features/dashboard/presentation/widgets/chosen_people_list.dart',
  'lib/app/features/dashboard/presentation/widgets/join_event_sheet.dart',
  'lib/app/features/dashboard/presentation/widgets/member_picker_sheet.dart',
  'lib/app/features/dashboard/presentation/widgets/mute_event_sheet.dart',
  'lib/app/features/dev/presentation/dev_tools_screen.dart',
  'lib/app/features/onboarding/presentation/onboarding_screen.dart',
  'lib/app/features/participants/presentation/field_answer_input.dart',
  'lib/app/features/participants/presentation/fields_screen.dart',
  'lib/app/features/participants/presentation/group_sheets.dart',
  'lib/app/features/participants/presentation/import_screen.dart',
  'lib/app/features/participants/presentation/link_requests_screen.dart',
  'lib/app/features/participants/presentation/roster_screen.dart',
  'lib/app/features/profile/presentation/edit_profile_screen.dart',
  'lib/app/features/profile/presentation/markdown_render_screen.dart',
  'lib/app/features/profile/presentation/notification_settings_screen.dart',
  'lib/app/features/profile/presentation/privacy_dashboard_screen.dart',
  'lib/app/features/profile/presentation/profile_screen.dart',
  'lib/app/features/profile/presentation/widgets/delete_account_dialog.dart',
  'lib/app/features/profile/presentation/widgets/sign_out_sheet.dart',
  'lib/app/features/profile/presentation/widgets/theme_switcher_sheet.dart',
  'lib/app/features/schedule/presentation/agenda_screen.dart',
  'lib/app/features/schedule/presentation/schedule_screen.dart',
  'lib/app/features/schedule/presentation/session_screen.dart',
  'lib/app/features/schedule/presentation/session_tile.dart',
  'lib/app/features/schedule/presentation/venue_card.dart',
  'lib/app/features/tasks/presentation/event_task_detail_page.dart',
  'lib/app/features/tasks/presentation/my_tasks_screen.dart',
  'lib/app/features/tasks/presentation/task_detail_screen.dart',
  'lib/app/features/tasks/presentation/widgets/task_tile.dart',
  'lib/app/features/tasks/presentation/widgets/tasks_filter_bar.dart',
  'lib/app/features/tasks/presentation/widgets/tasks_group_header.dart',
  'lib/main.dart',
};

void main() {
  group('findStyleHits', () {
    List<String> rules(String source) => [
      for (final hit in findStyleHits('a.dart', source)) hit.rule,
    ];

    test('flags raw colours and Material colour names', () {
      expect(rules('final c = Color(0xFF112233);'), ['Color(0x…)']);
      expect(rules('final c = Colors.white;'), ['Colors.…']);
      expect(rules('final c = context.cp.colors.accent;'), isEmpty);
    });

    test('flags font families set outside the design system', () {
      expect(rules('final s = GoogleFonts.inter();'), ['GoogleFonts']);
      expect(rules("const s = TextStyle(fontFamily: 'Mono');"), [
        'fontFamily:',
      ]);
    });

    test('flags bare non-zero numbers in sizes, spacing and radii', () {
      expect(rules('const EdgeInsets.all(16)'), ['number in EdgeInsets']);
      expect(rules('EdgeInsets.fromLTRB(0, 8, 0, 0)'), [
        'number in EdgeInsets',
      ]);
      expect(rules('const SizedBox(height: 8)'), ['number in SizedBox']);
      expect(rules('BorderRadius.circular(12)'), ['number in BorderRadius']);
      expect(rules('Radius.circular(4.5)'), ['number in Radius']);
    });

    test('allows zero, tokens and calculated sizes', () {
      expect(rules('const SizedBox(height: 0)'), isEmpty);
      expect(rules('EdgeInsets.all(space.lg)'), isEmpty);
      expect(rules('SizedBox(width: maxWidth * 0.5)'), isEmpty);
      expect(rules('EdgeInsets.only(top: inset + 2)'), isEmpty);
    });

    test('flags plain Material visual widgets', () {
      expect(rules('Card(child: x)'), ['Card']);
      expect(rules('ListTile(title: x)'), ['ListTile']);
      expect(rules('TextButton.icon(onPressed: f)'), ['TextButton']);
      expect(rules('FilledButton(onPressed: f)'), ['FilledButton']);
      expect(rules('ChoiceChip(label: x)'), ['ChoiceChip']);
    });

    test('leaves out style helpers, lookalike names, comments and strings', () {
      expect(rules('ElevatedButton.styleFrom(elevation: e)'), isEmpty);
      expect(rules('ActionChip(label: x)'), isEmpty);
      expect(rules('MyCard(child: x)'), isEmpty);
      expect(rules('// Colors.red and Card(child)'), isEmpty);
      expect(rules("final s = 'Colors.red Card(';"), isEmpty);
      expect(rules('/* SizedBox(height: 8) */'), isEmpty);
    });

    test('reports the line of each hit', () {
      final hits = findStyleHits('a.dart', 'a\nb\nfinal c = Colors.red;');
      expect(hits.single.line, 3);
    });
  });

  test('code outside the design system uses only design tokens', () {
    final offenders = <String>[];
    final cleanButListed = <String>[];
    for (final file in guardedFiles()) {
      final path = file.path;
      if (listedExceptions.containsKey(path)) continue;
      final hits = findStyleHits(path, file.readAsStringSync());
      if (hits.isEmpty && notYetMigrated.contains(path)) {
        cleanButListed.add(path);
      } else if (hits.isNotEmpty && !notYetMigrated.contains(path)) {
        offenders.addAll(hits.map((h) => h.toString()));
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Use the tokens and components in lib/app/core/design/ instead.',
    );
    expect(
      cleanButListed,
      isEmpty,
      reason:
          'These files follow the rules now: remove them from '
          'notYetMigrated.',
    );
  });

  test('every listed file still exists', () {
    expect([
      for (final path in notYetMigrated)
        if (!File(path).existsSync()) path,
    ], isEmpty);
  });
}
