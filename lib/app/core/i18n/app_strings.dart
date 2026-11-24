import 'package:crewpoint_app/app/features/dashboard/domain/models/expense_access.dart';
import 'package:flutter/widgets.dart';
import 'package:crewpoint_app/l10n/gen/app_localizations.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';

/// User-facing string surface for CrewPoint.
///
/// `context.strings` returns the strings for the app's language (English or
/// Gujarati, Spec #233 Req 55). Groups move to the gen-l10n ARB files
/// (`lib/l10n/app_en.arb`, `app_gu.arb`) as they are translated: an
/// ARB-backed group reads `AppLocalizations`, and every other group is still
/// the hand-written English below, which is what Gujarati shows until that
/// group is translated (Req 57). Call sites never change.
///
/// To translate a group: add its keys to both ARB files, implement the group
/// over `AppLocalizations` (as `_ArbLanguageStrings` does), and return it
/// from `_EnglishStrings` and `_LocalizedStrings`. A key that may stay
/// English goes in `lib/l10n/english_only.json` with a reason.
abstract class AppStrings {
  const AppStrings();

  AuthStrings get auth;
  ErrorStrings get errors;
  TasksStrings get tasks;
  DashboardStrings get dashboard;
  ChatStrings get chat;
  BudgetStrings get budget;
  ProfileStrings get profile;
  NavStrings get nav;
  UpdateStrings get update;
  RoleStrings get roles;
  CrewStrings get crews;
  TransferStrings get transfer;
  ExpenseAccessStrings get expenseAccess;
  PeopleStrings get people;
  GroupEntryStrings get groupEntry;
  CoverStrings get cover;
  EventHomeStrings get eventHome;
  FieldStrings get fields;
  ImportStrings get imports;
  LinkStrings get links;
  InviteStrings get invites;
  RegistrationSettingsStrings get registrationSettings;
  MemberPickerStrings get memberPicker;
  ScheduleStrings get schedule;
  AgendaStrings get agenda;
  CountsStrings get counts;
  TemplateStrings get templates;
  PrivacyStrings get privacy;
  OnboardingStrings get onboarding;
  DevStrings get dev;
  LanguageStrings get language;

  /// Static English fallback. Used by service-layer code that has no
  /// `BuildContext` in scope (e.g. `firebaseAuthErrorMessage`). UI code
  /// should always prefer `context.strings.<feature>.<key>` because
  /// that path will pick up the active locale once ARB is wired.
  static const AppStrings fallbackEnglish = _EnglishStrings();
}

abstract class AuthStrings {
  const AuthStrings();

  // Hero / layout
  String get heroTitle;
  String get tagline;
  String get dividerLabel;

  // Social auth
  String get continueWithGoogle;
  String get continueWithApple;

  // Email form
  String get emailHint;
  String get passwordHint;
  String get fullNameHint;
  String get signIn;
  String get createAccount;
  String get toggleToSignIn;
  String get toggleToSignUp;

  // Validators
  String get validatorEmailRequired;
  String get validatorEmailInvalid;
  String get validatorPasswordTooShort;
  String get validatorNameRequired;

  // Suggest-provider snackbar (templated)
  String suggestProvider(String providerLabel);

  // Email-verification banner
  String get verifyBannerTitle;
  String verifyBannerBody(String email);
  String get verifyBannerResend;
  String get verifyBannerRefresh;

  // Auth-gate legal footer
  String get legalFooterPrefix; // e.g. "By continuing, you agree to our "
  String get legalFooterTermsLink; // e.g. "Terms"
  String get legalFooterAnd; // e.g. " and "
  String get legalFooterPrivacyLink; // e.g. "Privacy Policy"
  String get legalFooterSuffix; // e.g. "."

  /// Stands in for a sign-in provider the app has no name for.
  String get existingProvider;
}

/// User-facing strings for the Tasks feature.
///
/// Phase 1 seeds the class with the labels the form-kit foundation needs;
/// later phases extend it with filter chip labels, sort/group menu labels,
/// priority pill labels, empty-state copy, and the `(copy)` suffix. All new
/// task-screen literals MUST land here rather than being hardcoded in
/// widgets — see `ai_specs/tasks-ux-overhaul-spec.md` `<boundaries>` i18n
/// contract.
abstract class TasksStrings {
  const TasksStrings();

  // Form section headers (used by Create / Edit task screens).
  String get sectionDetails;
  String get sectionAssignment;
  String get sectionTimingAndBudget;

  // Tile pills.
  String get overdueBadge;
  String get priorityNone;
  String get priorityLow;
  String get priorityMedium;
  String get priorityHigh;

  // Tasks-screen filter bar.
  String get searchHint;
  String get sortBy;
  String get groupBy;
  String get clearFilters;

  // Filter chips.
  String get filterChipMine;
  String get filterChipOverdue;
  String get filterChipHasBudget;

  // Status labels (filter chips + status grouping headers).
  String get statusTodo;
  String get statusInProgress;
  String get statusDone;

  // Sort menu items.
  String get sortDueDate;
  String get sortPriority;
  String get sortCreated;
  String get sortTitle;

  // Group toggle items.
  String get groupStatus;
  String get groupAssignee;
  String get groupDueWindow;

  // Due-window group headers.
  String get dueWindowToday;
  String get dueWindowThisWeek;
  String get dueWindowLater;
  String get dueWindowNoDueDate;

  // Assignee group fallback.
  String get assigneeUnassigned;

  // Empty states.
  String get emptyNoTasksYet;
  String get emptyNoTasksHelp;
  String get emptyNoMatch;

  // Cross-event "My Tasks" tab.
  String get myTasksAppBarTitle;
  String get myTasksEmptyTitle;
  String get myTasksEmptySubtitle;
  String get myTasksEmptySubtitleNoEvents;
  String get openDashboardCta;
  String get createFromDashboardCta;
  String get signInRequiredTitle;

  // Detail screen overflow menu.
  String get detailEdit;
  String get detailDuplicate;
  String get detailDelete;

  // Form labels.
  String get fieldPriority;

  // Event-scoped tasks screen (TaskListScreen).
  String get tasksAppBarTitle;
  String get exportPdfTooltip;

  // Create / Edit task screens.
  String get createTaskTitle;
  String get editTaskTitle;
  String get taskTitleHint;
  String get descriptionOptionalHint;
  String get dueDateLabel;
  String get budgetEstimateLabel;
  String get createTaskCta;
  String get saveChangesCta;

  // Checklist editor.
  String get checklistAddHint;
  String checklistHeading(int count, int max);
  String get checklistAdd;
  String get checklistRemove;

  // Tasks in the new look (Spec #186, #201).
  String get filterAll;
  String doneOf(int done, int total);
  String progressDetail(int overdue, int dueThisWeek);
  String dueOn(String day);
  String overdueOn(String day);
  String get dueToday;
  String get sortTooltip;
  String get createFailed;
  String get statusFailed;
  String get statusNotAllowed;
  String get exportFailed;
  String get saveFailed;
  String get duplicateFailed;
  String get loadFailed;
  String get notFound;
  String get taskWord;
  String get deleteTitle;
  String get deleteBody;
  String get cancel;
  String get statusLabel;
  String get assigneeLabel;
  String get dueLabel;
  String get budgetLabel;
  String completedOn(String date, String? by);
  String get unknownMember;
  String get noLongerInEvent;
  String get willSync;
  String get titleLabel;
  String get descriptionLabel;
  String get titleRequired;
  String titleTooLong(int max);
  String get clearDueDate;
  String get myTasksNoMatches;
  String overdueCount(int count);
  String get statusChange;
  String get budgetInvalid;
}

/// User-facing strings for the Dashboard feature (events list + empty state).
abstract class DashboardStrings {
  const DashboardStrings();

  /// Shown when someone loses access to an event they had open (#66).
  String lostAccess(String eventTitle);

  String get noEventsTitle;
  String get noEventsSubtitle;
  String get joinWithCode;

  // Header / hero greeting.
  String get greetingMorning;
  String get greetingAfternoon;
  String get greetingEvening;
  String get joinEventTooltip;

  // Filter pills (segmented bar).
  String get filterUpcoming;
  String get filterPast;

  // CTA + list section headers.
  String get createEventCta;
  String get createEventNeedsConnection;
  String get createEventRetry;
  String leaveEventBalanceWarning(String amount);
  String upcomingEventsHeader(int count);
  String pastEventsHeader(int count);

  // Event status.
  String get statusDraft;
  String get statusPublished;
  String get statusLive;
  String get statusEnded;
  String get statusArchived;
  String get draftCreated;
  String get publishAndInvite;
  String get publishEvent;
  String get publishEventSubtitle;
  String get publishFailed;
  String get notOpenToInvites;
  String get notOpenToJoin;
  String get settingsStatus;
  String get settingsStatusDraftUnavailable;
  String get settingsArchivedNotice;

  String inviteLabel(String membersWord);

  // Event hub and modules.
  String get moduleChat;
  String get moduleChatSubtitle;
  String get moduleBudget;
  String get moduleBudgetSubtitle;
  String get moduleTasks;
  String get moduleTasksSubtitle;
  String get hubEmpty;
  String get moduleOff;
  String get settingsModules;
  String get settingsModulesHelp;

  // Event settings.
  String get settingsLabels;
  String get settingsLabelsHelp;
  String settingsLabelOne(String defaultWord);
  String settingsLabelOther(String defaultWord);
  String get settingsTitle;
  String get settingsNoAccess;
  String get settingsBack;
  String get settingsTimeZone;
  String get settingsTimeZoneHelp;
  String get settingsTimeZoneSearch;
  String get settingsTimeZoneNone;
  String get settingsVenues;
  String get settingsVenuesEmpty;
  String get settingsVenueName;
  String get settingsVenueNameRequired;
  String get settingsVenueAddress;
  String get settingsVenueAdd;
  String get settingsVenueRemove;
  String get settingsCurrency;
  String get settingsCurrencyHelp;
  String get settingsCurrencyLocked;
  String get settingsLanguages;
  String get settingsLanguagesHelp;
  String get settingsLanguagesInvalid;
  String get settingsCapacity;
  String settingsCapacityCount(int count, int? capacity);
  String get settingsMemberLimit;
  String get settingsMemberLimitHelp;
  String get settingsWholeNumber;
  String get settingsSave;
  String get settingsSaved;
  String get settingsPending;
  String get settingsNeedsConnection;
  String get settingsFailed;
  String get settingsDiscardTitle;
  String get settingsDiscardBody;
  String get settingsDiscard;
  String get settingsKeepEditing;

  // Error state.
  String get errorLoading;
  String get retryCta;

  // The join and mute sheets in the new look (Spec #186, #206).
  String get joinSheetTitle;
  String get joinSheetHelp;
  String get joinCodeLabel;
  String get joinCodeLength;
  String get joined;
  String get joinCodeInvalid;
  String get joinAlreadyMember;
  String get joinFull;
  String get joinFailed;
  String get joinOffline;
  String get muteTitle;
  String get mutedTitle;
  String get muteHelp;
  String mutedUntil(String when);
  String get unmute;
  String get muteHour;
  String get muteEightHours;
  String get muteDay;
  String get muteUntilUnmute;

  // Event settings section headings (Spec #186, #206).
  String get settingsEventHeading;
  String get settingsAttendanceHeading;
  String get settingsMoreHeading;
}

/// User-facing strings for the cross-event Chat tab — the Global Inbox.
abstract class ChatStrings {
  const ChatStrings();

  String get readOnlyNotice;

  // Older messages (Req 57).
  String get olderLoad;
  String get olderFailed;
  String get olderRetry;
  String get olderNeedsConnection;
  String get olderNone;

  // Global inbox surface.
  String get inboxAppBarTitle;
  String get inboxEmptyTitle;
  String get inboxEmptySubtitle;
  String get inboxEmptyNoEventsSubtitle;
  String get inboxErrorTitle;

  /// Semantics label for the urgent-badge surface — spoken by screen
  /// readers when the row carries the terracotta-highlighted badge.
  String get inboxUrgentBadgeLabel;

  /// Templated last-message prefix used in inbox rows. When the message's
  /// sender is the current user, `senderName` should be "You".
  String inboxLastMessagePrefix({
    required String senderName,
    required String text,
  });

  // Event-scoped chat screen (ChatScreen).
  String get chatAppBarTitle;
  String get chatEmptyMessage;
  String get messageInputHint;
  String get sendFailedHint;

  /// Rendered as a small terracotta pill on rows marked critical/urgent.
  String get urgentBadge;

  /// Shown to the sender on an urgent message that alerted nobody.
  String get urgentLimitReached;

  /// Shown instead of the dispute option once the window has closed.
  String disputeWindowClosed(int days);

  // Chat in the new look (Spec #186, #205).
  String get signInRequired;
  String get retry;
  String get send;
  String get you;
  String get timeNow;
  String minutesAgo(int minutes);
  String hoursAgo(int hours);
  String get yesterday;
  String daysAgo(int days);
  String unreadCount(int count);

  /// Above an urgent message, beside its icon.
  String get urgentLabel;
  String get urgentTitle;
  List<String> get urgentPresets;
  String get urgentCustomLabel;
  String get urgentCustomHint;
  String get urgentSend;

  /// Above a settlement message, and the dispute sheet's title.
  String get settlementLabel;
  String get settlementFallback;
  String get settlementTapHint;
  String get disputeKeep;
  String get disputeConfirm;
  String get disputeExplain;
  String get disputed;
  String get disputeFailed;
}

/// User-facing strings for the cross-event Budget tab — the Financial Ledger.
abstract class BudgetStrings {
  const BudgetStrings();

  /// Above the balance card in a large event (Req 43a).
  String largestShown(int count);

  // Saving an expense.
  String get expenseNeedsConnection;
  String get expenseSaveRejected;
  String get expenseRetry;
  String get settlementNeedsConnection;
  String get settlementRejected;
  String get settleOnBehalfTitle;
  String settleOnBehalfBody(String amount, String from, String to);
  String get settleOnBehalfConfirm;
  String get settleOnBehalfCancel;
  String get settleOnBehalfNeedsOrganizer;

  // Ledger surface.
  String get ledgerAppBarTitle;
  String get ledgerHeroOwedToYouLabel;
  String get ledgerHeroYouOweLabel;
  String get ledgerDebtsHeader;
  String get ledgerRecentExpensesHeader;
  String get ledgerEmptyTitle;
  String get ledgerEmptyNoEventsSubtitle;
  String get ledgerEmptySubtitle;
  String get ledgerErrorTitle;
  String get multiCurrencyDisclaimer;

  // Settle Up surface (Phase 4).
  String get ledgerSettleUpCta;
  String settleUpFallbackTitle(String recipientName);
  String get settleUpFallbackCopyAmount;
  String get settleUpFallbackCopyHandle;
  String get settleUpFallbackMarkPaid;
  String get settleUpContactLoadError;

  /// Uppercase labels used by `BalanceTile` (same copy as ledgerHero*).
  String get balanceTileYouAreOwedLabel;
  String get balanceTileYouOweLabel;

  // Budget in the new look (Spec #186, #202).
  String get title;
  String get signInRequired;
  String get loadFailed;
  String get spentLabel;
  String expenseCount(int count);
  String get yourBalanceLabel;
  String youAreOwed(String amount);
  String youOwe(String amount);
  String get allSettled;
  String owesYou(String name, String amount);
  String youOweName(String name, String amount);
  String get settleUp;
  String get settle;
  String get balancesHeading;
  String get settleUpHeading;
  String get expensesHeading;
  String get isOwed;
  String get owes;
  String get settled;
  String pays(String from, String to);
  String paid(String from, String to);
  String get settlementLabel;
  String get paidChip;
  String paidBy(String name);
  String get you;
  String get youCapital;
  String splitWays(int count);
  String get donated;
  String get expenseFallback;
  String get expenseWord;
  String get noExpenses;
  String get noExpensesHelp;
  String get exportTooltip;
  String get exportPdf;
  String get exportCsv;
  String get exportFailed;
  String get addExpenseTitle;
  String get editExpenseTitle;
  String get addExpenseCta;
  String get saveChangesCta;
  String get amountLabel;
  String get descriptionLabel;
  String get descriptionHint;
  String get donateLabel;
  String get donateHelp;
  String perPerson(String amount, int count);
  String get addReceipt;
  String get receiptAttached;
  String get removeReceipt;
  String get receiptLabel;
  String get viewReceipt;
  String get deleteTitle;
  String get deleteBody;
  String get cancel;
  String get delete;
  String get edit;
  String get deleteFailed;
  String get receiptUploadFailed;
  String get invalidHandle;
  String get copiedDetails;
  String copyDetailsText(String amount, String to, String event);
  String get confirmSentTitle;
  String confirmSentBody(String amount);
  String get notYet;
  String get yesRecorded;
  String get notFound;
  String get paidByLabel;
  String get dateLabel;
  String get splitLabel;
  String eachShare(String amount);
  String sheetPays(String from, String to);
  String get them;
  String get payWithVenmo;
  String get noVenmo;
  String get payWithCashApp;
  String get noCashApp;
  String get copyPaymentDetails;
  String someonePaid(String name);
}

/// User-facing strings for the Profile feature (profile screen + settings).
abstract class ProfileStrings {
  const ProfileStrings();

  // Hero card.
  String get heroTitle;
  String get heroUserFallback;
  String get editProfileCta;

  // Stat triplet.
  String get statsEvents;
  String get statsTasks;
  String get statsOwed;

  // Section headers + rows.
  String get settingsSection;
  String get paymentSection;
  String get notifications;
  String get privacyDashboard;
  String get signOut;
  String get deleteAccount;

  /// The dev flavor's diagnostic console.
  String get devTools;

  // Edit profile.
  String get editTitle;
  String get changePhoto;
  String get photoGallery;
  String get photoCamera;
  String get nameLabel;
  String get nameHint;
  String get nameRequired;
  String get paymentHeading;
  String get paymentHelp;
  String get paymentMethodLabel;
  String get paymentMethodPlaceholder;
  String get paymentHandleLabel;
  String get paymentHandleHint;
  String get settleHeading;
  String get settleHelp;
  String get venmoHandleLabel;
  String get cashappHandleLabel;
  String get handleInvalid;
  String get save;
  String get saved;
  String get saveDenied;
  String get saveOffline;
  String get saveFailed;

  // Notification settings.
  String get signInRequired;
  String get notifLoadFailed;
  String get retry;
  String get notifPush;
  String get notifPushOn;
  String get notifPushOff;
  String get notifCategories;
  String get notifUrgent;
  String get notifUrgentHelp;
  String get notifTasks;
  String get notifTasksHelp;
  String get notifPayments;
  String get notifPaymentsHelp;
  String get notifEvents;
  String get notifEventsHelp;
  String get notifQuiet;
  String get notifQuietOff;
  String notifQuietOn({
    required String start,
    required String end,
    required String zone,
  });
  String get notifQuietStart;
  String get notifQuietEnd;
  String get notifDigest;
  String get notifDigestHelp;
  String get notifSaveFailed;

