import 'package:flutter/widgets.dart';

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
  String upcomingEventsHeader(int count);
  String pastEventsHeader(int count);

  // Error state.
  String get errorLoading;
  String get retryCta;
}

/// User-facing strings for the cross-event Chat tab — the Global Inbox.
abstract class ChatStrings {
  const ChatStrings();

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
}

/// User-facing strings for the cross-event Budget tab — the Financial Ledger.
abstract class BudgetStrings {
  const BudgetStrings();

  // Ledger surface.
  String get ledgerAppBarTitle;
  String get ledgerHeroOwedToYouLabel;
  String get ledgerHeroYouOweLabel;
  String get ledgerDebtsHeader;
  String get ledgerAllSettledMessage;
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
}

class _EnglishChatStrings extends ChatStrings {
  const _EnglishChatStrings();

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
}

class _EnglishBudgetStrings extends BudgetStrings {
  const _EnglishBudgetStrings();

  @override
  String get ledgerAppBarTitle => 'Budget';

  @override
  String get ledgerHeroOwedToYouLabel => 'You are owed';

  @override
  String get ledgerHeroYouOweLabel => 'You owe';

  @override
  String get ledgerDebtsHeader => 'Settle up';

  @override
  String get ledgerAllSettledMessage => "You're all settled up.";

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
  String get openDashboardCta => 'Open Dashboard';

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
