import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
// Conditional import: native (mobile/desktop) uses dart:ffi sqlite3, web
// uses drift's Wasm backend. Importing the right file at compile time
// keeps dart:ffi out of the web JS bundle (otherwise sqlite3 FFI bindings
// fail to compile to JS).
import 'package:crewpoint_app/app/core/database/connection/native.dart'
    if (dart.library.html) 'package:crewpoint_app/app/core/database/connection/web.dart';
import 'package:crewpoint_app/app/core/database/daos/chat_messages_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/chat_reads_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expense_splits_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/expenses_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/task_checklist_items_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/core/services/account_deletion_service.dart';
import 'package:crewpoint_app/app/core/services/app_badge_service.dart';
import 'package:crewpoint_app/app/core/services/app_lifecycle_source.dart';
import 'package:crewpoint_app/app/core/services/fcm_gateway.dart';
import 'package:crewpoint_app/app/core/services/fcm_service.dart';
import 'package:crewpoint_app/app/core/services/file_export_service.dart';
import 'package:crewpoint_app/app/core/services/file_export_service_native.dart'
    if (dart.library.html) 'package:crewpoint_app/app/core/services/file_export_service_web.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/core/services/secure_storage_service.dart';
import 'package:crewpoint_app/app/features/auth/application/auth_provider.dart';
import 'package:crewpoint_app/app/features/auth/data/auth_repository.dart';
import 'package:crewpoint_app/app/features/auth/data/firebase_auth_service.dart';
import 'package:crewpoint_app/app/core/services/firebase_image_service.dart';
import 'package:crewpoint_app/app/core/services/image_service.dart';
import 'package:crewpoint_app/app/features/onboarding/application/onboarding_provider.dart';
import 'package:crewpoint_app/app/features/profile/data/firestore_user_repository.dart';
import 'package:crewpoint_app/app/features/profile/domain/repositories/i_user_repository.dart';
import 'package:crewpoint_app/app/core/services/i_chat_service.dart';
import 'package:crewpoint_app/app/core/services/url_launcher_service.dart';
import 'package:crewpoint_app/app/features/budget/application/settle_up_controller.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_repository.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/settle_up_fallback_sheet.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/chat/data/firestore_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_repository.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';

/// Secure storage instance.
final secureStorageProvider = Provider<SecureStorageService>(
  (_) => SecureStorageService(storage: const FlutterSecureStorage()),
);

/// Auth service (Firebase).
final authServiceProvider = Provider<IAuthService>(
  (_) => FirebaseAuthService(),
);

/// Auth repository.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(authService: ref.watch(authServiceProvider)),
);

/// Auth state notifier.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  () => AuthNotifier(
    authRepository: AuthRepository(authService: FirebaseAuthService()),
    userRepository: FirestoreUserRepository(),
  ),
);

/// Onboarding state notifier.
final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(
  () => OnboardingNotifier(
    storageService: SecureStorageService(storage: const FlutterSecureStorage()),
  ),
);

/// App database (Drift).
///
/// On mobile/desktop, [openConnection] returns a [LazyDatabase] that
/// opens a persistent SQLite file at `<docs>/crewpoint.db` (see
/// `connection/native.dart`). On web, it returns a `WasmDatabase`
/// wrapper (`connection/web.dart`) — but per the V1 spec the web build
/// does not actually exercise Drift (data flows through Firestore
/// directly), so the Wasm path is only triggered if a Drift-backed
/// provider is read on web.
final databaseProvider = Provider<AppDatabase>(
  (_) => AppDatabase(openConnection()),
);

/// Image service (pick, take, upload).
final imageServiceProvider = Provider<IImageService>(
  (_) => FirebaseImageService(),
);

/// User profile repository (Firestore).
final userRepositoryProvider = Provider<IUserRepository>(
  (_) => FirestoreUserRepository(),
);