  // Sign-out sheet.
  String get signOutTitle;
  String get signOutBody;
  String get cancel;

  // Delete-account dialog.
  String get deleteTitle;
  String get deleteConfirmTitle;
  String get deleteContinue;
  String get deleteForever;
  String get deleteWarning;
  String get deletePasswordPrompt;
  String get deletePasswordLabel;
  String get deleteReauthPrompt;
  String get deleteReauthGoogle;
  String get deleteReauthApple;
  String get deleteUnknownProvider;
  String get deleting;
  String get deleteWrongPassword;
  String get deleteAuthFailed;
  String get deleteFailed;

  // Theme switcher (Settings row + sheet).
  String get themeRowTitle;
  String get themeModeSystem;
  String get themeModeLight;
  String get themeModeDark;
  String get themeModeSystemSubtitle;

  // Payment card.
  String get addPaymentMethod;
  String get addPaymentMethodSubtitle;
  String get paymentMethodVenmo;
  String get paymentMethodZelle;
  String get paymentMethodCashApp;
  String get paymentMethodPayPal;
  String get paymentMethodCash;
  String get paymentMethodOther;
  String get paymentMethodGeneric;

  // Version footer (e.g. "CrewPoint v1.2.3 (45)").
  String appVersionLabel({required String version, required String build});
}

/// User-facing strings for the bottom navigation / responsive shell.
abstract class NavStrings {
  const NavStrings();

  String get home;
  String get tasks;
  String get chat;
  String get budget;
  String get profile;
  String get signOutTooltip;

  /// The product name beside the logo in the sidebar.
  String get appName;

  /// The empty detail panel of a list and detail layout (Spec #186
  /// Req 23); [thing] is the event's word, such as a participant.
  String selectToSee(String thing);

  // A link to a page or event that is not there.
  String get pageNotFoundTitle;
  String get pageNotFoundBody;
  String triedLocation(String location);
  String get goHome;
  String get eventNotFoundTitle;
  String get eventNotFoundBody;
  String get backToEvents;
  String get eventSaveFailed;

  /// Read by screen readers while a screen loads.
  String get loading;

  // A push notification shown while the app is open.
  String get bannerView;
  String get bannerDismiss;
}

abstract class ErrorStrings {
  const ErrorStrings();

  String get invalidEmail;
  String get wrongPassword;
  String get userNotFound;
  String get emailAlreadyInUse;
  String get weakPassword;
  String get networkRequestFailed;
  String get popupBlocked;
  String get popupCancelled;
  String get tooManyRequests;
  String get permissionDenied;
  String get genericFallback;
}

/// Read translated strings from the current locale via `BuildContext`.
///
/// Today returns the English fallback singleton. The future ARB
/// migration replaces ONLY this getter's body — call sites stay
/// identical.
extension StringsX on BuildContext {
  /// The strings for the nearest `Localizations` (the app's language), or
  /// English where there is none, such as a bare widget test.
  ///
  /// This reads the language without subscribing to it, so it is safe from
  /// `initState` and before an `await`, as many screens use it.
  /// `AppLanguageRebuilder` rebuilds the whole tree when the language
  /// changes, so every screen still shows the new language.
  AppStrings get strings {
    final locale = findAncestorWidgetOfExactType<Localizations>()?.locale;
    if (locale == null || !AppLocalizations.delegate.isSupported(locale)) {
      return AppStrings.fallbackEnglish;
    }
    return _byLanguage[locale.languageCode] ??= _LocalizedStrings(
      lookupAppLocalizations(locale),
    );
  }
}

final _byLanguage = <String, AppStrings>{};

/// The app's strings in one language: ARB-backed groups from [_l], every
/// other group in English.
class _LocalizedStrings extends _EnglishStrings {
  _LocalizedStrings(this._l);

  final AppLocalizations _l;

  @override
  LanguageStrings get language => _ArbLanguageStrings(_l);

  @override
  InviteStrings get invites => _ArbInviteStrings(_l);

  @override
  RegistrationSettingsStrings get registrationSettings =>
      RegistrationSettingsStrings(_l);
}

/// The language choice (Req 56).
abstract class LanguageStrings {
  const LanguageStrings();

  String get title;
  String get hint;
  String get english;
  String get gujarati;
}

class _ArbLanguageStrings extends LanguageStrings {
  const _ArbLanguageStrings(this._l);

  final AppLocalizations _l;

  @override
  String get title => _l.languageTitle;
  @override
  String get hint => _l.languageHint;
  @override
  String get english => _l.languageEnglish;
  @override
  String get gujarati => _l.languageGujarati;
}

class _EnglishStrings extends AppStrings {
  const _EnglishStrings();

  @override
  LanguageStrings get language =>
      _ArbLanguageStrings(lookupAppLocalizations(const Locale('en')));

  @override
  AuthStrings get auth => const _EnglishAuthStrings();

  @override
  ErrorStrings get errors => const _EnglishErrorStrings();

  @override
  UpdateStrings get update => const _EnglishUpdateStrings();

  @override
  TasksStrings get tasks => const _EnglishTasksStrings();

  @override
  DashboardStrings get dashboard => const _EnglishDashboardStrings();

  @override
  ChatStrings get chat => const _EnglishChatStrings();

  @override
  BudgetStrings get budget => const _EnglishBudgetStrings();

  @override
  ProfileStrings get profile => const _EnglishProfileStrings();

  @override
  NavStrings get nav => const _EnglishNavStrings();

  @override
  RoleStrings get roles => const _EnglishRoleStrings();

  @override
  CrewStrings get crews => const _EnglishCrewStrings();

  @override
  TransferStrings get transfer => const _EnglishTransferStrings();

  @override
  ExpenseAccessStrings get expenseAccess =>
      const _EnglishExpenseAccessStrings();

  @override
  PeopleStrings get people => const _EnglishPeopleStrings();
  @override
  GroupEntryStrings get groupEntry => const _EnglishGroupEntryStrings();
  @override
  CoverStrings get cover => const _EnglishCoverStrings();
  @override
  EventHomeStrings get eventHome => const _EnglishEventHomeStrings();

  @override
  FieldStrings get fields => const _EnglishFieldStrings();

  @override
  ImportStrings get imports => const _EnglishImportStrings();

  @override
  LinkStrings get links => const _EnglishLinkStrings();

  @override
  InviteStrings get invites =>
      _ArbInviteStrings(lookupAppLocalizations(const Locale('en')));

  @override
  RegistrationSettingsStrings get registrationSettings =>
      RegistrationSettingsStrings(lookupAppLocalizations(const Locale('en')));

  @override
  MemberPickerStrings get memberPicker => const _EnglishMemberPickerStrings();
  @override
  ScheduleStrings get schedule => const _EnglishScheduleStrings();
  @override
  AgendaStrings get agenda => const _EnglishAgendaStrings();
  @override
  CountsStrings get counts => const _EnglishCountsStrings();
  @override
  TemplateStrings get templates => const _EnglishTemplateStrings();

  @override
  PrivacyStrings get privacy => const _EnglishPrivacyStrings();

  @override
  OnboardingStrings get onboarding => const _EnglishOnboardingStrings();

  @override
  DevStrings get dev => const _EnglishDevStrings();
}

class _EnglishChatStrings extends ChatStrings {
  const _EnglishChatStrings();

  @override
  String get olderLoad => 'Show earlier messages';
  @override
  String get olderFailed => "Couldn't load earlier messages.";
  @override
  String get olderRetry => 'Try again';
  @override
  String get olderNeedsConnection =>
      'Earlier messages need a connection. Showing the latest saved on this device.';
  @override
  String get olderNone => 'This is the start of the chat.';

  @override
  String get readOnlyNotice => 'This event is archived, so chat is read-only.';

  @override
  String get inboxAppBarTitle => 'Chat';

  @override
  String get inboxEmptyTitle => 'No messages yet';

  @override
  String get inboxEmptySubtitle =>
      'Open an event from the Dashboard to start chatting.';

  @override
  String get inboxEmptyNoEventsSubtitle =>
      'Create or join an event to chat with your crew.';

  @override
  String get inboxErrorTitle => 'Could not load your inbox';

  @override
  String get inboxUrgentBadgeLabel => 'Urgent unread';

  @override
  String inboxLastMessagePrefix({
    required String senderName,
    required String text,
  }) => '$senderName: $text';

  @override
  String get chatAppBarTitle => 'Chat';

  @override
  String get chatEmptyMessage =>
      'No messages yet — be the first to say something.';

  @override
  String get messageInputHint => 'Type a message...';

  @override
  String get sendFailedHint => 'Send failed — tap Send again to retry';

  @override
  String get urgentBadge => 'Urgent';

  @override
  String disputeWindowClosed(int days) =>
      'This settlement can no longer be disputed, because more than $days days '
      'have passed.';

  @override
  String get urgentLimitReached =>
      'Saved, but nobody was alerted: you have reached the limit for urgent '
      'messages. Try again later.';

  @override
  String get signInRequired => 'Sign in to read this chat';
  @override
  String get retry => 'Try again';
  @override
  String get send => 'Send';
  @override
  String get you => 'You';
  @override
  String get timeNow => 'now';
  @override
  String minutesAgo(int minutes) => '${minutes}m';
  @override
  String hoursAgo(int hours) => '${hours}h';
  @override
  String get yesterday => 'Yesterday';
  @override
  String daysAgo(int days) => '${days}d';
  @override
  String unreadCount(int count) => '$count unread';

  @override
  String get urgentLabel => 'Urgent';
  @override
  String get urgentTitle => 'Send an urgent alert';
  @override
  List<String> get urgentPresets => const [
    'Emergency - Everyone stop and check in',
    'Meeting point changed - Check details',
    'Weather alert - Take shelter',
    'Schedule changed - Check new times',
  ];
  @override
  String get urgentCustomLabel => 'Or write your own';
  @override
  String get urgentCustomHint => 'Type an alert';
  @override
  String get urgentSend => 'Send alert';

  @override
  String get settlementLabel => 'Settlement';
  @override
  String get settlementFallback => 'Settlement record';
  @override
  String get settlementTapHint => 'Confirm or dispute';
  @override
  String get disputeKeep => 'All good, keep it';
  @override
  String get disputeConfirm => 'Dispute this settlement';
  @override
  String get disputeExplain =>
      'Disputing removes this settlement and restores the balance.';
  @override
  String get disputed => 'Settlement disputed';
  @override
  String get disputeFailed => "Couldn't dispute the settlement. Try again.";
}

class _EnglishBudgetStrings extends BudgetStrings {
  const _EnglishBudgetStrings();

  @override
  String largestShown(int count) =>
      'Showing your balance and the $count largest.';

  @override
  String get expenseNeedsConnection =>
      'Saving an expense needs a connection. Check yours and try again.';

  @override
  String get expenseSaveRejected =>
      'This expense could not be saved. Check the details and try again.';

  @override
  String get expenseRetry => 'Retry';

  @override
  String get settlementNeedsConnection =>
      'Recording a payment needs a connection. Check yours and try again.';

  @override
  String get settlementRejected => 'This payment could not be recorded.';

  @override
  String get settleOnBehalfTitle => 'Record this payment?';

  @override
  String settleOnBehalfBody(String amount, String from, String to) =>
      'This records that $from paid $to $amount. One of them has left the '
      'event, so nothing is sent to a payment app.';

  @override
  String get settleOnBehalfConfirm => 'Record payment';

  @override
  String get settleOnBehalfCancel => 'Cancel';

  @override
  String get settleOnBehalfNeedsOrganizer =>
      'This person has left the event, so an organizer needs to record this '
      'payment.';

  @override
  String get ledgerAppBarTitle => 'Budget';

  @override
  String get ledgerHeroOwedToYouLabel => 'You are owed';

  @override
  String get ledgerHeroYouOweLabel => 'You owe';

  @override
  String get ledgerDebtsHeader => 'Settle up';

  @override
  String get ledgerRecentExpensesHeader => 'Recent expenses';

  @override
  String get ledgerEmptyTitle => 'No balances yet';

  @override
  String get ledgerEmptyNoEventsSubtitle =>
      'Create an event from the Dashboard to start tracking expenses.';

  @override
  String get ledgerEmptySubtitle =>
      'Open an event from the Dashboard to log an expense.';

  @override
  String get ledgerErrorTitle => 'Could not load your ledger';

  @override
  String get multiCurrencyDisclaimer =>
      'Totals are approximate when events use different currencies.';

  @override
  String get ledgerSettleUpCta => 'Settle Up';

  @override
  String settleUpFallbackTitle(String recipientName) => 'Pay $recipientName';

  @override
  String get settleUpFallbackCopyAmount => 'Copy amount';

  @override
  String get settleUpFallbackCopyHandle => 'Copy handle';

  @override
  String get settleUpFallbackMarkPaid => 'Mark paid in event budget';

  @override
  String get settleUpContactLoadError => 'Could not load contact info';

  @override
  String get balanceTileYouAreOwedLabel => 'You are owed';

  @override
  String get balanceTileYouOweLabel => 'You owe';

  @override
  String get title => 'Budget';
  @override
  String get signInRequired => 'Sign in to view the budget';
  @override
  String get loadFailed => 'Could not load the budget';
  @override
  String get spentLabel => 'Spent';
  @override
  String expenseCount(int count) =>
      count == 1 ? '1 expense' : '$count expenses';
  @override
  String get yourBalanceLabel => 'Your balance';
  @override
  String youAreOwed(String amount) => 'You are owed $amount';
  @override
  String youOwe(String amount) => 'You owe $amount';
  @override
  String get allSettled => 'You are all settled';
  @override
  String owesYou(String name, String amount) => '$name owes you $amount';
  @override
  String youOweName(String name, String amount) => 'You owe $name $amount';
  @override
  String get settleUp => 'Settle up';
  @override
  String get settle => 'Settle';
  @override
  String get balancesHeading => 'Balances';
  @override
  String get settleUpHeading => 'Settle up';
  @override
  String get expensesHeading => 'Expenses';
  @override
  String get isOwed => 'is owed';
  @override
  String get owes => 'owes';
  @override
  String get settled => 'settled';
  @override
  String pays(String from, String to) => '$from pays $to';
  @override
  String paid(String from, String to) => '$from paid $to';
  @override
  String get settlementLabel => 'Settlement';
  @override
  String get paidChip => 'Paid';
  @override
  String paidBy(String name) => 'Paid by $name';
  @override
  String get you => 'you';
  @override
  String get youCapital => 'You';
  @override
  String splitWays(int count) => 'split $count ways';
  @override
  String get donated => 'Donated';
  @override
  String get expenseFallback => 'Expense';
  @override
  String get expenseWord => 'Expense';
  @override
  String get noExpenses => 'No expenses yet';
  @override
  String get noExpensesHelp => 'Tap + to add the first one';
  @override
  String get exportTooltip => 'Export';
  @override
  String get exportPdf => 'Export PDF';
  @override
  String get exportCsv => 'Export CSV';
  @override
  String get exportFailed => "Couldn't generate report";
  @override
  String get addExpenseTitle => 'Add Expense';
  @override
  String get editExpenseTitle => 'Edit Expense';
  @override
  String get addExpenseCta => 'Add Expense';
  @override
  String get saveChangesCta => 'Save changes';
  @override
  String get amountLabel => 'Amount';
  @override
  String get descriptionLabel => 'Description';
  @override
  String get descriptionHint => 'Description (optional)';
  @override
  String get donateLabel => 'Donate this cost';
  @override
  String get donateHelp => 'You cover it, so nobody owes you for it';
  @override
  String perPerson(String amount, int count) =>
      'Split: $amount per person ($count people)';
  @override
  String get addReceipt => 'Add receipt';
  @override
  String get receiptAttached => 'Receipt attached';
  @override
  String get removeReceipt => 'Remove receipt';
  @override
  String get receiptLabel => 'Receipt';
  @override
  String get viewReceipt => 'View receipt';
  @override
  String get deleteTitle => 'Delete this expense?';
  @override
  String get deleteBody =>
      'It will be removed for everyone and balances will update.';
  @override
  String get cancel => 'Cancel';
  @override
  String get delete => 'Delete';
  @override
  String get edit => 'Edit';
  @override
  String get deleteFailed => 'Could not delete expense';
  @override
  String get receiptUploadFailed =>
      'Receipt upload failed — saved the expense without it';
  @override
  String get invalidHandle => 'That payment handle looks invalid';
  @override
  String get copiedDetails => 'Copied — paste it where you settle';
  @override
  String copyDetailsText(String amount, String to, String event) =>
      '$amount to $to for $event';
  @override
  String get confirmSentTitle => 'Did you send the payment?';
  @override
  String confirmSentBody(String amount) =>
      "Did you send $amount? We'll record it in the budget so the ledger "
      'balances.';
  @override
  String get notYet => 'Not yet';
  @override
  String get yesRecorded => 'Yes, recorded';
  @override
  String get notFound => 'Expense not found';
  @override
  String get paidByLabel => 'Paid by';
  @override
  String get dateLabel => 'Date';
  @override
  String get splitLabel => 'Split';
  @override
  String eachShare(String amount) => '$amount each';
  @override
  String sheetPays(String from, String to) => '$from pay $to';
  @override
  String get them => 'them';
  @override
  String get payWithVenmo => 'Pay with Venmo';
  @override
  String get noVenmo => 'No Venmo handle';
  @override
  String get payWithCashApp => 'Pay with Cash App';
  @override
  String get noCashApp => 'No Cash App handle';
  @override
  String get copyPaymentDetails => 'Copy payment details';
  @override
  String someonePaid(String name) => '$name paid';
}

class _EnglishProfileStrings extends ProfileStrings {
  const _EnglishProfileStrings();

  @override
  String get heroTitle => 'Profile';

  @override
  String get heroUserFallback => 'User';

  @override
  String get editProfileCta => 'Edit Profile';

  @override
  String get statsEvents => 'Events';

  @override
  String get statsTasks => 'Tasks';

  @override
  String get statsOwed => 'Owed';

  @override
  String get settingsSection => 'Settings';

  @override
  String get paymentSection => 'Payment';

  @override
  String get notifications => 'Notifications';

  @override
  String get privacyDashboard => 'Privacy Dashboard';

  @override
  String get signOut => 'Sign Out';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get devTools => 'Dev tools';

  @override
  String get editTitle => 'Edit profile';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get photoGallery => 'Choose from Gallery';

  @override
  String get photoCamera => 'Take a Photo';

  @override
  String get nameLabel => 'Display name';

  @override
  String get nameHint => 'How others see you';

  @override
  String get nameRequired => 'Please enter your name';

  @override
  String get paymentHeading => 'Payment info';

  @override
  String get paymentHelp => 'Optional. Helps your crew settle up with you.';

  @override
  String get paymentMethodLabel => 'Payment method';

  @override
  String get paymentMethodPlaceholder => 'Select payment method';

  @override
  String get paymentHandleLabel => 'Payment handle';

  @override
  String get paymentHandleHint => '@username, phone, or email';

  @override
  String get settleHeading => 'Settle handles';

