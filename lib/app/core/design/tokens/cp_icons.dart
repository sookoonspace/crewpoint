import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Icon tokens: every glyph the app shows, named by its role, drawn from
/// Lucide (Spec #186, ledger L22).
///
/// This file is the only place that names an icon set, so changing the set
/// is a one-file change (Req 20). Glyphs are constants rather than a theme
/// extension because they never differ between light and dark, and
/// `const Icon(CpIcons.x)` keeps icon tree-shaking working.
///
/// Brand marks Lucide does not draw (Apple sign-in) stay Material.
abstract final class CpIcons {
  // ===== Navigation =====
  // Lucide has no filled variants: the selected tab is marked by the
  // navigation pill, so both names point at the same glyph.
  static const IconData navHome = LucideIcons.calendar;
  static const IconData navHomeFilled = LucideIcons.calendar;
  static const IconData navTasks = LucideIcons.listChecks;
  static const IconData navTasksFilled = LucideIcons.listChecks;
  static const IconData navChat = LucideIcons.messageCircle;
  static const IconData navChatFilled = LucideIcons.messageCircle;
  static const IconData navBudget = LucideIcons.wallet;
  static const IconData navBudgetFilled = LucideIcons.wallet;
  static const IconData navProfile = LucideIcons.user;
  static const IconData navProfileFilled = LucideIcons.user;

  // ===== Status =====
  static const IconData statusTodo = LucideIcons.circle;
  static const IconData statusDoing = LucideIcons.circlePlay;
  static const IconData statusDoingAlt = LucideIcons.clock;
  static const IconData statusDone = LucideIcons.circleCheck;
  static const IconData statusDoneOutline = LucideIcons.circleCheck;
  static const IconData statusDue = LucideIcons.clock;
  static const IconData statusOverdue = LucideIcons.circleAlert;
  static const IconData statusUrgent = LucideIcons.triangleAlert;
  static const IconData statusInfo = LucideIcons.info;
  static const IconData statusError = LucideIcons.circleAlert;

  // ===== Actions =====
  static const IconData actionAdd = LucideIcons.plus;
  static const IconData actionAddCircle = LucideIcons.circlePlus;
  static const IconData actionEdit = LucideIcons.pencil;
  static const IconData actionDelete = LucideIcons.trash2;
  static const IconData actionDeletePermanent = LucideIcons.trash2;
  static const IconData actionClose = LucideIcons.x;
  static const IconData actionClear = LucideIcons.x;
  static const IconData actionCopy = LucideIcons.copy;
  static const IconData actionMore = LucideIcons.ellipsisVertical;
  static const IconData actionMoreHoriz = LucideIcons.ellipsis;
  static const IconData actionOpenInNew = LucideIcons.externalLink;
  static const IconData actionRetry = LucideIcons.refreshCw;
  static const IconData appUpdate = LucideIcons.download;
  static const IconData actionSearch = LucideIcons.search;
  static const IconData filter = LucideIcons.listFilter;
  static const IconData importFile = LucideIcons.fileUp;
  static const IconData actionLogout = LucideIcons.logOut;
  static const IconData actionShare = LucideIcons.share;
  static const IconData actionSend = LucideIcons.send;
  static const IconData actionBack = LucideIcons.arrowLeft;
  static const IconData actionSettings = LucideIcons.settings;
  static const IconData actionSort = LucideIcons.arrowUpDown;
  static const IconData actionSwap = LucideIcons.arrowLeftRight;
  static const IconData actionMute = LucideIcons.bellOff;
  static const IconData actionUnmute = LucideIcons.bellRing;

  // Mute lengths.
  static const IconData muteHour = LucideIcons.timer;
  static const IconData muteNight = LucideIcons.moon;
  static const IconData muteDay = LucideIcons.calendarDays;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData check = LucideIcons.check;

  // ===== Payment methods =====
  static const IconData paymentVenmo = LucideIcons.creditCard;
  static const IconData paymentZelle = LucideIcons.landmark;
  static const IconData paymentCashApp = LucideIcons.dollarSign;
  static const IconData paymentPayPal = LucideIcons.circleDollarSign;
  static const IconData paymentCash = LucideIcons.banknote;
  static const IconData paymentGeneric = LucideIcons.creditCard;

