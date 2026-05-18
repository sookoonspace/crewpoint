import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crewpoint_app/app/core/constants/app_icons.dart';

/// Smoke check: representative semantic names resolve to the expected
/// `IconData`. Not exhaustive — Phase 2 sweep verifies coverage. If any
/// of these starts failing, the underlying glyph was changed in
/// `app_icons.dart` and that may be intentional (variant normalisation) or
/// a regression — the test is the conversation starter.
void main() {
  group('Nav', () {
    test('navHome resolves to dashboard_outlined', () {
      expect(AppIcons.navHome, Icons.dashboard_outlined);
    });
    test('navHomeFilled resolves to dashboard', () {
      expect(AppIcons.navHomeFilled, Icons.dashboard);
    });
    test(
      'navTasks / navChat / navBudget / navProfile use the outlined family',
      () {
        expect(AppIcons.navTasks, Icons.task_outlined);
        expect(AppIcons.navChat, Icons.chat_outlined);
        expect(AppIcons.navBudget, Icons.account_balance_wallet_outlined);
        expect(AppIcons.navProfile, Icons.person_outline);
      },
    );
  });

  group('Status', () {
    test('statusTodo / statusDoing / statusDone match TaskStatus glyphs', () {
      expect(AppIcons.statusTodo, Icons.radio_button_unchecked);
      expect(AppIcons.statusDoing, Icons.play_circle_outline);
      expect(AppIcons.statusDone, Icons.check_circle);
    });
    test('statusUrgent collapses warning_amber_rounded to warning_amber', () {
      expect(AppIcons.statusUrgent, Icons.warning_amber);
    });
    test('statusInfo uses info_outline', () {
      expect(AppIcons.statusInfo, Icons.info_outline);
    });
  });

  group('Actions (variant collapses)', () {
    test('actionLogout collapses logout_rounded to logout', () {
      expect(AppIcons.actionLogout, Icons.logout);
    });
    test('actionCopy collapses copy_rounded to copy', () {
      expect(AppIcons.actionCopy, Icons.copy);
    });
    test('actionAdd uses Icons.add (not add_circle)', () {
      expect(AppIcons.actionAdd, Icons.add);
    });
    test('actionAddCircle uses the outlined variant', () {
      expect(AppIcons.actionAddCircle, Icons.add_circle_outline);
    });
    test('actionRetry uses refresh', () {
      expect(AppIcons.actionRetry, Icons.refresh);
    });
  });

  group('Payment methods (canonical glyphs)', () {
    test(
      'paymentVenmo / paymentZelle / paymentCashApp / paymentPayPal / paymentCash',
      () {
        expect(AppIcons.paymentVenmo, Icons.payment);
        expect(AppIcons.paymentZelle, Icons.account_balance);
        expect(AppIcons.paymentCashApp, Icons.attach_money);
        expect(AppIcons.paymentPayPal, Icons.paypal_outlined);
        expect(AppIcons.paymentCash, Icons.money);
      },
    );
  });

  group('Domain nouns + states', () {
    test('calendar family collapses to Icons.calendar_today', () {
      expect(AppIcons.calendar, Icons.calendar_today);
    });
    test('joinEvent collapses login_rounded to login', () {
      expect(AppIcons.joinEvent, Icons.login);
    });
    test('chevronRight resolves to chevron_right', () {
      expect(AppIcons.chevronRight, Icons.chevron_right);
    });
    test('errorCompass resolves to compass_calibration_outlined', () {
      expect(AppIcons.errorCompass, Icons.compass_calibration_outlined);
    });
    test('imageBroken resolves to broken_image', () {
      expect(AppIcons.imageBroken, Icons.broken_image);
    });
  });
}