  @override
  String get settleHelp =>
      'Used by the Venmo and Cash App buttons when settling up in Budget.';

  @override
  String get venmoHandleLabel => 'Venmo handle';

  @override
  String get cashappHandleLabel => r'Cash App $cashtag';

  @override
  String get handleInvalid => 'Letters, numbers, _ or - only (≤30 chars)';

  @override
  String get save => 'Save changes';

  @override
  String get saved => 'Profile updated';

  @override
  String get saveDenied => 'Permission denied. Please try again.';

  @override
  String get saveOffline => 'Network error. Check your connection.';

  @override
  String get saveFailed => 'Failed to save profile. Please try again.';

  @override
  String get signInRequired => 'Sign in required';

  @override
  String get notifLoadFailed => 'Could not load notification settings';

  @override
  String get retry => 'Try again';

  @override
  String get notifPush => 'Push notifications';

  @override
  String get notifPushOn => 'Receive alerts on this device.';

  @override
  String get notifPushOff => 'All notifications are muted.';

  @override
  String get notifCategories => 'Categories';

  @override
  String get notifUrgent => 'Urgent chat alerts';

  @override
  String get notifUrgentHelp =>
      'Critical messages in group chats. Enable to receive 🚨 alerts.';

  @override
  String get notifTasks => 'Task assignments';

  @override
  String get notifTasksHelp => 'When someone assigns a task to you.';

  @override
  String get notifPayments => 'Payments';

  @override
  String get notifPaymentsHelp => 'New expenses and settlement disputes.';

  @override
  String get notifEvents => 'Event updates';

  @override
  String get notifEventsHelp => 'When someone joins one of your events.';

  @override
  String get notifQuiet => 'Quiet hours';

  @override
  String get notifQuietOff => 'Suppress non-urgent push during a daily window.';

  @override
  String notifQuietOn({
    required String start,
    required String end,
    required String zone,
  }) => 'Muted $start – $end ($zone)';

  @override
  String get notifQuietStart => 'Start';

  @override
  String get notifQuietEnd => 'End';

  @override
  String get notifDigest => 'Daily digest';

  @override
  String get notifDigestHelp =>
      'Morning summary of unread chat, pending tasks, and open '
      'settlements. Sent at 9:00 in your timezone.';

  @override
  String get notifSaveFailed => 'Could not save — try again';

  @override
  String get signOutTitle => 'Sign out of CrewPoint?';

  @override
  String get signOutBody => 'Your local data will be preserved for next time.';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteTitle => 'Delete Account?';

  @override
  String get deleteConfirmTitle => 'Confirm Deletion';

  @override
  String get deleteContinue => 'Continue';

  @override
  String get deleteForever => 'Delete Forever';

  // Verbatim retention clause from docs/legal/privacy-policy.md (Account
  // deletion section); change both together.
  @override
  String get deleteWarning =>
      'Your solo events will be permanently deleted. In shared events, '
      "your name and account ID will be replaced with 'deleted user' "
      'so the historical record stays intact for the rest of your group. '
      'This is irreversible. To request full erasure of an anonymized '
      'record on a per-event basis, contact support after deletion.';

  @override
  String get deletePasswordPrompt => 'Enter your password to confirm deletion.';

  @override
  String get deletePasswordLabel => 'Password';

  @override
  String get deleteReauthPrompt =>
      'To confirm account deletion, please re-authenticate '
      'with your sign-in provider.';

  @override
  String get deleteReauthGoogle => 'Sign in with Google to confirm';

  @override
  String get deleteReauthApple => 'Sign in with Apple to confirm';

  @override
  String get deleteUnknownProvider =>
      'Unable to determine your sign-in method. '
      'Please sign out and sign in again.';

  @override
  String get deleting => 'Deleting your account...';

  @override
  String get deleteWrongPassword => 'Incorrect password. Please try again.';

  @override
  String get deleteAuthFailed => 'Authentication failed. Please try again.';

  @override
  String get deleteFailed => 'Account deletion failed. Please try again.';

  @override
  String get themeRowTitle => 'Theme';

  @override
  String get themeModeSystem => 'System';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get themeModeSystemSubtitle => 'Follow device';

  @override
  String get addPaymentMethod => 'Add payment method';

  @override
  String get addPaymentMethodSubtitle => 'Let your crew know how to pay you';

  @override
  String get paymentMethodVenmo => 'Venmo';

  @override
  String get paymentMethodZelle => 'Zelle';

  @override
  String get paymentMethodCashApp => 'Cash App';

  @override
  String get paymentMethodPayPal => 'PayPal';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodOther => 'Other';

  @override
  String get paymentMethodGeneric => 'Payment';

  @override
  String appVersionLabel({required String version, required String build}) =>
      'CrewPoint v$version${build.isNotEmpty ? ' ($build)' : ''}';
}

class _EnglishNavStrings extends NavStrings {
  const _EnglishNavStrings();

  @override
  String get home => 'Home';

  @override
  String get tasks => 'Tasks';

  @override
  String get chat => 'Chat';

  @override
  String get budget => 'Budget';

  @override
  String get profile => 'Profile';

  @override
  String get signOutTooltip => 'Sign out';

  @override
  String get appName => 'CrewPoint';

  @override
  String selectToSee(String thing) {
    final word = thing.toLowerCase();
    final article = RegExp('^[aeiou]').hasMatch(word) ? 'an' : 'a';
    return 'Select $article $word to see details';
  }

  @override
  String get pageNotFoundTitle => 'Something went wrong';

  @override
  String get pageNotFoundBody => "We couldn't find that page.";

  @override
  String triedLocation(String location) => 'Tried: $location';

  @override
  String get goHome => 'Go home';

  @override
  String get eventNotFoundTitle => "We couldn't find that event";

  @override
  String get eventNotFoundBody =>
      'It may have been deleted, or you may not have access.';

  @override
  String get backToEvents => 'Back to events';

  @override
  String get eventSaveFailed => 'Could not save event';

  @override
  String get loading => 'Loading';

  @override
  String get bannerView => 'View';

  @override
  String get bannerDismiss => 'Dismiss';
}

class _EnglishDashboardStrings extends DashboardStrings {
  const _EnglishDashboardStrings();

  @override
  String get settingsEventHeading => 'Event';
  @override
  String get settingsAttendanceHeading => 'Attendance';
  @override
  String get settingsMoreHeading => 'More';

  @override
  String get joinSheetTitle => 'Join Event';
  @override
  String get joinSheetHelp =>
      'Enter the 6-character code shared by the event organizer';
  @override
  String get joinCodeLabel => 'Join code';
  @override
  String get joinCodeLength => 'Please enter a 6-character code';
  @override
  String get joined => 'You joined the event!';
  @override
  String get joinCodeInvalid => 'This code is invalid or has expired.';
  @override
  String get joinAlreadyMember => "You're already a member of this event.";
  @override
  String get joinFull => 'This event is full.';
  @override
  String get joinFailed => 'Something went wrong. Please try again.';
  @override
  String get joinOffline => 'Network error. Check your connection.';
  @override
  String get muteTitle => 'Mute event';
  @override
  String get mutedTitle => 'Currently muted';
  @override
  String get muteHelp =>
      'Pause all notifications for this event for the selected window. '
      "You'll still see messages when you open the chat.";
  @override
  String mutedUntil(String when) =>
      'Notifications for this event are paused until $when.';
  @override
  String get unmute => 'Unmute';
  @override
  String get muteHour => '1 hour';
  @override
  String get muteEightHours => '8 hours';
  @override
  String get muteDay => '1 day';
  @override
  String get muteUntilUnmute => 'Until I unmute';

  @override
  String lostAccess(String eventTitle) =>
      'You no longer have access to $eventTitle.';

  @override
  String get statusDraft => 'Draft';
  @override
  String get statusPublished => 'Published';
  @override
  String get statusLive => 'Live';
  @override
  String get statusEnded => 'Ended';
  @override
  String get statusArchived => 'Archived';
  @override
  String get draftCreated => 'Draft created. Only organizers can see it.';
  @override
  String get publishAndInvite => 'Publish and invite';
  @override
  String get publishEvent => 'Publish event';
  @override
  String get publishEventSubtitle =>
      'This draft is visible only to organizers. Publish it to invite people.';
  @override
  String get publishFailed => "Couldn't publish the event. Try again.";
  @override
  String get notOpenToInvites =>
      'Invites work only while the event is published or live.';
  @override
  String get notOpenToJoin => 'This event is not open to joining right now.';
  @override
  String get settingsStatus => 'Status';
  @override
  String get settingsStatusDraftUnavailable =>
      'This event has members, so it cannot go back to draft.';
  @override
  String get settingsArchivedNotice =>
      'This event is archived and read-only. Change its status to restore it.';
  @override
  String inviteLabel(String membersWord) => 'Invite $membersWord';
  @override
  String get moduleChat => 'Chat';
  @override
  String get moduleChatSubtitle => 'Messages & alerts';
  @override
  String get moduleBudget => 'Budget';
  @override
  String get moduleBudgetSubtitle => 'Expenses & settlements';
  @override
  String get moduleTasks => 'Tasks';
  @override
  String get moduleTasksSubtitle => 'To-dos & assignments';
  @override
  String get hubEmpty =>
      'Nothing is turned on for this event yet. An organizer can turn things '
      'on in event settings.';
  @override
  String get moduleOff => 'This part of the event is turned off.';
  @override
  String get settingsModules => 'What this event uses';
  @override
  String get settingsModulesHelp =>
      'Turning something off hides it and keeps its data for when it comes '
      'back.';
  @override
  String get settingsLabels => 'Words used in this event';
  @override
  String get settingsLabelsHelp =>
      'Rename anything to suit your event. Leave a box empty to keep the '
      'usual word.';
  @override
  String settingsLabelOne(String defaultWord) => 'One: $defaultWord';
  @override
  String settingsLabelOther(String defaultWord) => 'Many: $defaultWord';
  @override
  String get settingsTitle => 'Event settings';
  @override
  String get settingsNoAccess => 'Only organizers can change event settings.';
  @override
  String get settingsBack => 'Back to the event';
  @override
  String get settingsTimeZone => 'Time zone';
  @override
  String get settingsTimeZoneHelp =>
      'Dates and times show in this zone for everyone.';
  @override
  String get settingsTimeZoneSearch => 'Search, for example Chicago';
  @override
  String get settingsTimeZoneNone => 'No matching zone.';
  @override
  String get settingsVenues => 'Venues';
  @override
  String get settingsVenuesEmpty => 'No venues yet.';
  @override
  String get settingsVenueName => 'Venue name';
  @override
  String get settingsVenueNameRequired => 'Enter a name, or remove this venue';
  @override
  String get settingsVenueAddress => 'Address (optional)';
  @override
  String get settingsVenueAdd => 'Add venue';
  @override
  String get settingsVenueRemove => 'Remove venue';
  @override
  String get settingsCurrency => 'Currency';
  @override
  String get settingsCurrencyHelp => 'Can change until money is recorded.';
  @override
  String get settingsCurrencyLocked =>
      'This event has money recorded, so its currency cannot change.';
  @override
  String get settingsLanguages => 'Languages';
  @override
  String get settingsLanguagesHelp => 'Language codes, such as en, es';
  @override
  String get settingsLanguagesInvalid =>
      'Enter at least one code, separated by commas';
  @override
  String get settingsCapacity => 'Capacity (optional)';
  @override
  String settingsCapacityCount(int count, int? capacity) =>
      capacity == null ? '$count attending' : '$count of $capacity attending';
  @override
  String get settingsMemberLimit => 'Member limit (optional)';
  @override
  String get settingsMemberLimitHelp =>
      'How many people can log in. Leave empty for no limit.';
  @override
  String get settingsWholeNumber => 'Enter a whole number above zero';
  @override
  String get settingsSave => 'Save settings';
  @override
  String get settingsSaved => 'Settings saved';
  @override
  String get settingsPending =>
      "You're offline. These settings will save when you reconnect.";
  @override
  String get settingsNeedsConnection =>
      'Changing the currency needs a connection. Nothing was saved.';
  @override
  String get settingsFailed => "Couldn't save settings. Try again.";
  @override
  String get settingsDiscardTitle => 'Discard changes?';
  @override
  String get settingsDiscardBody => 'Your changes have not been saved.';
  @override
  String get settingsDiscard => 'Discard';
  @override
  String get settingsKeepEditing => 'Keep editing';

  @override
  String get noEventsTitle => 'No events yet';

  @override
  String get noEventsSubtitle => 'Create an event or join one with a code';

  @override
  String get joinWithCode => 'Join with Code';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get joinEventTooltip => 'Join Event';

  @override
  String get filterUpcoming => 'Upcoming';

  @override
  String get filterPast => 'Past';

  @override
  String get createEventCta => 'Create Event';

  @override
  String get createEventNeedsConnection =>
      'Creating an event needs a connection. Check yours and try again.';

  @override
  String get createEventRetry => 'Retry';

  @override
  String leaveEventBalanceWarning(String amount) =>
      'You have an outstanding balance of $amount. You can still leave, and '
      'it stays visible to the event so it can be settled.';

  @override
  String upcomingEventsHeader(int count) => '$count UPCOMING EVENTS';

  @override
  String pastEventsHeader(int count) => '$count PAST EVENTS';

  @override
  String get errorLoading => "We couldn't load your events.";

  @override
  String get retryCta => 'Try again';
}

class _EnglishTasksStrings extends TasksStrings {
  const _EnglishTasksStrings();

  @override
  String get sectionDetails => 'Details';

  @override
  String get sectionAssignment => 'Assignment';

  @override
  String get sectionTimingAndBudget => 'Timing & Budget';

  @override
  String get overdueBadge => 'Overdue';

  @override
  String get priorityNone => 'None';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get searchHint => 'Search tasks';

  @override
  String get sortBy => 'Sort by';

  @override
  String get groupBy => 'Group by';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get filterChipMine => 'Mine';

  @override
  String get filterChipOverdue => 'Overdue';

  @override
  String get filterChipHasBudget => 'Has budget';

  @override
  String get statusTodo => 'To Do';

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get statusDone => 'Done';

  @override
  String get sortDueDate => 'Due date';

  @override
  String get sortPriority => 'Priority';

  @override
  String get sortCreated => 'Created';

  @override
  String get sortTitle => 'Title';

  @override
  String get groupStatus => 'Status';

  @override
  // Shortened from 'Assignee' for the iPhone 12 mini SegmentedButton
  // overflow fix (2026-06-08). The 'tasks.list.groupToggle.assignee'
  // Key is still 'assignee' — the segment value is what tests target;
  // only the rendered label changed.
  String get groupAssignee => 'People';

  @override
  // Shortened from 'Due window' for the same fix.
  String get groupDueWindow => 'Due';

  @override
  String get dueWindowToday => 'Today';

  @override
  String get dueWindowThisWeek => 'This week';

  @override
  String get dueWindowLater => 'Later';

  @override
  String get dueWindowNoDueDate => 'No due date';

  @override
  String get assigneeUnassigned => 'Unassigned';

  @override
  String get emptyNoTasksYet => 'No tasks yet';

  @override
  String get emptyNoTasksHelp => 'Tap + to create your first task';

  @override
  String get emptyNoMatch => 'No tasks match this filter';

  @override
  String get myTasksAppBarTitle => 'My Tasks';

  @override
  String get myTasksEmptyTitle => 'No tasks assigned to you';

  @override
  String get myTasksEmptySubtitle =>
      'Open an event from the Dashboard to view or create tasks.';

  @override
  String get myTasksEmptySubtitleNoEvents =>
      'Create an event from the Dashboard to get started.';

  @override
  // The bottom-nav tab on mobile reads "Home". Earlier copy ("Open
  // Dashboard") referenced the legacy name and made the empty-state
  // CTAs feel disconnected from the destination they navigate to.
  String get openDashboardCta => 'Go to Home';

  @override
  String get createFromDashboardCta => 'Create an event';

  @override
  String get signInRequiredTitle => 'Sign in to view your tasks';

  @override
  String get detailEdit => 'Edit';

  @override
  String get detailDuplicate => 'Duplicate';

  @override
  String get detailDelete => 'Delete';

  @override
  String get fieldPriority => 'Priority';

  @override
  String get tasksAppBarTitle => 'Tasks';

  @override
  String get exportPdfTooltip => 'Export PDF';

  @override
  String get createTaskTitle => 'Create Task';

  @override
  String get editTaskTitle => 'Edit Task';

  @override
  String get taskTitleHint => 'Task Title';

  @override
  String get descriptionOptionalHint => 'Description (optional)';

  @override
  String get dueDateLabel => 'Due Date';

  @override
  String get budgetEstimateLabel => 'Budget Estimate (optional)';

  @override
  String get createTaskCta => 'Create Task';

  @override
  String get saveChangesCta => 'Save changes';

  @override
  String get checklistAddHint => 'Add item';

  @override
  String checklistHeading(int count, int max) => 'Checklist ($count/$max)';

  @override
  String get checklistAdd => 'Add to checklist';

  @override
  String get checklistRemove => 'Remove item';

  @override
  String get filterAll => 'All';

  @override
  String doneOf(int done, int total) => '$done of $total done';

  @override
  String progressDetail(int overdue, int dueThisWeek) {
    final parts = [
      if (overdue > 0) '$overdue overdue',
      if (dueThisWeek > 0) '$dueThisWeek due this week',
    ];
    return parts.isEmpty ? 'Nothing due this week' : parts.join(' · ');
  }

  @override
  String dueOn(String day) => 'Due $day';

  @override
  String overdueOn(String day) => 'Overdue $day';

  @override
  String get dueToday => 'Due today';

  @override
  String get sortTooltip => 'Sort';

  @override
  String get createFailed => 'Failed to create task';

  @override
  String get statusFailed => 'Could not update status';

  @override
  String get statusNotAllowed =>
      'Only the assignee or an admin can change this';

  @override
  String get exportFailed => "Couldn't generate report";

  @override
  String get saveFailed => 'Could not save changes';

  @override
  String get duplicateFailed => 'Could not duplicate task';

  @override
  String get loadFailed => 'Could not load tasks';

  @override
  String get notFound => 'Task not found';

  @override
  String get taskWord => 'Task';

  @override
  String get deleteTitle => 'Delete this task?';

  @override
  String get deleteBody =>
      'This cannot be undone. Members will lose the task and any '
      'checklist items.';

  @override
  String get cancel => 'Cancel';

  @override
  String get statusLabel => 'Status';

  @override
  String get assigneeLabel => 'Assigned to';

  @override
  String get dueLabel => 'Due';

  @override
  String get budgetLabel => 'Budget';

  @override
  String completedOn(String date, String? by) =>
      by == null ? 'Completed $date' : 'Completed $date by $by';

  @override
  String get unknownMember => 'Unknown member';

  @override
  String get noLongerInEvent => '(no longer in event)';

  @override
  String get willSync => 'Will sync when online';

  @override
  String get titleLabel => 'Title';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get titleRequired => 'Please enter a title';