/// `firebase_messaging` test seam.
final fcmGatewayProvider = Provider<IFcmGateway>((_) => FirebaseFcmGateway());

/// Owns the FCM token lifecycle (`attach(uid)` / `detach(uid)`).
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(
    gateway: ref.watch(fcmGatewayProvider),
    userRepository: ref.watch(userRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Platform-channel adapter for the OS launcher app-icon badge.
///
/// Defaults to [NoOpAppBadgePlatform] — Phase 3b.1 deliberately defers
/// the real package choice (both `flutter_app_badge_control` and
/// `flutter_app_badger` have rough edges as of this writing). A follow-up
/// commit overrides this provider with a concrete adapter and adds the
/// package to `pubspec.yaml`.
final appBadgePlatformProvider = Provider<IAppBadgePlatform>(
  (_) => const NoOpAppBadgePlatform(),
);

/// App lifecycle source — `Widgets`-backed in prod, fake in tests.
final appLifecycleSourceProvider = Provider<AppLifecycleSource>((ref) {
  final source = WidgetsAppLifecycleSource();
  ref.onDispose(source.dispose);
  return source;
});

/// Mirrors a single unread count to the OS launcher badge. Wire from
/// `main.dart` via `ref.listen(unreadBadgeProvider(uid))`.
final appBadgeServiceProvider = Provider<AppBadgeService>((ref) {
  final service = AppBadgeService(
    platform: ref.watch(appBadgePlatformProvider),
    lifecycleSource: ref.watch(appLifecycleSourceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Account deletion service.
final accountDeletionServiceProvider = Provider<AccountDeletionService>(
  (ref) => AccountDeletionService(
    database: ref.watch(databaseProvider),
    secureStorage: ref.watch(secureStorageProvider),
  ),
);

/// Firestore instance.
final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

/// Current user's uid, derived from [authProvider]. Returns null when the
/// user is signed out, in any non-`Authenticated` state, or before auth
/// initialises. UI code reads this instead of pattern-matching `authProvider`
/// so the auth-state surface stays in one place.
final currentUserIdProvider = Provider<String?>((ref) {
  final state = ref.watch(authProvider);
  return switch (state) {
    Authenticated(:final user) => user.uid,
    _ => null,
  };
});

/// Event repository (Firestore source of truth + Drift mirror).
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = EventRepository(
    eventsDao: EventsDao(db),
    firestore: ref.watch(firestoreProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Live stream of events the current user is a member of. Emits an empty
/// list when no user is signed in.
final dashboardEventsProvider = StreamProvider<List<EventModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const <EventModel>[]);
  final repo = ref.watch(eventRepositoryProvider);
  ref.onDispose(() => repo.disposeMirror(uid));
  return repo.watchEventsForUser(uid);
});

/// Looks up a single event by id from the user's dashboard event list.
/// Returns null when the event isn't in the list (loading, deleted, or the
/// user lost access). Loading-vs-missing discrimination happens at the
/// widget layer (`_EventGuard`), not here.
final eventByIdProvider = Provider.family<EventModel?, String>((ref, id) {
  final asyncEvents = ref.watch(dashboardEventsProvider);
  return asyncEvents.maybeWhen(
    data: (events) {
      for (final e in events) {
        if (e.id == id) return e;
      }
      return null;
    },
    orElse: () => null,
  );
});

/// Task repository (Firestore source of truth + Drift mirror).
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = TaskRepository(
    tasksDao: TasksDao(db),
    checklistDao: TaskChecklistItemsDao(db),
    firestore: ref.watch(firestoreProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Live stream of tasks for a given event.
final taskListProvider = StreamProvider.family<List<TaskModel>, String>((
  ref,
  eventId,
) {
  final repo = ref.watch(taskRepositoryProvider);
  ref.onDispose(() => repo.disposeMirror(eventId));
  return repo.watchTasksByEventId(eventId);
});

/// Live stream of checklist items for a given (eventId, taskId) pair.
/// Family key is `'$eventId/$taskId'` for stable equality.
final taskChecklistProvider =
    StreamProvider.family<
      List<ChecklistItem>,
      ({String eventId, String taskId})
    >((ref, key) {
      final repo = ref.watch(taskRepositoryProvider);
      ref.onDispose(() => repo.disposeChecklistMirror(key.eventId, key.taskId));
      return repo.watchChecklist(key.eventId, key.taskId);
    });

/// Expense repository (Firestore source of truth + Drift mirror).
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = ExpenseRepository(
    expensesDao: ExpensesDao(db),
    splitsDao: ExpenseSplitsDao(db),
    firestore: ref.watch(firestoreProvider),
    imageService: ref.watch(imageServiceProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Live stream of expenses for a given event.
final expenseListProvider = StreamProvider.family<List<ExpenseModel>, String>((
  ref,
  eventId,
) {
  final repo = ref.watch(expenseRepositoryProvider);
  ref.onDispose(() => repo.disposeMirror(eventId));
  return repo.watchExpensesByEventId(eventId);
});

/// Chat service (Firestore-backed for V1).
final chatServiceProvider = Provider<IChatService>(
  (ref) => FirestoreChatService(firestore: ref.watch(firestoreProvider)),
);

/// `chat_reads` DAO — backs the global inbox unread badges.
final chatReadsDaoProvider = Provider<ChatReadsDao>(
  (ref) => ChatReadsDao(ref.watch(databaseProvider)),
);

/// Chat repository — wraps the chat service with a Drift cache.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final repo = ChatRepository(
    chatService: ref.watch(chatServiceProvider),
    chatMessagesDao: ChatMessagesDao(ref.watch(databaseProvider)),
    firestore: ref.watch(firestoreProvider),
    chatReadsDao: ref.watch(chatReadsDaoProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Live stream of chat messages for an event (Drift-mirrored).
final chatMessagesProvider =
    StreamProvider.family<List<ChatMessageModel>, String>((ref, eventId) {
      final repo = ref.watch(chatRepositoryProvider);
      ref.onDispose(() => repo.disposeMirror(eventId));
      return repo.watchMessages(eventId);
    });

/// `package:url_launcher` seam (testable).
final urlLauncherProvider = Provider<IUrlLauncher>(
  (_) => const UrlLauncherService(),
);

/// Settle-Up controller — picks a `PayLinkBuilder` deep link based on
/// the counterparty's `paymentMethod`, falls back to a manual sheet
/// when no link is available or the launch fails.
final settleUpControllerProvider = Provider<SettleUpController>((ref) {
  return SettleUpController(
    userRepository: ref.watch(userRepositoryProvider),
    urlLauncher: ref.watch(urlLauncherProvider),
    showFallback: SettleUpFallbackSheet.show,
  );
});

/// Platform-aware file-export seam (PDF + CSV downloads).
///
/// Web target compiles against `WebFileExporter` (Wasm-safe `package:web`
/// Blob + anchor for non-PDF; `Printing.sharePdf` for PDF). Mobile/desktop
/// compile against `NativeFileExporter` (`Printing.sharePdf` for PDF;
/// `share_plus` for everything else). Tests override with a recording
/// fake.
final fileExporterProvider = Provider<IFileExporter>(
  (_) => createFileExporter(),
);

/// Callable signature for the `disputeSettlement` Cloud Function.
typedef DisputeSettlementCall =
    Future<void> Function({
      required String eventId,
      required String settlementId,
    });

/// Default impl wraps `FirebaseFunctions.instance`. Tests override with a fake.
final disputeSettlementCallableProvider = Provider<DisputeSettlementCall>(
  (_) => ({required eventId, required settlementId}) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'disputeSettlement',
    );
    await callable.call<Map<String, dynamic>>({
      'eventId': eventId,
      'settlementId': settlementId,
    });
  },
);
