import 'package:flutter/material.dart';

/// Centralized icon glyph tokens for CrewPoint.
///
/// Each name describes the *role* (not the glyph), so swapping the underlying
/// `Icons.X` later changes one line. See `ai_specs/constants-and-polish-spec.md`
/// for the normalisation rule + naming convention this file enforces.
///
/// **Normalisation policy** (applies to every variant collision):
/// - Nav unselected → `Icons.X_outlined` / `Icons.X_outline`.
/// - Nav selected → the filled (default) variant of the same family. No
///   `_rounded` variants in nav.
/// - All `_rounded` glyphs in non-nav code collapse to their default variant.
/// - Calendar family collapses to `Icons.calendar_today`.
/// - `add` family: `actionAdd = Icons.add` (no circle);
///   `actionAddCircle = Icons.add_circle_outline` (always outlined).
///
/// **Naming convention** (strict): `nav<Tab>[Filled]`, `status<Name>`,
/// `action<Verb>[Variant]`, `payment<Method>`, `chevron<Direction>`,
/// `<domainNoun>` for general nouns, `<stateNoun>` for error/empty states.
/// One-off decoratives keep a Material-mirror camelCase name.
abstract final class AppIcons {
  // ===== Navigation (bottom bar + rail) =====
  // Unselected = outlined; selected = filled. Rounded variants collapse here.
  static const IconData navHome = Icons.dashboard_outlined;
  static const IconData navHomeFilled = Icons.dashboard;
  static const IconData navTasks = Icons.task_outlined;
  static const IconData navTasksFilled = Icons.task;
  static const IconData navChat =
      Icons.chat_outlined; // chat_rounded collapses here
  static const IconData navChatFilled = Icons.chat;
  static const IconData navBudget = Icons.account_balance_wallet_outlined;
  // account_balance_wallet_rounded collapses to the default filled variant.
  static const IconData navBudgetFilled = Icons.account_balance_wallet;
  static const IconData navProfile = Icons.person_outline;
  static const IconData navProfileFilled = Icons.person;

  // ===== Status (TaskStatus + general "this thing is X") =====
  // Per spec: warning_amber_rounded → warning_amber (drop _rounded).
  static const IconData statusTodo = Icons.radio_button_unchecked;
  static const IconData statusDoing = Icons.play_circle_outline;
  static const IconData statusDoingAlt =
      Icons.timelapse; // used by TaskTile chip
  static const IconData statusDone = Icons.check_circle;
  static const IconData statusDoneOutline = Icons.check_circle_outline;
  static const IconData statusUrgent = Icons.warning_amber; // was _rounded
  static const IconData statusInfo = Icons.info_outline;
  static const IconData statusError = Icons.error_outline;

  // ===== Actions (verbs) =====
  // _rounded collapses to default (logout_rounded → logout, copy_rounded → copy).
  static const IconData actionAdd = Icons.add;
  static const IconData actionAddCircle = Icons.add_circle_outline;
  static const IconData actionEdit = Icons.edit;
  static const IconData actionDelete = Icons.delete;
  static const IconData actionDeletePermanent = Icons.delete_forever;
  static const IconData actionClose = Icons.close;
  static const IconData actionClear = Icons.clear;
  static const IconData actionCopy = Icons.copy;
  static const IconData actionMore = Icons.more_vert;
  static const IconData actionMoreHoriz = Icons.more_horiz;
  static const IconData actionOpenInNew = Icons.open_in_new;
  static const IconData actionRetry = Icons.refresh;
  static const IconData actionSearch = Icons.search;
  static const IconData actionLogout = Icons.logout;
  static final IconData actionShare =
      Icons.adaptive.share; // Automatically adapts to iOS vs Android
  static const IconData actionSend = Icons.send;
  static const IconData actionBack = Icons.arrow_back;
  static const IconData actionSettings = Icons.settings_outlined;
  static const IconData actionSort = Icons.sort;
  static const IconData actionSwap = Icons.swap_horiz; // was _rounded

  // ===== Payment methods (canonical per profile_screen._PaymentCard) =====
  static const IconData paymentVenmo = Icons.payment;
  static const IconData paymentZelle = Icons.account_balance;
  static const IconData paymentCashApp = Icons.attach_money;
  static const IconData paymentPayPal = Icons.paypal_outlined;
  static const IconData paymentCash = Icons.money;
  static const IconData paymentGeneric = Icons.payment_outlined;

  // ===== Chevrons =====
  static const IconData chevronRight = Icons.chevron_right;

  // ===== Auth providers =====
  // Sign-in screen uses the SVG brand marks from `assets/images/auth/`
  // (see social_auth_buttons.dart). These IconData tokens are reserved
  // for secondary surfaces (e.g. delete_account_dialog re-auth prompts)
  // where a plain Material glyph is appropriate.
  static const IconData authGoogle = Icons.account_circle_outlined;
  static const IconData authApple = Icons.apple;
  static const IconData authEmail = Icons.alternate_email;
  static const IconData authEmailField = Icons.email_outlined;
  static const IconData authPassword = Icons.lock_outline;

  // ===== Domain nouns =====
  // Calendar family collapsed: calendar_month / _month_rounded / _today_outlined all → calendar_today.
  static const IconData calendar = Icons.calendar_today;
  static const IconData event = Icons.event;
  static const IconData eventBusy = Icons.event_busy_outlined;
  static const IconData member = Icons.person_outline;
  static const IconData memberAdd = Icons
      .person_add_rounded; // intentional rounded; one of the few rounded retained for visual weight
  static const IconData members = Icons.group_outlined;
  static const IconData notifications = Icons.notifications_none_rounded;
  static const IconData privacy = Icons.privacy_tip_outlined;
  static const IconData privacyPolicy = Icons.policy_outlined;
  static const IconData terms =
      Icons.article_outlined; // closest match to "document/legal" icon
  static const IconData currency = Icons.attach_money;
  static const IconData joinEvent =
      Icons.group_add_outlined; // was login_rounded; collapsed to default
  static const IconData markdown = Icons.description_outlined;
  static const IconData description = Icons.description;
  static const IconData image = Icons.image;
  static const IconData photoLibrary = Icons.photo_library_outlined;
  static const IconData camera = Icons.camera_alt_outlined;
  static const IconData receipt = Icons.receipt;
  static const IconData flag = Icons.flag;
  static const IconData priorityHigh = Icons.priority_high;
  static const IconData hub =
      Icons.hub_rounded; // intentional rounded — feature glyph
  static const IconData shield =
      Icons.shield_rounded; // intentional rounded — feature glyph
  static const IconData extension = Icons.extension_outlined;
  static const IconData inbox = Icons.inbox_outlined;
  static const IconData emailUnread = Icons.mark_email_unread;

  // ===== States (errors, empty placeholders) =====
  static const IconData imageBroken = Icons.broken_image;
  static const IconData errorCompass = Icons.compass_calibration_outlined;
  static const IconData wifiOff =
      Icons.wifi_off_rounded; // was _rounded; keep — single non-nav use
  static const IconData cloudOff = Icons.cloud_off;
  static const IconData blocked =
      Icons.block_rounded; // was _rounded; keep — single non-nav use
  static const IconData lock = Icons.lock_outline;
  static const IconData circleOutlined = Icons.circle_outlined;

  // ===== Decorative one-offs =====
  static const IconData wavingHand =
      Icons.waving_hand_rounded; // used in dashboard greeting
  static const IconData volunteerActivism = Icons.volunteer_activism;
  static const IconData homeOutlined = Icons.home_outlined;
}