  @override
  String titleTooLong(int max) => 'Title must be $max characters or fewer';

  @override
  String get clearDueDate => 'No due date';

  @override
  String get myTasksNoMatches => 'No tasks match this filter';

  @override
  String overdueCount(int count) => 'Overdue · $count';

  @override
  String get statusChange => 'Change status';

  @override
  String get budgetInvalid =>
      'Must be a non-negative number with up to 2 decimals';
}

class _EnglishAuthStrings extends AuthStrings {
  const _EnglishAuthStrings();

  @override
  String get heroTitle => 'CrewPoint';

  @override
  String get tagline => 'Collaborate. Organize. Deliver.';

  @override
  String get dividerLabel => 'or continue with email';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get emailHint => 'Email';

  @override
  String get passwordHint => 'Password';

  @override
  String get fullNameHint => 'Full Name';

  @override
  String get signIn => 'Sign In';

  @override
  String get createAccount => 'Create Account';

  @override
  String get toggleToSignIn => 'Already have an account? Sign In';

  @override
  String get toggleToSignUp => "Don't have an account? Sign Up";

  @override
  String get validatorEmailRequired => 'Please enter your email';

  @override
  String get validatorEmailInvalid => 'Please enter a valid email';

  @override
  String get validatorPasswordTooShort =>
      'Password must be at least 6 characters';

  @override
  String get validatorNameRequired => 'Please enter your name';

  @override
  String suggestProvider(String providerLabel) =>
      'This email is registered with $providerLabel. '
      'Tap "Continue with $providerLabel" above.';

  @override
  String get verifyBannerTitle =>
      'Verify your email so this sign-in stays active';

  @override
  String verifyBannerBody(String email) => 'We sent a link to $email.';

  @override
  String get verifyBannerResend => 'Resend';

  @override
  String get verifyBannerRefresh => "I've verified";

  @override
  String get legalFooterPrefix => 'By continuing, you agree to our ';

  @override
  String get legalFooterTermsLink => 'Terms';

  @override
  String get legalFooterAnd => ' and ';

  @override
  String get legalFooterPrivacyLink => 'Privacy Policy';

  @override
  String get legalFooterSuffix => '.';

  @override
  String get existingProvider => 'your existing provider';
}

class _EnglishErrorStrings extends ErrorStrings {
  const _EnglishErrorStrings();

  @override
  String get permissionDenied =>
      "You don't have permission to do that. Your role in this event may "
      'have changed.';

  @override
  String get invalidEmail => 'The email address is invalid.';

  @override
  String get wrongPassword => 'Incorrect email or password.';

  @override
  String get userNotFound => 'No account found with this email.';

  @override
  String get emailAlreadyInUse => 'An account already exists with this email.';

  @override
  String get weakPassword => 'Password must be at least 6 characters.';

  @override
  String get networkRequestFailed =>
      'Network error. Please check your connection.';

  @override
  String get popupBlocked =>
      'Pop-ups are blocked - please allow pop-ups for this site and try again.';

  @override
  String get popupCancelled => 'Sign-in cancelled.';

  @override
  String get tooManyRequests =>
      'Too many attempts. Please wait a minute before trying again.';

  @override
  String get genericFallback =>
      'An unexpected error occurred. Please try again.';
}

/// The full-screen message shown below the minimum app version (Req 34a).
abstract class UpdateStrings {
  const UpdateStrings();

  String get title;
  String get body;
  String get openStore;
  String get reload;

  /// Shown when there is no store link, so the person knows where to look.
  String get noStoreLink;
}

class _EnglishUpdateStrings extends UpdateStrings {
  const _EnglishUpdateStrings();

  @override
  String get title => 'Update CrewPoint';

  @override
  String get body =>
      'This version of CrewPoint is no longer supported. Update to keep '
      'using it.';

  @override
  String get openStore => 'Update now';

  @override
  String get reload => 'Reload';

  @override
  String get noStoreLink => 'Get the latest version from your app store.';
}

/// The Roles, Role editor and Member detail screens, and invite roles (#67).
abstract class RoleStrings {
  const RoleStrings();

  // Roles
  String get title;
  String get presetsHeading;
  String get customHeading;
  String get noCustomRoles;
  String get noCustomRolesHint;
  String get newRole;
  String permissionCount(int count);
  String get edited;
  String get loadFailed;
  String get retry;
  String get noAccessTitle;
  String get noAccessBody;
  String get readOnly;

  // Role editor
  String get nameLabel;
  String get nameRequired;
  String nameTooLong(int max);
  String get permissionsHeading;
  String get save;
  String get saved;
  String get saveFailed;
  String get ownerFixed;
  String get reset;
  String get resetTitle;
  String get resetBody;
  String get resetDone;
  String get delete;
  String get deleteTitle;
  String get deleteBody;
  String get deleted;
  String get deleteFailed;
  String get discardTitle;
  String get discardBody;
  String get keepEditing;
  String get discard;
  String get cancel;
  String get roleNotFound;

  /// The heading for a group of permissions in the editor.
  String permissionGroup(String group);

  /// A permission's name, for someone who has never seen the catalogue.
  String permission(String id);

  // Member detail
  String get rolesHeading;
  String get grantsHeading;
  String get grantsNothing;
  String get saveRoles;
  String get rolesSaved;
  String get rolesSaveFailed;
  String get pickOneRole;
  String get ownerNote;
  String get remove;
  String removeTitle(String member);
  String get removeBody;
  String removed(String member);
  String get removeFailed;
  String memberGone(String member);
  String get you;

  // Invite and leave
  String get inviteRoleLabel;
  String get inviteRoleHint;
  String get inviteRoleFailed;
  String get leaveOnlyManagerWarning;

  /// [name] is the one person left who can invite and remove people, or null
  /// when unknown.
  String leaveOneManagerLeftWarning(String? name);

  // The members list in the new look (Spec #186, #206).
  String membersTitle(String members, int count);
  String removeMemberTitle(String member);
  String get removeMemberBody;
  String memberRemoved(String member);
  String get makeAdmin;
  String get removeAdmin;
  String get promoted;
  String get demoted;
  String get promoteFailed;
  String get demoteFailed;
  String get memberOptions;
  String inviteTooltip(String members);
}

class _EnglishRoleStrings extends RoleStrings {
  const _EnglishRoleStrings();

  @override
  String membersTitle(String members, int count) => '$members ($count)';
  @override
  String removeMemberTitle(String member) => 'Remove $member?';
  @override
  String get removeMemberBody =>
      'They will lose access to this event. '
      'Their past messages and expenses will remain.';
  @override
  String memberRemoved(String member) => '$member removed';
  @override
  String get makeAdmin => 'Make Admin';
  @override
  String get removeAdmin => 'Remove Admin';
  @override
  String get promoted => 'Promoted to admin';
  @override
  String get demoted => 'Demoted to member';
  @override
  String get promoteFailed => 'Failed to promote';
  @override
  String get demoteFailed => 'Failed to demote admin';
  @override
  String get memberOptions => 'Options';
  @override
  String inviteTooltip(String members) => 'Invite $members';

  @override
  String get title => 'Roles';
  @override
  String get presetsHeading => 'Built-in roles';
  @override
  String get customHeading => 'Custom roles';
  @override
  String get noCustomRoles => 'No custom roles yet';
  @override
  String get noCustomRolesHint =>
      'Make a role with exactly what one job needs.';
  @override
  String get newRole => 'New role';
  @override
  String permissionCount(int count) =>
      count == 1 ? '1 permission' : '$count permissions';
  @override
  String get edited => 'Edited';
  @override
  String get loadFailed => "Couldn't load this. Check your connection.";
  @override
  String get retry => 'Try again';
  @override
  String get noAccessTitle => "You can't open this";
  @override
  String get noAccessBody =>
      'Only people who manage members or roles can see this page.';
  @override
  String get readOnly => 'Only owners and co-owners can change roles.';

  @override
  String get nameLabel => 'Name';
  @override
  String get nameRequired => 'Give the role a name.';
  @override
  String nameTooLong(int max) => 'Use $max characters or fewer.';
  @override
  String get permissionsHeading => 'What this role can do';
  @override
  String get save => 'Save';
  @override
  String get saved => 'Role saved';
  @override
  String get saveFailed =>
      "Couldn't save the role. Your changes are still here, so try again.";
  @override
  String get ownerFixed =>
      'The Owner can always do everything. Ownership moves only through a '
      'transfer.';
  @override
  String get reset => 'Reset to built-in';
  @override
  String get resetTitle => 'Reset this role?';
  @override
  String get resetBody =>
      'Everyone with this role goes back to its built-in permissions.';
  @override
  String get resetDone => 'Role reset';
  @override
  String get delete => 'Delete role';
  @override
  String get deleteTitle => 'Delete this role?';
  @override
  String get deleteBody =>
      'A role can be deleted only when nobody holds it. This cannot be undone.';
  @override
  String get deleted => 'Role deleted';
  @override
  String get deleteFailed =>
      "Couldn't delete the role. Take it off everyone who holds it first.";
  @override
  String get discardTitle => 'Discard changes?';
  @override
  String get discardBody => "Your changes haven't been saved.";
  @override
  String get keepEditing => 'Keep editing';
  @override
  String get discard => 'Discard';
  @override
  String get cancel => 'Cancel';
  @override
  String get roleNotFound => 'This role no longer exists.';

  @override
  String permissionGroup(String group) => switch (group) {
    'event' => 'Event',
    'people' => 'People and roles',
    'schedule' => 'Schedule and updates',
    'participants' => 'Participants and groups',
    'money' => 'Money',
    'tasks' => 'Tasks',
    'chat' => 'Chat',
    'checkin' => 'Check-in and counts',
    'safety' => 'Safety',
    'competition' => 'Reports and competition',
    _ => group,
  };

  @override
  String permission(String id) => switch (id) {
    'event.manage' => 'Change event settings',
    'event.transfer' => 'Transfer or delete the event',
    'members.manage' => 'Invite and remove people',
    'roles.manage' => 'Change roles',
    'schedule.edit' => 'Edit the schedule',
    'updates.send' => 'Post updates',
    'participants.read' => 'See participants',
    'participants.edit' => 'Edit participants',
    'participants.readPrivate' => 'See private participant details',
    'participants.import' => 'Import participants',
    'group.readOwn' => 'See their own group',
    'group.editOwn' => 'Edit their own group',
    'registrations.manage' => 'Manage registrations',
    'money.read' => 'See money',
    'money.record' => 'Record and edit payments',
    'money.refund' => 'Give refunds',
    'money.dueAtDoor' => 'Take payment at the door',
    'budget.read' => 'See the budget',
    'budget.edit' => 'Edit the budget',
    'expenses.readAll' => 'See every expense',
    'contributions.manage' => 'Manage contributions',
    'tasks.manage' => "Manage everyone's tasks",
    'chat.send' => 'Send chat messages',
    'chat.urgent' => 'Send urgent messages',
    'messages.send' => 'Send messages to participants',
    'checkin.scan' => 'Scan people in',
    'checkin.lookup' => 'Look people up at check-in',
    'counts.read' => 'See counts',
    'incidents.report' => 'Report incidents',
    'incidents.receive' => 'Receive incident alerts',
    'reports.export' => 'Export reports',
    'competition.manage' => 'Run the competition',
    'scores.enter' => 'Enter scores',
    _ => id,
  };

  @override
  String get rolesHeading => 'Roles';
  @override
  String get grantsHeading => 'What they can do';
  @override
  String get grantsNothing =>
      'Read the event and its published schedule, nothing more.';
  @override
  String get saveRoles => 'Save roles';
  @override
  String get rolesSaved => 'Roles saved';
  @override
  String get rolesSaveFailed =>
      "Couldn't save the roles. Your choices are still here, so try again.";
  @override
  String get pickOneRole => 'Choose at least one role.';
  @override
  String get ownerNote => 'Ownership moves only through a transfer.';
  @override
  String get remove => 'Remove from event';
  @override
  String removeTitle(String member) => 'Remove $member?';
  @override
  String get removeBody =>
      'They lose access straight away. Their past messages and expenses stay.';
  @override
  String removed(String member) => '$member removed';
  @override
  String get removeFailed => "Couldn't remove them. Try again.";
  @override
  String memberGone(String member) =>
      'This ${member.toLowerCase()} is no longer in the event.';
  @override
  String get you => 'You';

  @override
  String get inviteRoleLabel => 'Joins as';
  @override
  String get inviteRoleHint =>
      'Changing the role makes a new code. The old one stops working.';
  @override
  String get inviteRoleFailed => "Couldn't change the role. Try again.";
  @override
  String get leaveOnlyManagerWarning =>
      "You're the only one who can invite and remove people. Give someone "
      'else that permission first, or nobody will be able to.';
  @override
  String leaveOneManagerLeftWarning(String? name) =>
      'After you leave, only ${name ?? 'one other person'} can invite and '
      'remove people. Give someone else that permission first, so there is '
      'always a backup.';
}

/// The event list and the Event home (Spec #186, #199).
abstract class EventHomeStrings {
  const EventHomeStrings();

  String get happeningNow;
  String get upcoming;
  String get drafts;
  String get past;
  String get createEvent;
  String get muted;
  String get mute;
  String get settings;
  String get tasks;
  String get budget;
  String openCount(int count);
  String tasksDone(int done, int total);
  String expenseCount(int count);
  String get noTasks;
  String get upNext;
  String get scheduleLink;
  String get nothingNext;
  String get openTasks;
  String get allTasks;
  String get noOpenTasks;
  String get overdue;
  String due(String day);
  String get eventSection;
  String get manageSection;
  String get editEvent;
  String get editEventSubtitle;
  String get inviteSubtitle;
  String get archiveEvent;
  String get archived;
  String get archiveHelp;
  String get archiveFailed;
  String get leaveEvent;
  String get leaveTitle;
  String get leaveBody;
  String get leave;
  String get cancel;
  String get leaveFailed;
  String get deleteEvent;
  String get deleteTitle;
  String get deleteBody;
  String get continueLabel;
  String get confirmTitle;
  String get confirmBody;
  String get deleteForever;
  String get deleteFailed;
}

class _EnglishEventHomeStrings extends EventHomeStrings {
  const _EnglishEventHomeStrings();

  @override
  String get happeningNow => 'Happening now';
  @override
  String get upcoming => 'Upcoming';
  @override
  String get drafts => 'Drafts';
  @override
  String get past => 'Past';
  @override
  String get createEvent => 'Create an event';
  @override
  String get muted => 'Muted — tap to manage';
  @override
  String get mute => 'Mute event';
  @override
  String get settings => 'Event settings';
  @override
  String get tasks => 'Tasks';
  @override
  String get budget => 'Budget';
  @override
  String openCount(int count) => '$count open';
  @override
  String tasksDone(int done, int total) => '$done of $total tasks done';
  @override
  String expenseCount(int count) =>
      count == 1 ? '1 expense' : '$count expenses';
  @override
  String get noTasks => 'No tasks yet';
  @override
  String get upNext => 'Up next';
  @override
  String get scheduleLink => 'Schedule';
  @override
  String get nothingNext => 'Nothing else is on the schedule.';
  @override
  String get openTasks => 'Open tasks';
  @override
  String get allTasks => 'All tasks';
  @override
  String get noOpenTasks => 'No open tasks.';
  @override
  String get overdue => 'Overdue';
  @override
  String due(String day) => 'Due $day';
  @override
  String get eventSection => 'Event';
  @override
  String get manageSection => 'Manage';
  @override
  String get editEvent => 'Edit Event';
  @override
  String get editEventSubtitle => 'Update title, dates, or details';
  @override
  String get inviteSubtitle => 'Share a code to add people';
  @override
  String get archiveEvent => 'Archive Event';
  @override
  String get archived => 'Event is archived (read-only)';
  @override
  String get archiveHelp => 'Archive to make read-only';
  @override
  String get archiveFailed => 'Could not update archive status';
  @override
  String get leaveEvent => 'Leave Event';
  @override
  String get leaveTitle => 'Leave Event?';
  @override
  String get leaveBody =>
      'You will lose access to this event. '
      'Your past messages and expenses will remain.';
  @override
  String get leave => 'Leave';
  @override
  String get cancel => 'Cancel';
  @override
  String get leaveFailed => 'Failed to leave event';
  @override
  String get deleteEvent => 'Delete Event';
  @override
  String get deleteTitle => 'Delete Event?';
  @override
  String get deleteBody =>
      'This will permanently delete the event and all its data: '
      'messages, expenses, tasks, and invite codes.\n\n'
      'This action cannot be undone.';
  @override
  String get continueLabel => 'Continue';
  @override
  String get confirmTitle => 'Are you sure?';
  @override
  String get confirmBody =>
      'All event data will be permanently erased for all members.';
  @override
  String get deleteForever => 'Delete Forever';
  @override
  String get deleteFailed => 'Failed to delete event';
}

/// An event's cover photo (Spec #186 Req 41–44).
abstract class CoverStrings {
  const CoverStrings();

  String get heading;
  String get help;
  String get none;
  String get choose;
  String get replace;
  String get remove;
  String get saved;
  String get removed;
  String get tooLarge;
  String get notAnImage;
  String get failed;
  String get removeFailed;
}

class _EnglishCoverStrings extends CoverStrings {
  const _EnglishCoverStrings();

  @override
  String get heading => 'Cover photo';
  @override
  String get help =>
      'Shown on the event home and in the event list. JPEG, PNG or WebP, '
      'under 5 MB.';
  @override
  String get none => 'No photo yet. The event shows its icon instead.';
  @override
  String get choose => 'Choose photo';
  @override
  String get replace => 'Replace photo';
  @override
  String get remove => 'Remove photo';
  @override
  String get saved => 'Cover photo saved';
  @override
  String get removed => 'Cover photo removed';
  @override
  String get tooLarge => 'That photo is 5 MB or more. Choose a smaller one.';
  @override
  String get notAnImage => 'Choose a JPEG, PNG or WebP photo.';
  @override
  String get failed =>
      "Couldn't save the photo. Check your connection and try again.";
  @override
  String get removeFailed => "Couldn't remove the photo. Try again.";
}

/// The group screen (Spec #186 Req 25–36): adding a whole group, or people
/// to one. [group] is the event's word for a group, from `event.words`.
abstract class GroupEntryStrings {
  const GroupEntryStrings();

  String addPerson(String participant);
  String addGroup(String group);
  String addPeople(String people);
  String newTitle(String group);
  String addToTitle(String name);
  String groupName(String group);
  String groupQuestions(String group);
  String personTitle(int number);
  String get peopleHeading;
  String peopleCount(int count);
  String get adult;
  String get child;
  String get nameLabel;
  String get emailLabel;
  String get emailHelp;
  String get phoneLabel;
  String get phoneHelp;
  String get phoneInvalid;
  String get birthDateLabel;
  String birthDateHelp(String? band);
  String get clearBirthDate;
  String sameAnswersAs(String name);
  String get sameAnswersAsPrevious;
  String get addAnotherPerson;
  String get removePerson;
  String get required;
  String get chooseAnswer;
  String get enterAnswer;
  String get privateHeading;
  String get yes;
  String get no;
  String get addAtLeastOne;
  String missingCount(int count);
  String get nameRequired;
  String save(String group);
  String get saveAdditions;
  String offline(String group);
  String groupFailed(String group);
  String answersFailed(String group);
  String peopleFailed(String group);
  String newGroupSaved(String name, int count);
  String addedToGroup(String name, int count);
  String get maxPeople;
  String yourGroup(String group);
  String get editAnswers;
  String editTitle(String name);
  String get saveAnswers;
  String answersSaved(String name);
  String get questionsHeading;
}

