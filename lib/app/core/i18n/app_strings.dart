import 'package:crewpoint_app/app/features/dashboard/domain/models/expense_access.dart';
import 'package:flutter/widgets.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/category.dart';
import 'package:crewpoint_app/app/features/participants/domain/models/custom_field.dart';

/// User-facing string surface for CrewPoint.
///
/// Today: a single hand-written English impl (`_EnglishStrings`).
/// Tomorrow (when `flutter_localizations` + ARB are wired): swap the
/// body of `StringsX.strings` to return an adapter over the generated
/// `AppLocalizations` class — every call site stays identical.
///
/// Migration path:
/// ```dart
/// // today
/// extension StringsX on BuildContext {
///   AppStrings get strings => const _EnglishStrings();
/// }
///
/// // tomorrow (one file's body changes; UI files do not)
/// extension StringsX on BuildContext {
///   AppStrings get strings =>
///       _AppLocalizationsAdapter(AppLocalizations.of(this)!);
/// }
/// ```
///
/// ARB-key naming convention: field names on the sub-objects map 1:1
/// to flat ARB keys via the future adapter (`auth.signIn` →
/// `_l.authSignIn`, `errors.popupBlocked` → `_l.errorsPopupBlocked`).
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
  FieldStrings get fields;
  ImportStrings get imports;
  LinkStrings get links;
  InviteStrings get invites;
  MemberPickerStrings get memberPicker;
  ScheduleStrings get schedule;
  AgendaStrings get agenda;

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
}

/// User-facing strings for the cross-event Chat tab — the Global Inbox.
abstract class ChatStrings {
  const ChatStrings();

  String get readOnlyNotice;

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
  AppStrings get strings => AppStrings.fallbackEnglish;
}

class _EnglishStrings extends AppStrings {
  const _EnglishStrings();

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
  FieldStrings get fields => const _EnglishFieldStrings();

  @override
  ImportStrings get imports => const _EnglishImportStrings();

  @override
  LinkStrings get links => const _EnglishLinkStrings();

  @override
  InviteStrings get invites => const _EnglishInviteStrings();

  @override
  MemberPickerStrings get memberPicker => const _EnglishMemberPickerStrings();
  @override
  ScheduleStrings get schedule => const _EnglishScheduleStrings();
  @override
  AgendaStrings get agenda => const _EnglishAgendaStrings();
}

class _EnglishChatStrings extends ChatStrings {
  const _EnglishChatStrings();

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
  String get urgentBadge => 'URGENT';

  @override
  String disputeWindowClosed(int days) =>
      'This settlement can no longer be disputed, because more than $days days '
      'have passed.';

  @override
  String get urgentLimitReached =>
      'Saved, but nobody was alerted: you have reached the limit for urgent '
      'messages. Try again later.';
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
  String get settingsSection => 'SETTINGS';

  @override
  String get paymentSection => 'PAYMENT';

  @override
  String get notifications => 'Notifications';

  @override
  String get privacyDashboard => 'Privacy Dashboard';

  @override
  String get signOut => 'Sign Out';

  @override
  String get deleteAccount => 'Delete Account';

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
}

class _EnglishDashboardStrings extends DashboardStrings {
  const _EnglishDashboardStrings();

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
}

class _EnglishRoleStrings extends RoleStrings {
  const _EnglishRoleStrings();

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
  String deleteGroupBody(String group);
  String get groupSaved;
  String get groupDeleted;
  String get groupSaveFailed;
}

class _EnglishPeopleStrings extends PeopleStrings {
  const _EnglishPeopleStrings();

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
  String accountLine(String? name, String email);
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
  String accountLine(String? name, String email) =>
      name == null || name.isEmpty ? email : '$name · $email';
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

/// The invite link and QR code (Req 47, 56), and `/join/:code`.
abstract class InviteStrings {
  const InviteStrings();

  String get generating;
  String get offline;
  String get permissionDenied;
  String get eventGone;
  String get failed;
  String get retry;
  String get shareHint;
  String get linkLabel;
  String get codeLabel;
  String qrLabel(String link);
  String expires(String when);
  String get changeExpiry;
  String expiryChoice(String choice);
  String get pickDate;
  String get copyLink;
  String get copied;
  String get share;
  String shareText(String title, String link, String code);
  String get rotate;
  String get rotateHint;

  // `/join/:code`
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
}

class _EnglishInviteStrings extends InviteStrings {
  const _EnglishInviteStrings();

  @override
  String get generating => 'Getting the invite…';
  @override
  String get offline => 'Invites need a connection. Check it and try again.';
  @override
  String get permissionDenied =>
      'Only people who manage members can invite others.';
  @override
  String get eventGone => 'This event no longer exists.';
  @override
  String get failed => "Couldn't get the invite. Please try again.";
  @override
  String get retry => 'Try again';
  @override
  String get shareHint =>
      'Share the link or QR code. Anyone with it can join until it expires.';
  @override
  String get linkLabel => 'Invite link';
  @override
  String get codeLabel => 'Or enter this code in the app';
  @override
  String qrLabel(String link) => 'QR code for $link';
  @override
  String expires(String when) => 'Expires $when';
  @override
  String get changeExpiry => 'Change expiry';
  @override
  String expiryChoice(String choice) => switch (choice) {
    'day' => '24 hours',
    'week' => '7 days',
    'month' => '30 days',
    'eventStart' => 'Until the event starts',
    'eventEnd' => 'Until the event ends',
    _ => choice,
  };
  @override
  String get pickDate => 'Pick a date…';
  @override
  String get copyLink => 'Copy link';
  @override
  String get copied => 'Link copied';
  @override
  String get share => 'Share';
  @override
  String shareText(String title, String link, String code) =>
      'Join $title on CrewPoint: $link (or enter code $code in the app)';
  @override
  String get rotate => 'Replace link';
  @override
  String get rotateHint =>
      'The old link and code stop working, for one that was shared too widely.';

  @override
  String get joinTitle => 'Join an event';
  @override
  String get joinNeedsConnection => 'Joining needs a connection.';
  @override
  String get joinLoading => 'Checking the invite…';
  @override
  String joinAs(String role) => "You'll join as $role.";
  @override
  String startsOn(String date) => 'Starts $date';
  @override
  String get joinButton => 'Join';
  @override
  String get joined => 'You joined the event!';
  @override
  String get notFound =>
      'This invite is invalid or has expired. Ask the organizer for a new link.';
  @override
  String get notOpenDraft =>
      "This event isn't open to joining yet. The organizer still needs to "
      'publish it. Try the link again later.';
  @override
  String get notOpenEnded =>
      'This event has ended, so it is closed to joining.';
  @override
  String get full => 'This event is full. Ask the organizer about a place.';
  @override
  String get alreadyMember => "You're already in this event.";
  @override
  String get openEvent => 'Open the event';
  @override
  String get joinFailed =>
      "Couldn't join. Check your connection and try again.";
  @override
  String get backToEvents => 'Go to my events';
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
}

class _EnglishMemberPickerStrings extends MemberPickerStrings {
  const _EnglishMemberPickerStrings();

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