  // ===== Sign-in =====
  static const IconData authGoogle = LucideIcons.circleUser;
  static const IconData authApple = Icons.apple;
  static const IconData authEmail = LucideIcons.atSign;
  static const IconData authEmailField = LucideIcons.mail;
  static const IconData authPassword = LucideIcons.lock;

  // ===== Event templates =====
  // Named by the template file's `icon`, never by the kind of event.
  static const IconData templateAdd = LucideIcons.plus;
  static const IconData templateCelebration = LucideIcons.partyPopper;
  static const IconData templateHeart = LucideIcons.heart;
  static const IconData templateBat = LucideIcons.trophy;
  static const IconData templateFlag = LucideIcons.flag;
  static const IconData templateGroups = LucideIcons.usersRound;

  // ===== Older event types (display text only since #65) =====
  static const IconData eventTrip = LucideIcons.luggage;
  static const IconData eventProject = LucideIcons.clipboardList;
  static const IconData eventSocial = LucideIcons.usersRound;

  // ===== Things =====
  static const IconData calendar = LucideIcons.calendar;
  static const IconData event = LucideIcons.calendarDays;
  static const IconData schedule = LucideIcons.clock;
  static const IconData agenda = LucideIcons.calendarDays;
  static const IconData counts = LucideIcons.chartColumn;
  static const IconData budget = LucideIcons.wallet;
  static const IconData chat = LucideIcons.messageCircle;
  static const IconData tasks = LucideIcons.listChecks;
  static const IconData place = LucideIcons.mapPin;
  static const IconData map = LucideIcons.map;
  static const IconData directions = LucideIcons.navigation;
  static const IconData hidden = LucideIcons.eyeOff;
  static const IconData eventBusy = LucideIcons.calendarX;
  static const IconData member = LucideIcons.user;
  static const IconData memberAdd = LucideIcons.userPlus;

  /// Owning an event, such as an ownership offer.
  static const IconData owner = LucideIcons.crown;
  static const IconData members = LucideIcons.users;
  static const IconData notifications = LucideIcons.bell;
  static const IconData privacy = LucideIcons.shieldCheck;
  static const IconData privacyPolicy = LucideIcons.scrollText;

  /// Light, dark or the device's appearance.
  static const IconData theme = LucideIcons.sunMoon;

  /// The dev flavor's diagnostic tools.
  static const IconData devTools = LucideIcons.wrench;
  static const IconData terms = LucideIcons.fileText;
  static const IconData currency = LucideIcons.dollarSign;
  static const IconData joinEvent = LucideIcons.userRoundPlus;
  static const IconData markdown = LucideIcons.fileText;
  static const IconData description = LucideIcons.fileText;
  static const IconData image = LucideIcons.image;
  static const IconData photoLibrary = LucideIcons.images;
  static const IconData camera = LucideIcons.camera;
  static const IconData receipt = LucideIcons.receipt;
  static const IconData flag = LucideIcons.flag;
  static const IconData priorityHigh = LucideIcons.circleAlert;
  static const IconData hub = LucideIcons.network;
  static const IconData shield = LucideIcons.shield;
  static const IconData extension = LucideIcons.puzzle;
  static const IconData inbox = LucideIcons.inbox;
  static const IconData emailUnread = LucideIcons.mail;
  static const IconData lock = LucideIcons.lock;

  // ===== States =====
  static const IconData imageBroken = LucideIcons.imageOff;
  static const IconData errorCompass = LucideIcons.compass;
  static const IconData wifiOff = LucideIcons.wifiOff;
  static const IconData cloudOff = LucideIcons.cloudOff;
  static const IconData blocked = LucideIcons.ban;
  static const IconData circleOutlined = LucideIcons.circle;

  /// A choice among several, chosen or not.
  static const IconData radioOn = LucideIcons.circleDot;
  static const IconData radioOff = LucideIcons.circle;

  // ===== Decorative =====
  static const IconData wavingHand = LucideIcons.hand;
  static const IconData volunteerActivism = LucideIcons.handHeart;
  static const IconData homeOutlined = LucideIcons.house;
}