class _EnglishGroupEntryStrings extends GroupEntryStrings {
  const _EnglishGroupEntryStrings();

  @override
  String addPerson(String participant) => 'Add ${participant.toLowerCase()}';
  @override
  String addGroup(String group) => 'Add ${group.toLowerCase()}';
  @override
  String addPeople(String people) => 'Add people';
  @override
  String newTitle(String group) => 'New ${group.toLowerCase()}';
  @override
  String addToTitle(String name) => 'Add people to $name';
  @override
  String groupName(String group) => '$group name';
  @override
  String groupQuestions(String group) => 'For the whole ${group.toLowerCase()}';
  @override
  String personTitle(int number) => 'Person $number';
  @override
  String get peopleHeading => 'People';
  @override
  String peopleCount(int count) => count == 1 ? '1 person' : '$count people';
  @override
  String get adult => 'Adult';
  @override
  String get child => 'Child';
  @override
  String get nameLabel => 'Name';
  @override
  String get emailLabel => 'Email (private)';
  @override
  String get emailHelp =>
      'Links their account when they sign in with this email.';
  @override
  String get phoneLabel => 'Phone (private)';
  @override
  String get phoneHelp =>
      'Links their account when they sign in with this number. '
      'Add the country code for a number outside this event\'s country.';
  @override
  String get phoneInvalid =>
      'Enter the whole number, with the area code, such as (214) 555-0100 '
      'or +44 7700 900123.';
  @override
  String get birthDateLabel => 'Birth date (private)';
  @override
  String birthDateHelp(String? band) => band == null
      ? 'Optional. Sets the age band.'
      : 'Sets the age band: $band.';
  @override
  String get clearBirthDate => 'Clear birth date';
  @override
  String sameAnswersAs(String name) => 'Same answers as $name';
  @override
  String get sameAnswersAsPrevious => 'Same answers as the person above';
  @override
  String get addAnotherPerson => 'Add another person';
  @override
  String get removePerson => 'Remove this person';
  @override
  String get required => 'required';
  @override
  String get chooseAnswer => 'Choose an answer.';
  @override
  String get enterAnswer => 'Enter an answer.';
  @override
  String get privateHeading => 'Private';
  @override
  String get yes => 'Yes';
  @override
  String get no => 'No';
  @override
  String get addAtLeastOne => 'Add at least one person';
  @override
  String missingCount(int count) =>
      count == 1 ? '1 answer missing' : '$count answers missing';
  @override
  String get nameRequired => 'Enter a name.';
  @override
  String save(String group) => 'Save ${group.toLowerCase()}';
  @override
  String get saveAdditions => 'Save people';
  @override
  String offline(String group) =>
      "You're offline. Connect to save this ${group.toLowerCase()}.";
  @override
  String groupFailed(String group) =>
      "Couldn't create the ${group.toLowerCase()}, so nothing was saved. "
      'Everything you typed is still here, so try again.';
  @override
  String answersFailed(String group) =>
      "The ${group.toLowerCase()}'s answers and people weren't saved. "
      'Everything you typed is still here, so try again.';
  @override
  String peopleFailed(String group) =>
      "The ${group.toLowerCase()} is saved, but its people aren't. "
      'Everything you typed is still here, so try again.';
  @override
  String newGroupSaved(String name, int count) =>
      '$name added with ${count == 1 ? '1 person' : '$count people'}';
  @override
  String addedToGroup(String name, int count) =>
      '${count == 1 ? '1 person' : '$count people'} added to $name';
  @override
  String get maxPeople => 'Up to 20 people at a time.';
  @override
  String yourGroup(String group) => 'Your ${group.toLowerCase()}';
  @override
  String get editAnswers => 'Edit answers';
  @override
  String editTitle(String name) => 'Answers for $name';
  @override
  String get saveAnswers => 'Save answers';
  @override
  String answersSaved(String name) => 'Answers saved for $name';
  @override
  String get questionsHeading => 'Questions';
}

/// The Crews screen and task crews (#68). [crew] and [crews] are the event's
/// own words for the concept, from `event.words`.
/// The roster, participant and group screens (Req 40, 43). Concept words,
/// such as the event's word for a participant or a group, come from
/// `event.words` and are passed in.
abstract class PeopleStrings {
  const PeopleStrings();

  String get noAdultsYet;

  String searchHint(String participants);
  String get hubSubtitle;
  String get onlineNote;
  String filterByGroup(String group);
  String get all;
  String allGroups(String groups);
  String clearGroup(String group);
  String manageGroup(String group);
  String add(String participant);
  String emptyTitle(String participants);
  String emptyHint(String group);
  String get loadFailed;
  String get retry;
  String get loadMore;
  String get child;
  String noGroup(String group);
  String newTitle(String participant);
  String get nameLabel;
  String get nameRequired;
  String nameTooLong(int max);
  String groupLabel(String group);
  String newGroup(String group);
  String newGroupName(String group);
  String get childLabel;
  String get childHelp;
  String get birthDateLabel;
  String get birthDateHelp;
  String get clearBirthDate;
  String get save;
  String get saved;
  String get saveFailed;
  String get delete;
  String deleteTitle(String name);
  String get deleteBody;
  String get deleted;
  String get deleteFailed;
  String notFound(String participant);
  String get readOnly;
  String groupSearchHint(String groups);
  String noGroupsFound(String groups);
  String groupNameLabel(String group);
  String get rename;
  String get adultsHeading;
  String adultsHelp(String group);
  String get noMembers;
  String deleteGroupTitle(String name);
  String deleteGroup(String group);
  String deleteGroupBody(String group);
  String get groupSaved;
  String get groupDeleted;
  String get groupSaveFailed;
}

class _EnglishPeopleStrings extends PeopleStrings {
  const _EnglishPeopleStrings();

  @override
  String deleteGroup(String group) => 'Delete ${group.toLowerCase()}';
  @override
  String get all => 'All';
  @override
  String get noAdultsYet => 'No linked adults yet.';

  @override
  String searchHint(String participants) =>
      'Search ${participants.toLowerCase()} by name';
  @override
  String get hubSubtitle => 'Who is coming, with or without an account';
  @override
  String get onlineNote =>
      'Needs a connection. This list is not kept on your device.';
  @override
  String filterByGroup(String group) => 'Filter by ${group.toLowerCase()}';
  @override
  String allGroups(String groups) => 'All ${groups.toLowerCase()}';
  @override
  String clearGroup(String group) => 'Show every ${group.toLowerCase()}';
  @override
  String manageGroup(String group) => 'Manage ${group.toLowerCase()}';
  @override
  String add(String participant) => 'Add ${participant.toLowerCase()}';
  @override
  String emptyTitle(String participants) =>
      'No ${participants.toLowerCase()} yet';
  @override
  String emptyHint(String group) =>
      'Add people attending, with or without an account. Put people who come '
      'together in the same ${group.toLowerCase()}.';
  @override
  String get loadFailed =>
      "Couldn't load. This list needs a connection, so check yours and try "
      'again.';
  @override
  String get retry => 'Try again';
  @override
  String get loadMore => 'Show more';
  @override
  String get child => 'Child';
  @override
  String noGroup(String group) => 'No ${group.toLowerCase()}';
  @override
  String newTitle(String participant) => 'New ${participant.toLowerCase()}';
  @override
  String get nameLabel => 'Name';
  @override
  String get nameRequired => 'Enter a name.';
  @override
  String nameTooLong(int max) => 'Use $max characters or fewer.';
  @override
  String groupLabel(String group) => group;
  @override
  String newGroup(String group) => 'New ${group.toLowerCase()}';
  @override
  String newGroupName(String group) => '$group name';
  @override
  String get childLabel => 'Child';
  @override
  String get childHelp =>
      'Children have no account. Only a parent or guardian linked to their '
      'group, or an organizer, can add or change them.';
  @override
  String get birthDateLabel => 'Birth date (private)';
  @override
  String get birthDateHelp =>
      'Seen only by organizers who can read private details, and by the '
      "adults linked to this person's group. Reports show age bands.";
  @override
  String get clearBirthDate => 'Clear birth date';
  @override
  String get save => 'Save';
  @override
  String get saved => 'Saved';
  @override
  String get saveFailed =>
      "Couldn't save. Your changes are still here, so try again.";
  @override
  String get delete => 'Remove';
  @override
  String deleteTitle(String name) => 'Remove $name?';
  @override
  String get deleteBody =>
      'They will no longer be counted for this event. This cannot be undone.';
  @override
  String get deleted => 'Removed';
  @override
  String get deleteFailed => "Couldn't remove. Try again.";
  @override
  String notFound(String participant) =>
      'This ${participant.toLowerCase()} no longer exists.';
  @override
  String get readOnly => 'You can see this person, but not change them.';
  @override
  String groupSearchHint(String groups) =>
      'Search ${groups.toLowerCase()} by name';
  @override
  String noGroupsFound(String groups) => 'No ${groups.toLowerCase()} found';
  @override
  String groupNameLabel(String group) => '$group name';
  @override
  String get rename => 'Save name';
  @override
  String get adultsHeading => 'Linked adults';
  @override
  String adultsHelp(String group) =>
      'Members who look after this ${group.toLowerCase()}. They can see it '
      'and add or change its people, including children.';
  @override
  String get noMembers => 'No members to link yet.';
  @override
  String deleteGroupTitle(String name) => 'Delete $name?';
  @override
  String deleteGroupBody(String group) =>
      'Only an empty ${group.toLowerCase()} can be deleted. Its linked adults '
      'are unlinked.';
  @override
  String get groupSaved => 'Saved';
  @override
  String get groupDeleted => 'Deleted';
  @override
  String get groupSaveFailed => "Couldn't save. Try again.";
}

/// The roster import screen (Req 44, 45, 75).
abstract class ImportStrings {
  const ImportStrings();

  String title(String participants);
  String get rosterAction;
  String get intro;
  String get needsConnection;
  String get pick;
  String get pickAnother;
  String fileSummary(String name, int rows);
  String get unreadable;
  String get mappingHeading;
  String get mappingHelp;
  String targetName(String target, String Function(String) fieldLabel);
  String get nameNotMapped;
  String requiredNotMapped(String label);
  String get check;
  String get uploadFailed;
  String get retry;
  String get queued;
  String progress(int processed, int total);
  String get checking;
  String reportSummary(int total, int valid, int errors);
  String willCreate(int creates, int updates, int newGroups, String groups);
  String imported(int creates, int updates);
  String get errorsHeading;
  String rowError(int row, String column, String problem);
  String moreErrors(int more);
  String problemName(String problem);
  String get apply;
  String get applyHelp;
  String get done;
  String failed(String? reason);
  String missingHeading(String groups);
  String missingHelp(String groups);
  String missingPeople(int people);
  String get cancelMissing;
  String cancelled(int groups);
  String get cancelFailed;
  String get recentHeading;
  String statusName(String status);
  String get startOver;
}

class _EnglishImportStrings extends ImportStrings {
  const _EnglishImportStrings();

  @override
  String title(String participants) => 'Import ${participants.toLowerCase()}';
  @override
  String get rosterAction => 'Import from CSV';
  @override
  String get intro =>
      'Bring in a list from a spreadsheet or another tool. You choose what '
      'each column holds, and see what will change before anything is saved. '
      'Importing the same list again updates it and adds nobody twice.';
  @override
  String get needsConnection =>
      'Importing needs a connection. It runs on our servers, so once it has '
      'started you can leave and come back.';
  @override
  String get pick => 'Choose a CSV file';
  @override
  String get pickAnother => 'Choose another file';
  @override
  String fileSummary(String name, int rows) =>
      '$name · ${rows == 1 ? '1 row' : '$rows rows'}';
  @override
  String get unreadable =>
      "This file can't be read as CSV. Save it from your spreadsheet as CSV "
      'and try again.';
  @override
  String get mappingHeading => 'What each column holds';
  @override
  String get mappingHelp => 'Columns left as Not imported are skipped.';
  @override
  String targetName(String target, String Function(String) fieldLabel) =>
      switch (target) {
        'ignore' => 'Not imported',
        'name' => 'Name',
        'group' => 'Group',
        'externalId' => 'ID from the other tool',
        'birthDate' => 'Birth date (private)',
        'age' => 'Age',
        'isChild' => 'Child (yes or no)',
        'category' => 'Category',
        'email' => 'Email (private)',
        'phone' => 'Phone (private)',
        _ when target.startsWith('field:') => fieldLabel(target.substring(6)),
        _ => target,
      };
  @override
  String get nameNotMapped => 'Choose the column that holds names.';
  @override
  String requiredNotMapped(String label) =>
      '$label is required, but no column holds it, so it stays empty.';
  @override
  String get check => 'Check the file';
  @override
  String get uploadFailed =>
      "Couldn't upload the file. Importing needs a connection, so check yours "
      'and try again.';
  @override
  String get retry => 'Try again';
  @override
  String get queued => 'Waiting to start…';
  @override
  String progress(int processed, int total) => '$processed of $total saved';
  @override
  String get checking => 'Checking every row…';
  @override
  String reportSummary(int total, int valid, int errors) =>
      '$valid of $total rows are ready${errors == 0 ? '' : ', $errors need fixing'}.';
  @override
  String willCreate(int creates, int updates, int newGroups, String groups) =>
      'Importing adds $creates, updates $updates and creates $newGroups new '
      '${groups.toLowerCase()}.';
  @override
  String imported(int creates, int updates) =>
      'Imported: $creates added and $updates updated.';
  @override
  String get errorsHeading => 'Rows that will be skipped';
  @override
  String rowError(int row, String column, String problem) =>
      'Row $row, $column: $problem';
  @override
  String moreErrors(int more) => 'And $more more.';
  @override
  String problemName(String problem) => switch (problem) {
    'required' => 'missing',
    'unknownAge' => 'not a date or age we can read',
    'duplicateEmail' => 'the same email as an earlier row',
    'badEmail' => 'not an email address',
    'badPhone' => 'not a whole phone number',
    'notAnOption' => 'not one of the choices',
    'wrongType' => 'not the right kind of answer',
    'tooLong' => 'too long',
    'duplicateRow' => 'the same person as an earlier row',
    'unknownCategory' => 'not a category of this event',
    _ => problem,
  };
  @override
  String get apply => 'Import the ready rows';
  @override
  String get applyHelp =>
      'Skipped rows are not saved. Fix them in the file and import again.';
  @override
  String get done => 'Done';
  @override
  String failed(String? reason) => switch (reason) {
    'unreadable' => unreadable,
    'tooManyRows' =>
      'This file has more than 20,000 rows. Split it and try again.',
    _ => "The import couldn't finish. Try again.",
  };
  @override
  String missingHeading(String groups) => '$groups missing from this file';
  @override
  String missingHelp(String groups) =>
      'They were imported before but are not in this file, which may mean '
      'they cancelled. Confirm to stop counting them. Their records are kept.';
  @override
  String missingPeople(int people) =>
      people == 1 ? '1 person' : '$people people';
  @override
  String get cancelMissing => 'Mark as cancelled';
  @override
  String cancelled(int groups) =>
      groups == 1 ? '1 marked as cancelled' : '$groups marked as cancelled';
  @override
  String get cancelFailed => "Couldn't mark them as cancelled. Try again.";
  @override
  String get recentHeading => 'Recent imports';
  @override
  String statusName(String status) => switch (status) {
    'queued' || 'running' => 'In progress',
    'checked' => 'Checked, not imported',
    'done' => 'Imported',
    'failed' => 'Failed',
    _ => status,
  };
  @override
  String get startOver => 'Start a new import';
}

/// The Fields screen, field and category editors, and answers (Req 41, 42).
abstract class FieldStrings {
  const FieldStrings();

  String title(String fields, String categories);
  String get settingsEntry;
  String get settingsEntryHelp;
  String fieldsHeading(String fields);
  String fieldsEmpty(String fields);
  String addField(String field);
  String newField(String field);
  String get labelLabel;
  String get labelRequired;
  String get typeLabel;
  String typeName(FieldType type);
  String get optionsLabel;
  String get optionsHelp;
  String get optionsRequired;
  String get requiredLabel;
  String scopeLabel(String participant, String group);
  String scopeName(FieldScope scope, String participant, String group);
  String get visibilityLabel;
  String get visibilityStandard;
  String get visibilityStandardHelp;
  String get visibilityPrivate;
  String get visibilityPrivateHelp;
  String fieldSummary(CustomField field, String participant, String group);
  String categoriesHeading(String categories);
  String categoriesHelp(String categories);
  String categoriesEmpty(String categories);
  String addCategory(String category);
  String get childAdultPreset;
  String get nameLabel;
  String get minAgeLabel;
  String get maxAgeLabel;
  String get agesHelp;
  String get ageInvalid;
  String get childLabel;
  String categorySummary(EventCategory category);
  String get save;
  String get saved;
  String get saveFailed;
  String get delete;
  String deleteTitle(String name);
  String get deleteBody;
  String get yes;
  String get no;
  String get answerRequired;
  String get answerWrong;
  String get answerTooLong;
  String get privateBadge;
  String categoryLabel(String category);
  String derivedCategory(String name);
  String get noCategory;
  String filterByField(String field);
  String filterByCategory(String category);
  String get pickValue;
  String get chooseDate;
}

class _EnglishFieldStrings extends FieldStrings {
  const _EnglishFieldStrings();

