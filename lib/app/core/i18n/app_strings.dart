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
}

/// User-facing strings for the Dashboard feature (events list + empty state).
abstract class DashboardStrings {
  const DashboardStrings();

  String get noEventsTitle;
  String get noEventsSubtitle;
  String get joinWithCode;
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

  /// Templated last-message prefix used in inbox rows. When the message's
  /// sender is the current user, `senderName` should be "You".
  String inboxLastMessagePrefix({
    required String senderName,
    required String text,
  });
}

/// User-facing strings for the cross-event Budget tab placeholder.
abstract class BudgetStrings {
  const BudgetStrings();

  String get tabEmptyTitle;
  String get tabEmptySubtitle;
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
  String inboxLastMessagePrefix({
    required String senderName,
    required String text,
  }) => '$senderName: $text';
}

class _EnglishBudgetStrings extends BudgetStrings {
  const _EnglishBudgetStrings();

  @override
  String get tabEmptyTitle => 'Budget is coming soon';

  @override
  String get tabEmptySubtitle =>
      'Open an event from the Dashboard to track expenses.';
}

class _EnglishDashboardStrings extends DashboardStrings {
  const _EnglishDashboardStrings();

  @override
  String get noEventsTitle => 'No events yet';

  @override
  String get noEventsSubtitle => 'Create an event or join one with a code';

  @override
  String get joinWithCode => 'Join with Code';
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
  String get groupAssignee => 'Assignee';

  @override
  String get groupDueWindow => 'Due window';

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