  @override
  String title(String fields, String categories) => '$fields and $categories';
  @override
  String get settingsEntry => 'Custom fields and categories';
  @override
  String get settingsEntryHelp =>
      'Questions to ask attendees, such as a diet, and groupings such as '
      'Child and Adult.';
  @override
  String fieldsHeading(String fields) => fields;
  @override
  String fieldsEmpty(String fields) =>
      'No ${fields.toLowerCase()} yet. Add one to ask attendees something, '
      'such as a diet or a T-shirt size.';
  @override
  String addField(String field) => 'Add ${field.toLowerCase()}';
  @override
  String newField(String field) => 'New ${field.toLowerCase()}';
  @override
  String get labelLabel => 'Question';
  @override
  String get labelRequired => 'Enter the question.';
  @override
  String get typeLabel => 'Answer type';
  @override
  String typeName(FieldType type) => switch (type) {
    FieldType.text => 'Text',
    FieldType.number => 'Number',
    FieldType.date => 'Date',
    FieldType.singleChoice => 'One choice',
    FieldType.multiChoice => 'Several choices',
    FieldType.yesNo => 'Yes or no',
  };
  @override
  String get optionsLabel => 'Choices';
  @override
  String get optionsHelp => 'One per line.';
  @override
  String get optionsRequired => 'Add at least one choice.';
  @override
  String get requiredLabel => 'Required';
  @override
  String scopeLabel(String participant, String group) =>
      'Asked once per ${participant.toLowerCase()} or per ${group.toLowerCase()}';
  @override
  String scopeName(FieldScope scope, String participant, String group) =>
      switch (scope) {
        FieldScope.participant => 'Each ${participant.toLowerCase()}',
        FieldScope.group => 'Each ${group.toLowerCase()}',
      };
  @override
  String get visibilityLabel => 'Who sees the answer';
  @override
  String get visibilityStandard => 'Standard';
  @override
  String get visibilityStandardHelp =>
      'Anyone who can see the person, and it can filter the list.';
  @override
  String get visibilityPrivate => 'Private';
  @override
  String get visibilityPrivateHelp =>
      'Only organizers who can read private details, and the adults linked to '
      'the group. Never used for filtering.';
  @override
  String fieldSummary(CustomField field, String participant, String group) => [
    typeName(field.type),
    scopeName(field.scope, participant, group),
    if (field.required) 'Required',
    if (field.isPrivate) 'Private',
  ].join(' · ');
  @override
  String categoriesHeading(String categories) => categories;
  @override
  String categoriesHelp(String categories) =>
      '$categories with ages are worked out from a birth date on the first '
      'day of the event. Others are picked by hand.';
  @override
  String categoriesEmpty(String categories) =>
      'No ${categories.toLowerCase()} yet.';
  @override
  String addCategory(String category) => 'Add ${category.toLowerCase()}';
  @override
  String get childAdultPreset => 'Add Child (up to 17) and Adult (18 and up)';
  @override
  String get nameLabel => 'Name';
  @override
  String get minAgeLabel => 'From age (optional)';
  @override
  String get maxAgeLabel => 'Up to age (optional)';
  @override
  String get agesHelp => 'Ages on the first day of the event, in whole years.';
  @override
  String get ageInvalid => 'Use a whole number from 0 to 130.';
  @override
  String get childLabel => 'Counts as a child';
  @override
  String categorySummary(EventCategory category) {
    final min = category.minAge;
    final max = category.maxAge;
    final ages = switch ((min, max)) {
      (null, null) => 'Picked by hand',
      (final a?, null) => '$a and older',
      (null, final b?) => 'Up to $b',
      (final a?, final b?) => '$a to $b',
    };
    return [ages, if (category.isChild) 'Child'].join(' · ');
  }

  @override
  String get save => 'Save';
  @override
  String get saved => 'Saved';
  @override
  String get saveFailed =>
      "Couldn't save. Your changes are still here, so try again.";
  @override
  String get delete => 'Delete';
  @override
  String deleteTitle(String name) => 'Delete $name?';
  @override
  String get deleteBody =>
      'Answers already given stay on people, but are no longer shown.';
  @override
  String get yes => 'Yes';
  @override
  String get no => 'No';
  @override
  String get answerRequired => 'This is required.';
  @override
  String get answerWrong => 'That answer does not fit this question.';
  @override
  String get answerTooLong => 'Use 500 characters or fewer.';
  @override
  String get privateBadge => 'Private';
  @override
  String categoryLabel(String category) => category;
  @override
  String derivedCategory(String name) => '$name, from the birth date';
  @override
  String get noCategory => 'None';
  @override
  String filterByField(String field) => 'Filter by ${field.toLowerCase()}';
  @override
  String filterByCategory(String category) =>
      'Filter by ${category.toLowerCase()}';
  @override
  String get pickValue => 'Choose an answer';
  @override
  String get chooseDate => 'Choose a date';
}

/// The Expense access screen and its Event settings entry (Req 38).
abstract class ExpenseAccessStrings {
  const ExpenseAccessStrings();

  String get title;
  String get intro;
  String get everyone;
  String get everyoneHelp;
  String includeNonContributors(String observers, String vendors);
  String get involved;
  String get involvedHelp;
  String get selected;
  String get selectedHelp;
  String get rolesHeading;
  String get peopleHeading;
  String get nobodyNote;
  String get nothingToPick;
  String get save;
  String get saved;
  String get saveFailed;
  String get narrowTitle;
  String narrowBody(int people);
  String get narrowConfirm;

  /// The Event settings entry's summary of the current option.
  String summary(ExpenseAccessMode mode, {required bool includesEveryone});
}

class _EnglishExpenseAccessStrings extends ExpenseAccessStrings {
  const _EnglishExpenseAccessStrings();

  @override
  String get title => 'Who can see expenses';
  @override
  String get intro =>
      'People always see expenses they paid for or share in, and people '
      'whose role can read money see every expense.';
  @override
  String get everyone => 'Everyone in the event';
  @override
  String get everyoneHelp => 'Every member sees every expense.';
  @override
  String includeNonContributors(String observers, String vendors) =>
      'Also show $observers and $vendors';
  @override
  String get involved => 'Only people involved';
  @override
  String get involvedHelp =>
      'Members see only expenses they paid for or are part of. Everyone '
      'still sees their own balance and who to pay.';
  @override
  String get selected => 'Selected roles and people';
  @override
  String get selectedHelp =>
      'Only the roles and people you pick see every '
      'expense.';
  @override
  String get rolesHeading => 'Roles';
  @override
  String get peopleHeading => 'People';
  @override
  String get nobodyNote =>
      'Nobody picked. People whose role can read money still see every '
      'expense.';
  @override
  String get nothingToPick => 'Everyone here already sees every expense.';
  @override
  String get save => 'Save';
  @override
  String get saved => 'Saved';
  @override
  String get saveFailed =>
      'Could not save. Check your connection and try again.';
  @override
  String get narrowTitle => 'Fewer people will see expenses';
  @override
  String narrowBody(int people) =>
      '${people == 1 ? '1 person' : '$people people'} will no longer see '
      'every expense. They will still see the ones they paid for or share in.';
  @override
  String get narrowConfirm => 'Save anyway';
  @override
  String summary(ExpenseAccessMode mode, {required bool includesEveryone}) =>
      switch (mode) {
        ExpenseAccessMode.everyone =>
          includesEveryone
              ? 'Everyone, including Observers and Vendors'
              : everyone,
        ExpenseAccessMode.involved => involved,
        ExpenseAccessMode.selected => selected,
      };
}

abstract class CrewStrings {
  const CrewStrings();

  String emptyTitle(String crews);
  String get emptyHint;
  String newCrew(String crew);
  String get nameLabel;
  String get nameRequired;
  String nameTooLong(int max);
  String get create;
  String get rename;
  String get save;
  String get cancel;
  String get delete;
  String deleteTitle(String name);
  String deleteBody(String crew);
  String get saved;
  String get deleted;
  String get saveFailed;
  String get deleteFailed;
  String membersTitle(String name);
  String get membersSaved;
  String get noMembers;
  String get readOnly;
  String get crewOptions;

  /// The task field's label and its empty choice.
  String noCrew(String crew);
  String allCrews(String crews);
}

class _EnglishCrewStrings extends CrewStrings {
  const _EnglishCrewStrings();

  @override
  String emptyTitle(String crews) => 'No ${crews.toLowerCase()} yet';
  @override
  String get emptyHint =>
      'Make one for each team, such as food or registration, then put people '
      'in it and give it tasks.';
  @override
  String newCrew(String crew) => 'New ${crew.toLowerCase()}';
  @override
  String get nameLabel => 'Name';
  @override
  String get nameRequired => 'Give it a name.';
  @override
  String nameTooLong(int max) => 'Use $max characters or fewer.';
  @override
  String get create => 'Create';
  @override
  String get rename => 'Rename';
  @override
  String get save => 'Save';
  @override
  String get cancel => 'Cancel';
  @override
  String get delete => 'Delete';
  @override
  String deleteTitle(String name) => 'Delete $name?';
  @override
  String deleteBody(String crew) =>
      'Everyone stays in the event, and its tasks stay with no '
      '${crew.toLowerCase()}.';
  @override
  String get saved => 'Saved';
  @override
  String get deleted => 'Deleted';
  @override
  String get saveFailed =>
      "Couldn't save. Your changes are still here, so try again.";
  @override
  String get deleteFailed => "Couldn't delete. Try again.";
  @override
  String membersTitle(String name) => 'Who is in $name';
  @override
  String get membersSaved => 'Saved';
  @override
  String get noMembers => 'Nobody yet';
  @override
  String get readOnly => 'Only people who manage members can change these.';
  @override
  String get crewOptions => 'More options';
  @override
  String noCrew(String crew) => 'No ${crew.toLowerCase()}';
  @override
  String allCrews(String crews) => 'All ${crews.toLowerCase()}';
}

/// The Transfer ownership screen and offer banner (#69).
abstract class TransferStrings {
  const TransferStrings();

  String get title;
  String currentOwner(String name);
  String get pickHeading;
  String get pickHint;
  String get offer;
  String offerTitle(String name);
  String get offerBody;
  String get offered;
  String waiting(String name);
  String get withdraw;
  String get withdrawn;
  String offerToYou(String from);
  String offerToYouBody(String from);
  String get accept;
  String get decline;
  String get accepted;
  String get declined;
  String get failed;
  String get noOneElse;
  String get noAccessBody;
  String get open;
  String get you;
  String get bannerBody;
}

class _EnglishTransferStrings extends TransferStrings {
  const _EnglishTransferStrings();

  @override
  String get title => 'Transfer ownership';
  @override
  String currentOwner(String name) => 'Owner: $name';
  @override
  String get pickHeading => 'Who should be the new Owner?';
  @override
  String get pickHint =>
      'They must accept it. Until then nothing changes, and you can withdraw '
      'the offer.';
  @override
  String get offer => 'Offer ownership';
  @override
  String offerTitle(String name) => 'Offer ownership to $name?';
  @override
  String get offerBody =>
      'Once they accept, they become the Owner and you become a Co-owner. '
      'They can give it back the same way.';
  @override
  String get offered => 'Offer sent';
  @override
  String waiting(String name) => 'Waiting for $name to accept.';
  @override
  String get withdraw => 'Withdraw offer';
  @override
  String get withdrawn => 'Offer withdrawn';
  @override
  String offerToYou(String from) => '$from wants to make you the Owner';
  @override
  String offerToYouBody(String from) =>
      'As Owner you can do everything, including handing ownership on. '
      '$from becomes a Co-owner.';
  @override
  String get accept => 'Accept';
  @override
  String get decline => 'Decline';
  @override
  String get accepted => "You're now the Owner";
  @override
  String get declined => 'Offer declined';
  @override
  String get failed => "Couldn't do that. Check your connection and try again.";
  @override
  String get noOneElse =>
      'There is nobody else in this event yet. Invite someone first.';
  @override
  String get noAccessBody =>
      'Only the Owner, Co-owners and the person offered ownership can see '
      'this page.';
  @override
  String get open => 'View';
  @override
  String get you => 'You';
  @override
  String get bannerBody => "You've been offered ownership of this event.";
}

/// Linking accounts to participant records (Req 46, 14a).
abstract class LinkStrings {
  const LinkStrings();

  /// Shown on the roster to organizers.
  String waiting(int count);
  String get openWaiting;
  String get title;
  String get intro;
  String get empty;
  String get loadFailed;
  String get retry;
  String get offline;
  String accountLine(String? name, String contact);
  String get pickRecord;
  String asAdultOf(String group);
  String get onlyChildren;
  String get link;
  String get notAMatch;
  String get linkFailed;
  String get linkedDone;
  String get dismissedDone;
  String get childTag;

  /// After sign-in links someone (Req 46).
  String linkedToast(int events);

  /// A record left by a deleted account (Req 14a).
  String get unnamed;
  String get unnamedHint;

  /// The linked person's own record, when they see no group.
  String get yourRecord;
}

class _EnglishLinkStrings extends LinkStrings {
  const _EnglishLinkStrings();

  @override
  String waiting(int count) => count == 1
      ? '1 person is waiting to be linked to their record.'
      : '$count people are waiting to be linked to their records.';
  @override
  String get openWaiting => 'Review';
  @override
  String get title => 'Link accounts';
  @override
  String get intro =>
      'These people signed in with a verified email that matches more than '
      'one adult, or only children. Pick who they are, or say it is not a '
      'match.';
  @override
  String get empty => 'Nobody is waiting to be linked.';
  @override
  String get loadFailed => "Couldn't load these. Check your connection.";
  @override
  String get retry => 'Try again';
  @override
  String get offline => 'Linking needs a connection.';
  @override
  String accountLine(String? name, String contact) =>
      name == null || name.isEmpty ? contact : '$name · $contact';
  @override
  String get pickRecord => 'Who is this?';
  @override
  String asAdultOf(String group) => 'An adult looking after $group';
  @override
  String get onlyChildren =>
      'Only children carry this email, and a child is never linked to an '
      'account. Link this person as an adult of the group instead.';
  @override
  String get link => 'Link';
  @override
  String get notAMatch => 'Not a match';
  @override
  String get linkFailed =>
      "Couldn't save that. Check your connection and try again.";
  @override
  String get linkedDone => 'Linked.';
  @override
  String get dismissedDone => 'Marked as not a match.';
  @override
  String get childTag => 'Child';
  @override
  String linkedToast(int events) => events == 1
      ? "You've been linked to your registration in 1 event."
      : "You've been linked to your registration in $events events.";
  @override
  String get unnamed => 'Unnamed person';
  @override
  String get unnamedHint =>
      'Their account was deleted. Kept only so counts stay right.';
  @override
  String get yourRecord => 'Your record';
}

/// Member invite links and their QR codes (Req 47, 56; Spec #233 Req 15,
/// #238), and `/join/:code`. Translated: read from the ARB files.
abstract class InviteStrings {
  const InviteStrings();

  String get loading;
  String get offline;
  String get permissionDenied;
  String get eventGone;
  String get failed;
  String get retry;
  String get shareHint;
  String get newLink;
  String get noLinks;
  String get linkLabel;
  String get codeLabel;
  String qrLabel(String link);
  String get showQr;
  String expires(String when);
  String expiredOn(String when);
  String get noExpiry;
  String get changeExpiry;
  String get expiryDefault;
  String get pickDate;
  String get copyLink;
  String get copied;
  String get share;
  String shareText(String title, String link, String code);
  String get singleUse;
  String get singleUseHelp;
  String get manyUse;
  String uses(int count);
  String get turnOff;
  String get turnOffTitle;
  String get turnOffMessage;
  String get cancel;
  String get turnedOff;
  String get newLinkTitle;
  String get expiryLabel;
  String get create;
  String get linkUsed;
  String get linkOff;
  String get linkExpired;
  String get joinTitle;
  String get joinNeedsConnection;
  String get joinLoading;
  String joinAs(String role);
  String startsOn(String date);
  String get joinButton;
  String get joined;
  String get notFound;
  String get notOpenDraft;
  String get notOpenEnded;
  String get full;
  String get alreadyMember;
  String get openEvent;
  String get joinFailed;
  String get backToEvents;

  /// An expiry choice by its `InviteExpiry` name.
  String expiryChoice(String choice);

  /// A link's state by its `InviteLinkState` name.
  String state(String state);

  /// Why a link cannot be used, by the server's reason (`used`, `off`,
  /// `expired`), or [notFound] for anything else.
  String unusable(String? reason) => switch (reason) {
    'used' => linkUsed,
    'off' => linkOff,
    'expired' => linkExpired,
    _ => notFound,
  };
}

class _ArbInviteStrings extends InviteStrings {
  const _ArbInviteStrings(this._l);

  final AppLocalizations _l;

  @override
  String get loading => _l.inviteLoading;
  @override
  String get offline => _l.inviteOffline;
  @override
  String get permissionDenied => _l.invitePermissionDenied;
  @override
  String get eventGone => _l.inviteEventGone;
  @override
  String get failed => _l.inviteFailed;
  @override
  String get retry => _l.inviteRetry;
  @override
  String get shareHint => _l.inviteShareHint;
  @override
  String get newLink => _l.inviteNewLink;
  @override
  String get noLinks => _l.inviteNoLinks;
  @override
  String get linkLabel => _l.inviteLinkLabel;
  @override
  String get codeLabel => _l.inviteCodeLabel;
  @override
  String qrLabel(String link) => _l.inviteQrLabel(link);
  @override
  String get showQr => _l.inviteShowQr;
  @override
  String expires(String when) => _l.inviteExpires(when);
  @override
  String expiredOn(String when) => _l.inviteExpiredOn(when);
  @override
  String get noExpiry => _l.inviteNoExpiry;
  @override
  String get changeExpiry => _l.inviteChangeExpiry;
  @override
  String get expiryDefault => _l.inviteExpiryDefault;
  @override
  String get pickDate => _l.invitePickDate;
  @override
  String get copyLink => _l.inviteCopyLink;
  @override
  String get copied => _l.inviteCopied;
  @override
  String get share => _l.inviteShare;
  @override
  String shareText(String title, String link, String code) =>
      _l.inviteShareText(title, link, code);
  @override
  String get singleUse => _l.inviteSingleUse;
  @override
  String get singleUseHelp => _l.inviteSingleUseHelp;
  @override
  String get manyUse => _l.inviteManyUse;
  @override
  String uses(int count) => _l.inviteUses(count);
  @override
  String get turnOff => _l.inviteTurnOff;
  @override
  String get turnOffTitle => _l.inviteTurnOffTitle;
  @override
  String get turnOffMessage => _l.inviteTurnOffMessage;
  @override
  String get cancel => _l.inviteCancel;
  @override
  String get turnedOff => _l.inviteTurnedOff;
  @override
  String get newLinkTitle => _l.inviteNewLinkTitle;
  @override
  String get expiryLabel => _l.inviteExpiryLabel;
  @override
  String get create => _l.inviteCreate;
  @override
  String get linkUsed => _l.inviteLinkUsed;
  @override
  String get linkOff => _l.inviteLinkOff;
  @override
  String get linkExpired => _l.inviteLinkExpired;
  @override
  String get joinTitle => _l.inviteJoinTitle;
  @override
  String get joinNeedsConnection => _l.inviteJoinNeedsConnection;
  @override
  String get joinLoading => _l.inviteJoinLoading;
  @override
  String joinAs(String role) => _l.inviteJoinAs(role);
  @override
  String startsOn(String date) => _l.inviteStartsOn(date);
  @override
  String get joinButton => _l.inviteJoinButton;
  @override
  String get joined => _l.inviteJoined;
  @override
  String get notFound => _l.inviteNotFound;
  @override
  String get notOpenDraft => _l.inviteNotOpenDraft;
  @override
  String get notOpenEnded => _l.inviteNotOpenEnded;
  @override
  String get full => _l.inviteFull;
  @override
  String get alreadyMember => _l.inviteAlreadyMember;
  @override
  String get openEvent => _l.inviteOpenEvent;
  @override
  String get joinFailed => _l.inviteJoinFailed;
  @override
  String get backToEvents => _l.inviteBackToEvents;
  @override
  String expiryChoice(String choice) => switch (choice) {
    'day' => _l.inviteExpiryDay,
    'week' => _l.inviteExpiryWeek,
    'month' => _l.inviteExpiryMonth,
    'eventStart' => _l.inviteExpiryEventStart,
    'eventEnd' => _l.inviteExpiryEventEnd,
    _ => choice,
  };
  @override
  String state(String state) => switch (state) {
    'used' => _l.inviteStateUsed,
    'expired' => _l.inviteStateExpired,
    'off' => _l.inviteStateOff,
    _ => _l.inviteStateActive,
  };
}

/// The paged member picker, task assignee and expense split (Req 43a).
/// [member] and [members] are the event's own words, from `event.words`.
abstract class MemberPickerStrings {
  const MemberPickerStrings();

  String chooseOne(String member);
  String chooseMany(String members);
  String search(String members);
  String get showMore;
  String get loadFailed;
  String get retry;
  String noneFound(String members);
  String noneYet(String members);
  String done(int count);
  String get noName;
  String you(String name);

  String get assignee;
  String get unassigned;
  String leftEvent(String name);
  String get clearAssignee;

  String get splitHeading;
  String splitEveryone(int count);
  String splitChosen(int count);
  String get choosePeople;
  String get splitUseEveryone;
  String splitMustChoose(int limit);
  String get splitNoneChosen;

  /// The button that takes someone off a chosen list.
  String removePerson(String name);
}

class _EnglishMemberPickerStrings extends MemberPickerStrings {
  const _EnglishMemberPickerStrings();

  @override
  String removePerson(String name) => 'Remove $name';

  @override
  String chooseOne(String member) => 'Choose a ${member.toLowerCase()}';
  @override
  String chooseMany(String members) => 'Choose ${members.toLowerCase()}';
  @override
  String search(String members) => 'Search ${members.toLowerCase()} by name';
  @override
  String get showMore => 'Show more';
  @override
  String get loadFailed =>
      "Couldn't load the list. Check your connection and try again.";
  @override
  String get retry => 'Try again';
  @override
  String noneFound(String members) =>
      'No ${members.toLowerCase()} have a name starting with that.';
  @override
  String noneYet(String members) => 'No ${members.toLowerCase()} yet.';
  @override
  String done(int count) => count == 0 ? 'Done' : 'Done ($count)';
  @override
  String get noName => 'No name yet';
  @override
  String you(String name) => '$name (you)';

  @override
  String get assignee => 'Assignee';
  @override
  String get unassigned => 'Unassigned';
  @override
  String leftEvent(String name) => '$name (no longer in event)';
  @override
  String get clearAssignee => 'Clear assignee';

  @override
  String get splitHeading => 'Split between';
  @override
  String splitEveryone(int count) => 'Everyone ($count)';
  @override
  String splitChosen(int count) =>
      count == 1 ? '1 person chosen' : '$count people chosen';
  @override
  String get choosePeople => 'Choose people';
  @override
  String get splitUseEveryone => 'Split with everyone';
  @override
  String splitMustChoose(int limit) =>
      'With more than $limit people in this event, choose who shares this cost.';
  @override
  String get splitNoneChosen =>
      'Choose at least one person to share this cost.';
}

/// The schedule and venues (#81, Req 48, 49). Session words come from the
/// event's labels.
abstract class ScheduleStrings {
  const ScheduleStrings();

  String get title;
  String get hubSubtitle;
  String get byDay;
  String get byVenue;

  /// Above By day and By venue at large text sizes.
  String get viewLabel;
  String add(String session);
  String noneYet(String sessions);
  String get noneYetEditorHint;
  String get loadFailed;
  String get retry;
  String get timeTbc;
  String get locationTba;
  String get addressTba;
  String get noVenue;
  String get hidden;

  /// The tag on a hidden session in the list.
  String get hiddenDraft;

  /// The tag on a session open to everyone.
  String get everyone;

  /// A day's button above the list, read aloud, such as "Go to Saturday, July 17".
  String goToDay(String day);
  String get openMap;
  String get directions;
  String capacity(int count);
  String get forEveryone;
  String forOnly(String who);
  String get missing;

  String editTitle(String session);
  String newTitle(String session);
  String get titleLabel;
  String get titleRequired;
  String get dayLabel;
  String get dayRequired;
  String get startLabel;
  String get startRequired;
  String get endLabel;
  String get endNextDay;
  String get clearEnd;
  String get timeTbcLabel;
  String get timeTbcHelp;
  String get venueLabel;
  String get venueNone;
  String get venueHelpNoVenues;
  String get locationTbaLabel;
  String get typeLabel;
  String get typeHelp;
  String get tagsLabel;
  String get tagAdd;
  String removeTag(String tag);
  String get capacityLabel;
  String get capacityInvalid;
  String get eligibilityLabel;
  String get eligibilityHelp;
  String get eligibilityNone;
  String get hiddenLabel;
  String get hiddenHelp;
  String get save;
  String get saved;
  String get pending;
  String get saveFailed;
  String get delete;
  String deleteTitle(String session);
  String get deleteBody;
  String get deleteFailed;
  String get cancel;
  String get discardTitle;
  String get discardBody;
  String get keepEditing;
  String get discard;

  String get venueMapLabel;
  String get venueMapInvalid;
  String get venueDirectionsLabel;
  String get venueAddressHelp;
}

class _EnglishScheduleStrings extends ScheduleStrings {
  const _EnglishScheduleStrings();

  @override
  String get title => 'Schedule';
  @override
  String get hubSubtitle => 'Days, times & venues';
  @override
  String get byDay => 'By day';
  @override
  String get byVenue => 'By venue';
  @override
  String get viewLabel => 'Show';
  @override
  String add(String session) => 'Add ${session.toLowerCase()}';
  @override
  String noneYet(String sessions) => 'No ${sessions.toLowerCase()} yet.';
  @override
  String get noneYetEditorHint => 'Add the first one to start the schedule.';
  @override
  String get loadFailed =>
      "Couldn't load the schedule. Check your connection and try again.";
  @override
  String get retry => 'Try again';
  @override
  String get timeTbc => 'Time to be confirmed';
  @override
  String get locationTba => 'Location to be announced';
  @override
  String get addressTba => 'Address to be announced';
  @override
  String get noVenue => 'No venue set';
  @override
  String get hidden => 'Hidden';
  @override
  String get hiddenDraft => 'Hidden draft';
  @override
  String get everyone => 'Everyone';
  @override
  String goToDay(String day) => 'Go to $day';
  @override
  String get openMap => 'Open map';
  @override
  String get directions => 'Directions';
  @override
  String capacity(int count) => 'Up to $count';
  @override
  String get forEveryone => 'For everyone';
  @override
  String forOnly(String who) => 'For $who';
  @override
  String get missing => 'This is no longer on the schedule.';

  @override
  String editTitle(String session) => 'Edit ${session.toLowerCase()}';
  @override
  String newTitle(String session) => 'New ${session.toLowerCase()}';
  @override
  String get titleLabel => 'Title';
  @override
  String get titleRequired => 'Enter a title.';
  @override
  String get dayLabel => 'Day';
  @override
  String get dayRequired => 'Choose a day.';
  @override
  String get startLabel => 'Starts';
  @override
  String get startRequired => 'Choose a start time.';
  @override
  String get endLabel => 'Ends (optional)';
  @override
  String get endNextDay => 'Ends the next day';
  @override
  String get clearEnd => 'Clear end time';
  @override
  String get timeTbcLabel => 'Time to be confirmed';
  @override
  String get timeTbcHelp => 'Shown as a placeholder until you confirm it.';
  @override
  String get venueLabel => 'Venue';
  @override
  String get venueNone => 'No venue';
  @override
  String get venueHelpNoVenues => 'Add venues in event settings.';
  @override
  String get locationTbaLabel => 'Location to be announced';
  @override
  String get typeLabel => 'Type (optional)';
  @override
  String get typeHelp =>
      'Any words you like. Types already used are suggested.';
  @override
  String get tagsLabel => 'Tags';
  @override
  String get tagAdd => 'Add tag';
  @override
  String removeTag(String tag) => 'Remove $tag';
  @override
  String get capacityLabel => 'Capacity (optional)';
  @override
  String get capacityInvalid => 'Enter a whole number above 0.';
  @override
  String get eligibilityLabel => 'Who it is for';
  @override
  String get eligibilityHelp =>
      'Choose nothing for everyone. With both kinds chosen, people need one of each.';
  @override
  String get eligibilityNone =>
      'Everyone. Add categories or choice fields to limit who it is for.';
  @override
  String get hiddenLabel => 'Hidden from members';
  @override
  String get hiddenHelp => 'Only people who edit the schedule see it.';
  @override
  String get save => 'Save';
  @override
  String get saved => 'Saved';
  @override
  String get pending =>
      "Saved on this device. It will be sent when you're back online.";
  @override
  String get saveFailed =>
      "Couldn't save. Your changes are kept, so try again.";
  @override
  String get delete => 'Delete';
  @override
  String deleteTitle(String session) => 'Delete this ${session.toLowerCase()}?';
  @override
  String get deleteBody => 'It is removed from everyone\'s schedule.';
  @override
  String get deleteFailed => "Couldn't delete. Try again.";
  @override
  String get cancel => 'Cancel';
  @override
  String get discardTitle => 'Discard changes?';
  @override
  String get discardBody => 'What you entered here will be lost.';
  @override
  String get keepEditing => 'Keep editing';
  @override
  String get discard => 'Discard';

  @override
  String get venueMapLabel => 'Map link (optional)';
  @override
  String get venueMapInvalid => 'Enter a link starting with https://';
  @override
  String get venueDirectionsLabel => 'Directions (optional)';
  @override
  String get venueAddressHelp => 'Leave empty while it is to be announced.';
}

/// Attendance, the personal agenda and now and next (#82, Req 50, 51), and
/// offline notes (Req 74).
abstract class AgendaStrings {
  const AgendaStrings();

  String get title;
  String get hubSubtitle;
  String get now;
  String get next;
  String get nothingNow;
  String get nothingNext;
  String get empty;
  String get noRecord;
  String get wholeSchedule;
  String get everyoneInGroup;
  String get loadFailed;
  String get retry;
  String offline(String? when);

  String policy(String name);
  String policyHelp(String name);
  String get policyLabel;
  String get sessionRuleLabel;
  String get sessionRuleFollow;

  String get attendanceHeading;
  String get arrivalLabel;
  String get departureLabel;
  String get clearTime;
  String get departureBeforeArrival;
  String get sessionsHeading;
  String get sessionsNone;
  String get attends;
  String get optedOut;
  String get invited;
  String get signedUp;
  String get notAttending;
  String get onlyOrganizersInvite;
  String get groupInvitations;
  String get groupInvitationsHelp;
  String get groupInvitationsSaved;
  String get groupInvitationsFailed;
}

class _EnglishAgendaStrings extends AgendaStrings {
  const _EnglishAgendaStrings();

  @override
  String get title => 'Agenda';
  @override
  String get hubSubtitle => 'Where to be, now & next';
  @override
  String get now => 'Now';
  @override
  String get next => 'Next';
  @override
  String get nothingNow => 'Nothing on right now.';
  @override
  String get nothingNext => 'Nothing else coming up.';
  @override
  String get empty => 'Nothing on your agenda yet.';
  @override
  String get noRecord =>
      "You aren't on the attendee list, so this shows the whole schedule.";
  @override
  String get wholeSchedule => 'Full schedule';
  @override
  String get everyoneInGroup => 'Everyone';
  @override
  String get loadFailed =>
      "Couldn't load your agenda. Check your connection and try again.";
  @override
  String get retry => 'Try again';
  @override
  String offline(String? when) => when == null
      ? 'Offline. Showing what was saved on this device.'
      : 'Offline. Last updated $when.';

  @override
  String policy(String name) => switch (name) {
    'arrivalToDeparture' => 'From arrival to departure',
    'invitedOnly' => 'Invited only',
    'everyone' => 'Everyone',
    'bySession' => 'Sign-up',
    _ => name,
  };
  @override
  String policyHelp(String name) => switch (name) {
    'arrivalToDeparture' =>
      'People attend what happens between their arrival and departure.',
    'invitedOnly' =>
      'People attend only what they or their group are invited to.',
    'everyone' => 'Everyone attends everything.',
    'bySession' => 'People choose what they attend. Nothing is assumed.',
    _ => '',
  };
  @override
  String get policyLabel => 'Who attends sessions';
  @override
  String get sessionRuleLabel => 'Who attends';
  @override
  String get sessionRuleFollow => "Follow the event's setting";

  @override
  String get attendanceHeading => 'Attendance';
  @override
  String get arrivalLabel => 'Arrives (optional)';
  @override
  String get departureLabel => 'Leaves (optional)';
  @override
  String get clearTime => 'Clear';
  @override
  String get departureBeforeArrival => 'Leaving must be after arriving.';
  @override
  String get sessionsHeading => 'Sessions';
  @override
  String get sessionsNone => 'Nothing is on the schedule yet.';
  @override
  String get attends => 'Attends';
  @override
  String get optedOut => 'Opted out';
  @override
  String get invited => 'Invited';
  @override
  String get signedUp => 'Signed up';
  @override
  String get notAttending => 'Not attending';
  @override
  String get onlyOrganizersInvite => 'Only organizers can invite.';
  @override
  String get groupInvitations => 'Invited to';
  @override
  String get groupInvitationsHelp => 'Everyone in this group attends these.';
  @override
  String get groupInvitationsSaved => 'Invitations saved';
  @override
  String get groupInvitationsFailed =>
      "Couldn't save the invitations. Try again.";
}

/// Counts per event and session (#83, Req 52).
abstract class CountsStrings {
  const CountsStrings();

  String get title;
  String get hubSubtitle;
  String updated(String when);
  String get recalculate;
  String get recalculating;
  String get recalculateFailed;
  String get needsConnection;
  String get recalculateHelp;
  String get notYet;
  String get notYetHelp;
  String get countNow;
  String get loadFailed;
  String get retry;
  String get wholeEvent;
  String people(int n);
  String groups(int n, String groupWord);
  String get byCategory;
  String get noCategory;
  String get noAnswer;
  String get yes;
  String get no;
  String get sessionsHeading;
  String get noSessions;
  String get removedSession;
  String capacity(int count, int? capacity);

  String get export;
  String get exportTitle;
  String get exportCounts;
  String get exportRoster;
  String get exportChanges;
  String get includePrivate;
  String get includePrivateHelp;
  String get exportFailed;
  String get exported;
  String get freeze;
  String get freezeTitle;
  String get freezeBody;
  String get freezeLabel;
  String get freezeConfirm;
  String get cancel;
  String get freezeFailed;
  String get frozenNow;
  String frozenOn(String when, String? label);
  String get changesHeading;
  String get noChanges;
  String change(String what, int before, int after);
  String get earlierFreezes;
  String get wholeEventLabel;
}

class _EnglishCountsStrings extends CountsStrings {
  const _EnglishCountsStrings();

  @override
  String get title => 'Counts';
  @override
  String get hubSubtitle => 'Headcounts by session';
  @override
  String updated(String when) => 'Last updated $when';
  @override
  String get recalculate => 'Recalculate now';
  @override
  String get recalculating => 'Counting…';
  @override
  String get recalculateFailed => "Couldn't recalculate. Try again.";
  @override
  String get needsConnection =>
      'Recalculating needs a connection. The counts shown are the last ones saved.';
  @override
  String get recalculateHelp =>
      'Counts update by themselves within a few minutes of a change.';
  @override
  String get notYet => 'Not counted yet';
  @override
  String get notYetHelp =>
      'Counts appear a few minutes after people or sessions are added, or count now.';
  @override
  String get countNow => 'Count now';
  @override
  String get loadFailed =>
      "Couldn't load the counts. Check your connection and try again.";
  @override
  String get retry => 'Try again';
  @override
  String get wholeEvent => 'Whole event';
  @override
  String people(int n) => n == 1 ? '1 person' : '$n people';
  @override
  String groups(int n, String groupWord) => '$n ${groupWord.toLowerCase()}';
  @override
  String get byCategory => 'By category';
  @override
  String get noCategory => 'No category';
  @override
  String get noAnswer => 'No answer';
  @override
  String get yes => 'Yes';
  @override
  String get no => 'No';
  @override
  String get sessionsHeading => 'By session';
  @override
  String get noSessions => 'Nothing is on the schedule yet.';
  @override
  String get removedSession => 'Removed from the schedule';
  @override
  String capacity(int count, int? capacity) =>
      capacity == null ? '$count attending' : '$count of $capacity attending';

  @override
  String get export => 'Export';
  @override
  String get exportTitle => 'Export to CSV';
  @override
  String get exportCounts => 'Counts';
  @override
  String get exportRoster => 'Roster';
  @override
  String get exportChanges => 'Changes since the freeze';
  @override
  String get includePrivate => 'Include private fields';
  @override
  String get includePrivateHelp =>
      'Left out unless you choose them. The roster adds birth dates too.';
  @override
  String get exportFailed =>
      "Couldn't export. Check your connection and try again.";
  @override
  String get exported => 'Exported';
  @override
  String get freeze => 'Freeze counts';
  @override
  String get freezeTitle => 'Freeze counts now?';
  @override
  String get freezeBody =>
      'The numbers are kept with today\'s date, for suppliers. Later changes show against them.';
  @override
  String get freezeLabel => 'Note (optional), such as who it was sent to';
  @override
  String get freezeConfirm => 'Freeze';
  @override
  String get cancel => 'Cancel';
  @override
  String get freezeFailed => "Couldn't freeze the counts. Try again.";
  @override
  String get frozenNow => 'Counts frozen';
  @override
  String frozenOn(String when, String? label) =>
      label == null ? 'Frozen $when' : 'Frozen $when · $label';
  @override
  String get changesHeading => 'Changes since the freeze';
  @override
  String get noChanges => 'No changes since the freeze.';
  @override
  String change(String what, int before, int after) {
    final d = after - before;
    return '$what: $before → $after (${d > 0 ? '+' : ''}$d)';
  }

  @override
  String get earlierFreezes => 'Compare with';
  @override
  String get wholeEventLabel => 'Whole event';
}

/// The template picker, the first step of creating an event (#89, Req 63).
abstract class TemplateStrings {
  const TemplateStrings();

  String get pickerTitle;
  String get pickerHelp;
  String get quick;
  String get loadFailed;
  String get retry;
  String formTitle(String template);

  String get titleLabel;
  String get titleHint;
  String get titleRequired;
  String get titleTooLong;
  String get descriptionLabel;
  String get descriptionHint;
  String get startDate;
  String get dateOptional;
  String get currency;
  String get create;
  String get createFailed;
  String get signInRequired;
  String get currencyHelp;

  /// A saved template's subtitle, naming the template it started from.
  String basedOn(String template);

  // Editing an event (Spec #186).
  String get editTitle;
  String get endDate;
  String get endBeforeStart;
  String get clearDate;
  String get archivedLabel;
  String get archivedOn;
  String get archivedOff;
  String get saveChanges;

  // Saved templates (Req 65).
  String get systemHeading;
  String get mineHeading;
  String get deleteMine;
  String deleteMineTitle(String name);
  String get deleteMineBody;
  String get cancel;
  String get delete;
  String get saveAsTemplate;
  String get saveAsTemplateHelp;
  String get saveAsTemplateName;
  String get saveAsTemplateNameRequired;
  String get save;
  String get savedAsTemplate;
  String get saveAsTemplateFailed;

  // Follow-up setup (Req 64).
  String get setupTitle;
  String get setupHelp;
  String get setupSkip;
  String get setupDone;
  String get setupEntry;
  String get setupEntryHelp;
  String get stepDates;
  String get stepDatesHelp;
  String get stepVenues;
  String get stepVenuesHelp;
  String get stepSchedule;
  String get stepScheduleHelp;
  String get stepFields;
  String get stepFieldsHelp;
  String stepPeople(String people);
  String stepPeopleHelp(String people);
  String get stepComplete;
  String get stepToDo;
}

class _EnglishTemplateStrings extends TemplateStrings {
  const _EnglishTemplateStrings();

  @override
  String get pickerTitle => 'Create an event';
  @override
  String get pickerHelp =>
      'Start from a template. You can change anything afterwards.';
  @override
  String get quick => 'Just a title and a date';
  @override
  String get loadFailed => "Couldn't load the templates. Try again.";
  @override
  String get retry => 'Try again';
  @override
  String formTitle(String template) => 'New ${template.toLowerCase()} event';

  @override
  String get titleLabel => 'Title';
  @override
  String get titleHint => 'What are you planning?';
  @override
  String get titleRequired => 'Please enter a title';
  @override
  String get titleTooLong => 'Title must be under 200 characters';
  @override
  String get descriptionLabel => 'Description';
  @override
  String get descriptionHint => 'Details, location, notes... (optional)';
  @override
  String get startDate => 'Start date';
  @override
  String get dateOptional => 'Optional, tap to set';
  @override
  String get currency => 'Currency';
  @override
  String get create => 'Create event';
  @override
  String get createFailed => "Couldn't create the event. Try again.";
  @override
  String get signInRequired => 'Sign in to create an event.';
  @override
  String get currencyHelp =>
      'Can be changed in settings until money is recorded.';
  @override
  String basedOn(String template) => 'Based on $template';
  @override
  String get editTitle => 'Edit event';
  @override
  String get endDate => 'End date';
  @override
  String get endBeforeStart => 'End date must be on or after start date';
  @override
  String get clearDate => 'Clear date';
  @override
  String get archivedLabel => 'Archived';
  @override
  String get archivedOn => 'Event is read-only';
  @override
  String get archivedOff => 'Active';
  @override
  String get saveChanges => 'Save changes';

  @override
  String get systemHeading => 'Templates';
  @override
  String get mineHeading => 'Your templates';
  @override
  String get deleteMine => 'Delete template';
  @override
  String deleteMineTitle(String name) => 'Delete "$name"?';
  @override
  String get deleteMineBody => 'Events made from it keep their settings.';
  @override
  String get cancel => 'Cancel';
  @override
  String get delete => 'Delete';
  @override
  String get saveAsTemplate => 'Save as template';
  @override
  String get saveAsTemplateHelp =>
      'Keep this setup to start your next event from. Only settings are saved, never people, money or messages.';
  @override
  String get saveAsTemplateName => 'Template name';
  @override
  String get saveAsTemplateNameRequired => 'Enter a name.';
  @override
  String get save => 'Save';
  @override
  String get savedAsTemplate => 'Saved to your templates';
  @override
  String get saveAsTemplateFailed => "Couldn't save the template. Try again.";

  @override
  String get setupTitle => 'Finish setting up';
  @override
  String get setupHelp =>
      'All optional. Skip any of these and finish later from Event settings.';
  @override
  String get setupSkip => 'Skip for now';
  @override
  String get setupDone => 'Done';
  @override
  String get setupEntry => 'Finish setting up';
  @override
  String get setupEntryHelp => 'Dates, places, schedule, questions and people';
  @override
  String get stepDates => 'Dates';
  @override
  String get stepDatesHelp => 'When it starts and ends';
  @override
  String get stepVenues => 'Places and time zone';
  @override
  String get stepVenuesHelp =>
      'Where it happens, with addresses and directions';
  @override
  String get stepSchedule => 'Schedule';
  @override
  String get stepScheduleHelp => 'What happens when, over each day';
  @override
  String get stepFields => 'Questions for attendees';
  @override
  String get stepFieldsHelp => 'Such as diet or sizes, and age groups';
  @override
  String stepPeople(String people) => 'Add ${people.toLowerCase()}';
  @override
  String stepPeopleHelp(String people) =>
      'Import a list or add ${people.toLowerCase()} one by one';
  @override
  String get stepComplete => 'Done';
  @override
  String get stepToDo => 'Not yet';
}

/// One kind of data the app keeps, why, and whether it is required.
typedef PrivacyDataItem = ({String field, String purpose, bool required});

/// A service the app depends on, and what for.
typedef PrivacyService = ({String name, String purpose});

/// The Privacy dashboard and the legal documents it opens.
abstract class PrivacyStrings {
  const PrivacyStrings();

  String get title;
  String get collectedHeading;
  List<PrivacyDataItem> get collected;
  String get required;
  String get optional;
  String get paymentNote;
  String get notCollectedHeading;
  List<String> get notCollected;
  String get servicesHeading;
  List<PrivacyService> get services;
  String get legalHeading;
  String get privacyPolicy;
  String get terms;

  // A legal document.
  String get effective;
  String get lastUpdated;
  String get viewHosted;
  String get loadFailed;
  String get viewOnline;
  String couldNotOpen(String url);
}

class _EnglishPrivacyStrings extends PrivacyStrings {
  const _EnglishPrivacyStrings();

  @override
  String get title => 'Privacy Dashboard';

  @override
  String get collectedHeading => 'Data we collect';

  @override
  List<PrivacyDataItem> get collected => const [
    (
      field: 'Display Name',
      purpose: 'How you appear to crew members',
      required: true,
    ),
    (
      field: 'Email',
      purpose: 'Contact for settlements, account recovery',
      required: true,
    ),
    (
      field: 'Profile Photo',
      purpose: 'Avatar in events, chat, expenses',
      required: false,
    ),
    (
      field: 'Payment Method',
      purpose: 'Show crew how to pay you (Venmo, Zelle, etc.)',
      required: false,
    ),
    (
      field: 'Payment Handle',
      purpose: 'Your @username or phone for chosen method',
      required: false,
    ),
    (
      field: 'Currency',
      purpose: 'Display formatting preference',
      required: false,
    ),
    (
      field: 'Usage Analytics',
      purpose: 'Anonymous app improvement data',
      required: false,
    ),
  ];

  @override
  String get required => 'Required';

  @override
  String get optional => 'Optional';

  @override
  String get paymentNote =>
      'Your payment details (Venmo handle, etc.) are visible to other '
      'CrewPoint users to facilitate settlements.';

  @override
  String get notCollectedHeading => 'What we do not collect';

  @override
  List<String> get notCollected => const [
    'Phone number (unless you add it as payment handle)',
    'Physical address, birthday, or demographics',
    'Device identifiers or advertising IDs',
    'Contacts or social graph',
    'Location data',
    'Browsing or usage history (unless opted in)',
  ];

  @override
  String get servicesHeading => 'Third-party services';

  @override
  List<PrivacyService> get services => const [
    (name: 'Firebase Auth', purpose: 'Authentication services'),
    (name: 'Cloud Firestore', purpose: 'Real-time database'),
    (name: 'Firebase Storage', purpose: 'Profile photo storage'),
    (name: 'Cloud Functions', purpose: 'Account deletion (server-side)'),
    (name: 'Google Sign-In', purpose: 'Social authentication'),
    (name: 'Sign in with Apple', purpose: 'Social authentication'),
    (name: 'Drift (SQLite)', purpose: 'Local offline database'),
    (name: 'Flutter Secure Storage', purpose: 'Encrypted token storage'),
  ];

  @override
  String get legalHeading => 'Legal documents';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get terms => 'Terms of Service';

  @override
  String get effective => 'Effective';

  @override
  String get lastUpdated => 'Last updated';

  @override
  String get viewHosted => 'View hosted version';

  @override
  String get loadFailed => 'Could not load this document right now.';

  @override
  String get viewOnline => 'View online';

  @override
  String couldNotOpen(String url) => 'Could not open $url';
}

/// The first-run pages before signing in.
abstract class OnboardingStrings {
  const OnboardingStrings();

  String get appName;
  String get tagline;
  String get planTitle;
  String get planBody;
  String get syncTitle;
  String get syncBody;
  String get splitTitle;
  String get splitBody;
  String get privacyTitle;
  String get privacyBody;
  String get dataOptIn;
  String get skip;
  String get next;
  String get start;

  /// Read by screen readers on the page dots, such as "Page 2 of 5".
  String page(int number, int count);
}

class _EnglishOnboardingStrings extends OnboardingStrings {
  const _EnglishOnboardingStrings();

  @override
  String get appName => 'CrewPoint';

  @override
  String get tagline => 'Your crew, organized.';

  @override
  String get planTitle => 'Plan Events Together';

  @override
  String get planBody =>
      'Assign roles, set dates, and track progress\u2014all in one place.';

  @override
  String get syncTitle => 'Stay in Sync';

  @override
  String get syncBody =>
      'Real-time messaging with critical alerts when it matters most.';

  @override
  String get splitTitle => 'Split Costs Fairly';

  @override
  String get splitBody =>
      'Track expenses, upload receipts, and see who owes what.';

  @override
  String get privacyTitle => 'Your Data, Your Rules';

  @override
  String get privacyBody =>
      'We believe in transparency. You decide what to share.';

  @override
  String get dataOptIn => 'Allow anonymous usage data';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Continue';

  @override
  String get start => 'Get Started';

  @override
  String page(int number, int count) => 'Page $number of $count';
}

/// The dev flavor's diagnostic console. Only developers see it.
abstract class DevStrings {
  const DevStrings();

  String get title;
  String flavorLine(String flavor);
  String get signInForDiagnostics;
  String get crashHeading;
  String get crashOff;
  String get crashSend;
  String get crashThrow;
  String get crashNotSent;
  String crashSent(String id);
  String get fcmHeading;
  String uidLine(String uid);
  String get fcmRerun;
  String get fcmReattach;
  String get fcmAttached;
  String get fcmNotAttached;
  String get fcmAuthStatus;
  String get fcmApnsToken;
  String get fcmApnsMissing;
  String get fcmLiveToken;
  String get fcmStoredTokens;
  String get fcmNoStoredTokens;
  String fcmTokenCount(int count);
  String fcmError(String error);
  String get copyReport;
  String get copied;
  String get galleryTitle;
  String get galleryHelp;
}

class _EnglishDevStrings extends DevStrings {
  const _EnglishDevStrings();

  @override
  String get title => 'Dev Tools';

  @override
  String flavorLine(String flavor) => 'flavor: $flavor · build: debug-only';

  @override
  String get signInForDiagnostics =>
      'Sign in to run diagnostics that need a uid '
      '(FCM token registration, Firestore round-trip, etc).';

  @override
  String get crashHeading => 'Crash reporting';

  @override
  String get crashOff => 'Off: this build has no SENTRY_DSN.';

  @override
  String get crashSend => 'Send test report';

  @override
  String get crashThrow => 'Throw test error';

  @override
  String get crashNotSent => 'Not sent. Debug builds need SENTRY_DEBUG=true.';

  @override
  String crashSent(String id) => 'Sent as $id';

  @override
  String get fcmHeading => 'FCM diagnostic';

  @override
  String uidLine(String uid) => 'uid: $uid';

  @override
  String get fcmRerun => 'Re-run check';

  @override
  String get fcmReattach => 'Force re-attach';

  @override
  String get fcmAttached => 'attach() returned true — token written';

  @override
  String get fcmNotAttached =>
      'attach() returned false — see diagnostics below';

  @override
  String get fcmAuthStatus => 'Auth status';

  @override
  String get fcmApnsToken => 'APNs token';

  @override
  String get fcmApnsMissing => '(null) — APNs not registered yet';

  @override
  String get fcmLiveToken => 'FCM token (live)';

  @override
  String get fcmStoredTokens => 'Firestore fcmTokens';

  @override
  String get fcmNoStoredTokens => '(empty array — token not yet written)';

  @override
  String fcmTokenCount(int count) => '$count token(s):';

  @override
  String fcmError(String error) => 'ERROR: $error';

  @override
  String get copyReport => 'Copy report';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get galleryTitle => 'Design gallery';

  @override
  String get galleryHelp => 'Every component in light, dark and 200% text';
}

/// Event settings → Registration (#239), translated through the ARB
/// files.
class RegistrationSettingsStrings {
  const RegistrationSettingsStrings(this._l);

  final AppLocalizations _l;

  String intro(String fields) => _l.regSettingsIntro(fields);
  String get modeHeading => _l.regSettingsModeHeading;
  String get modeOpen => _l.regSettingsModeOpen;
  String get modeOpenHelp => _l.regSettingsModeOpenHelp;
  String get modeInvited => _l.regSettingsModeInvited;
  String modeInvitedHelp(String group) => _l.regSettingsModeInvitedHelp(group);
  String get placesHeading => _l.regSettingsPlacesHeading;
  String get capacity => _l.regSettingsCapacity;
  String get capacityHelp => _l.regSettingsCapacityHelp;
  String get capacityInvalid => _l.regSettingsCapacityInvalid;
  String get deadline => _l.regSettingsDeadline;
  String deadlineHelp(String zone) => _l.regSettingsDeadlineHelp(zone);
  String get deadlineTime => _l.regSettingsDeadlineTime;
  String get noDeadline => _l.regSettingsNoDeadline;
  String get clear => _l.regSettingsClear;
  String get review => _l.regSettingsReview;
  String get reviewHelp => _l.regSettingsReviewHelp;
  String extraGuests(String group) => _l.regSettingsExtraGuests(group);
  String get extraGuestsHelp => _l.regSettingsExtraGuestsHelp;
  String get extraGuestsInvalid => _l.regSettingsExtraGuestsInvalid;
  String get offerHours => _l.regSettingsOfferHours;
  String get offerHoursHelp => _l.regSettingsOfferHoursHelp;
  String get offerHoursInvalid => _l.regSettingsOfferHoursInvalid;
  String get linkHeading => _l.regSettingsLinkHeading;
  String get slug => _l.regSettingsSlug;
  String get slugHelp => _l.regSettingsSlugHelp;
  String slugLink(String link) => _l.regSettingsSlugLink(link);
  String get noSlug => _l.regSettingsNoSlug;
  String get slugSave => _l.regSettingsSlugSave;
  String get slugRemove => _l.regSettingsSlugRemove;
  String get slugSaved => _l.regSettingsSlugSaved;
  String get slugRemoved => _l.regSettingsSlugRemoved;
  String get slugTaken => _l.regSettingsSlugTaken;
  String get slugInvalid => _l.regSettingsSlugInvalid;
  String get slugFailed => _l.regSettingsSlugFailed;
  String get roleHeading => _l.regSettingsRoleHeading;
  String get roleLabel => _l.regSettingsRoleLabel;
  String get roleHelp => _l.regSettingsRoleHelp;
  String get chosen => _l.regSettingsChosen;
  String get blocksHeading => _l.regSettingsBlocksHeading;
  String get blockPeople => _l.regSettingsBlockPeople;
  String get blockPeopleHelp => _l.regSettingsBlockPeopleHelp;
  String get blockAgeOnly => _l.regSettingsBlockAgeOnly;
  String get blockAgeOnlyHelp => _l.regSettingsBlockAgeOnlyHelp;
  String get blockStay => _l.regSettingsBlockStay;
  String get blockStayHelp => _l.regSettingsBlockStayHelp;
  String blockSessions(String sessions) =>
      _l.regSettingsBlockSessions(sessions);
  String blockSessionsHelp(String sessions) =>
      _l.regSettingsBlockSessionsHelp(sessions);
  String get blockWaivers => _l.regSettingsBlockWaivers;
  String get blockWaiversHelp => _l.regSettingsBlockWaiversHelp;
  String get blockContact => _l.regSettingsBlockContact;
  String get blockContactHelp => _l.regSettingsBlockContactHelp;
  String get sectionsHeading => _l.regSettingsSectionsHeading;
  String sectionsHelp(String fields) => _l.regSettingsSectionsHelp(fields);
  String get addSection => _l.regSettingsAddSection;
  String newSectionName(int number) => _l.regSettingsNewSectionName(number);
  String get sectionName => _l.regSettingsSectionName;
  String get sectionNeedsName => _l.regSettingsSectionNeedsName;
  String get sectionActions => _l.regSettingsSectionActions;
  String questionActions(String question) =>
      _l.regSettingsQuestionActions(question);
  String get moveUp => _l.regSettingsMoveUp;
  String get moveDown => _l.regSettingsMoveDown;
  String get removeSection => _l.regSettingsRemoveSection;
  String get removeQuestion => _l.regSettingsRemoveQuestion;
  String sectionEmpty(String field) => _l.regSettingsSectionEmpty(field);
  String addQuestion(String field) => _l.regSettingsAddQuestion(field);
  String addQuestionTitle(String field) =>
      _l.regSettingsAddQuestionTitle(field);
  String unplaced(String names) => _l.regSettingsUnplaced(names);
  String noFields(String fields) => _l.regSettingsNoFields(fields);
  String editFields(String fields) => _l.regSettingsEditFields(fields);
  String get shownToEveryone => _l.regSettingsShownToEveryone;
  String onlyCategory(String category) => _l.regSettingsOnlyCategory(category);
  String whenAnswer(String question, String value) =>
      _l.regSettingsWhenAnswer(question, value);
  String conditionTitle(String question) =>
      _l.regSettingsConditionTitle(question);
  String get conditionFixed => _l.regSettingsConditionFixed;
  String get yes => _l.regSettingsYes;
  String get no => _l.regSettingsNo;
  String get noteHeading => _l.regSettingsNoteHeading;
  String noteHelp(String groups) => _l.regSettingsNoteHelp(groups);
  String get note => _l.regSettingsNote;
  String get laterNoteFrom => _l.regSettingsLaterNoteFrom;
  String laterNoteFromHelp(String groups) =>
      _l.regSettingsLaterNoteFromHelp(groups);
  String get notReplaced => _l.regSettingsNotReplaced;
  String get laterNote => _l.regSettingsLaterNote;
  String get laterNoteNeedsDate => _l.regSettingsLaterNoteNeedsDate;
  String get save => _l.regSettingsSave;
  String get saved => _l.regSettingsSaved;
  String get saveFailed => _l.regSettingsSaveFailed;
}
