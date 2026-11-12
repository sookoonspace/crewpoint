import 'dart:convert';
import 'package:crewpoint_app/app/core/services/qr_renderer.dart';
import 'package:crewpoint_app/app/core/services/file_picker_service.dart';
import 'package:crewpoint_app/app/features/participants/data/import_repository.dart';
import 'package:crewpoint_app/app/features/participants/data/participant_repository.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/my_balance.dart';
import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart' show rootBundle;
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
import 'package:crewpoint_app/app/core/database/daos/mirror_syncs_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/my_records_dao.dart';
import 'package:crewpoint_app/app/core/database/daos/sessions_dao.dart';
import 'package:crewpoint_app/app/features/counts/domain/count_export.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event_template.dart';
import 'package:crewpoint_app/app/features/counts/domain/event_stats.dart';
import 'package:crewpoint_app/app/features/schedule/data/my_records_repository.dart';
import 'package:crewpoint_app/app/features/schedule/data/session_repository.dart';
import 'package:crewpoint_app/app/features/schedule/domain/models/session.dart';
import 'package:crewpoint_app/app/core/services/account_deletion_service.dart';
import 'package:crewpoint_app/app/core/services/app_badge_service.dart';
import 'package:crewpoint_app/app/core/services/app_lifecycle_source.dart';
import 'package:crewpoint_app/app/core/services/fcm_gateway.dart';
import 'package:crewpoint_app/app/core/services/fcm_service.dart';
import 'package:crewpoint_app/app/core/services/device_timezone.dart';
import 'package:crewpoint_app/app/core/services/notification_channels.dart';
import 'package:crewpoint_app/app/core/services/file_export_service.dart';
import 'package:crewpoint_app/app/core/services/file_export_service_native.dart'
    if (dart.library.html) 'package:crewpoint_app/app/core/services/file_export_service_web.dart';
import 'package:crewpoint_app/app/core/services/i_auth_service.dart';
import 'package:crewpoint_app/app/core/services/page_reloader.dart';
import 'package:crewpoint_app/app/core/services/page_reloader_native.dart'
    if (dart.library.html) 'package:crewpoint_app/app/core/services/page_reloader_web.dart';
import 'package:crewpoint_app/app/core/services/secure_storage_service.dart';
import 'package:crewpoint_app/app/core/version/app_version_check.dart';
import 'package:crewpoint_app/app/core/version/app_version_services.dart';
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
import 'package:crewpoint_app/app/features/budget/domain/repositories/i_expense_repository.dart';
import 'package:crewpoint_app/app/features/budget/application/settle_up_controller.dart';
import 'package:crewpoint_app/app/features/budget/data/expense_repository.dart';
import 'package:crewpoint_app/app/features/budget/domain/models/expense.dart';
import 'package:crewpoint_app/app/features/budget/presentation/widgets/settle_up_fallback_sheet.dart';
import 'package:crewpoint_app/app/features/chat/data/chat_repository.dart';
import 'package:crewpoint_app/app/features/chat/data/firestore_chat_service.dart';
import 'package:crewpoint_app/app/features/chat/domain/models/chat_message.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_mute_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/data/event_repository.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/event_mute.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/member.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/role.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/crew.dart';
import 'package:crewpoint_app/app/features/dashboard/domain/models/ownership_offer.dart';
import 'package:crewpoint_app/app/features/dashboard/data/member_calls.dart';
import 'package:crewpoint_app/app/core/database/daos/events_dao.dart';
import 'package:crewpoint_app/app/features/tasks/data/task_repository.dart';
import 'package:crewpoint_app/app/features/tasks/domain/models/task.dart';
import 'package:crewpoint_app/app/core/services/crash_reporter.dart';

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
  (ref) => FirestoreUserRepository(firestore: ref.watch(firestoreProvider)),
);

/// `firebase_messaging` test seam.
final fcmGatewayProvider = Provider<IFcmGateway>((_) => FirebaseFcmGateway());

/// Android notification-channel declaration adapter. Backed by a Kotlin
/// `MethodChannel` handler in `MainActivity` that calls
/// `NotificationManager.createNotificationChannel(...)` per registered
/// spec. iOS / web / desktop short-circuit inside the adapter.
final notificationChannelsProvider = Provider<INotificationChannels>(
  (_) => const MethodChannelNotificationChannels(),
);

/// Device IANA timezone resolver (Phase 5.2). Used by the quiet-hours
/// settings to persist the recipient's true timezone alongside the
/// minute-of-day window so the CF can do `Intl.DateTimeFormat`
/// conversion correctly. Tests inject a [LocalNameDeviceTimezone] or
/// a recording fake.
final deviceTimezoneProvider = Provider<IDeviceTimezone>(
  (_) => const MethodChannelDeviceTimezone(),
);

/// Web VAPID public key — required by `FirebaseMessaging.getToken()` on
/// the web platform. Source: Firebase Console → Project Settings →
/// Cloud Messaging → Web configuration. Supplied via
/// `--dart-define=FIREBASE_VAPID_KEY=...` at build time. Empty string
/// (the default) is treated as unset so mobile builds don't pass a
/// bogus value into the gateway.
const _firebaseVapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

/// Owns the FCM token lifecycle (`attach(uid)` / `detach(uid)`).
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(
    gateway: ref.watch(fcmGatewayProvider),
    userRepository: ref.watch(userRepositoryProvider),
    notificationChannels: ref.watch(notificationChannelsProvider),
    vapidKey: _firebaseVapidKey.isEmpty ? null : _firebaseVapidKey,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Platform-channel adapter for the OS launcher app-icon badge.
///
/// Backed by `app_badge_plus` (Phase 3b.2) — iOS / Android / macOS.
/// Tests override this with [NoOpAppBadgePlatform] or a recording fake
/// to keep the platform channel out of the test loop.
final appBadgePlatformProvider = Provider<IAppBadgePlatform>(
  (_) => const AppBadgePlusPlatform(),
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

/// Default impl wraps `FirebaseFunctions.instance`. Tests override with a fake.
final createEventCallProvider = Provider<CreateEventCall>(
  (_) => (event, {savedTemplateId}) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'createEvent',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    await callable.call<Map<String, dynamic>>({
      'eventId': event.id,
      'title': event.title,
      'description': event.description,
      'timeZone': event.timeZone,
      'dateOnly': event.dateOnly,
      'currency': event.currency,
      'templateId': event.templateId,
      'savedTemplateId': ?savedTemplateId,
      'startDate': event.startDate?.toUtc().toIso8601String(),
      'endDate': event.endDate?.toUtc().toIso8601String(),
    });
  },
);

/// The viewer's zone, to show an event's zone only where it differs.
final deviceZoneNameProvider = FutureProvider<String>(
  (ref) => ref.watch(deviceTimezoneProvider).getLocalTimezone(),
);

/// Default impl wraps `FirebaseFunctions.instance`. Tests override with a fake.
final changeEventCurrencyCallProvider = Provider<ChangeEventCurrencyCall>(
  (_) => (eventId, currency) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'changeEventCurrency',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    await callable.call<Map<String, dynamic>>({
      'eventId': eventId,
      'currency': currency,
    });
  },
);

/// Event repository (Firestore source of truth + Drift mirror).
/// Where "My events" memberships come from. Null in the app, which reads
/// member documents with a collection-group query. Tests override it, since
/// the fake Firestore sends collection-group results only once.
final membershipsSourceProvider = Provider<MembershipsSource?>((_) => null);

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = EventRepository(
    eventsDao: EventsDao(db),
    firestore: ref.watch(firestoreProvider),
    createEventCall: ref.watch(createEventCallProvider),
    memberships: ref.watch(membershipsSourceProvider),
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
  return repo
      .watchEventsForUser(uid)
      .map((events) => events.where((e) => e.isVisibleTo(uid)).toList());
});

/// Everyone's member document in an event (Req 25): roles and permissions.
/// Read straight from Firestore, whose cache keeps it offline. Empty for an
/// event with no member documents, where callers fall back to the arrays.
final eventMembersProvider = StreamProvider.family<List<MemberModel>, String>((
  ref,
  eventId,
) {
  return ref
      .watch(firestoreProvider)
      .collection('events')
      .doc(eventId)
      .collection('members')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => MemberModel.fromFirestore(doc.id, doc.data()))
            .toList(),
      );
});

/// The member and role callables. Tests override it with a fake.
final memberCallsProvider = Provider<MemberCalls>(
  (_) => const FirebaseMemberCalls(),
);

/// Draws invite QR codes (Req 47). Tests override it with a fake.
final qrRendererProvider = Provider<IQrRenderer>(
  (_) => const QrFlutterRenderer(),
);

/// An event's roles (Req 26a): the presets with the event's own versions, then
/// its custom roles. Read straight from Firestore, whose cache keeps it
/// offline.
final eventRolesProvider = StreamProvider.family<List<RoleDefinition>, String>((
  ref,
  eventId,
) {
  return ref
      .watch(firestoreProvider)
      .collection('events')
      .doc(eventId)
      .collection('roles')
      .snapshots()
      .map(
        (snap) => resolveRoles(RoleCatalogue.current, {
          for (final doc in snap.docs) doc.id: doc.data(),
        }),
      );
});

/// An event's crews (Req 33), by name. Read straight from Firestore, whose
/// cache keeps it offline.
final eventCrewsProvider = StreamProvider.family<List<CrewModel>, String>((
  ref,
  eventId,
) {
  return ref
      .watch(firestoreProvider)
      .collection('events')
      .doc(eventId)
      .collection('crews')
      .snapshots()
      .map(
        (snap) => [
          for (final doc in snap.docs)
            CrewModel.fromFirestore(doc.id, doc.data()),
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      );
});

/// The pending ownership offer for an event (Req 30), or null when there is
/// none.
final ownershipOfferProvider = StreamProvider.family<OwnershipOffer?, String>(
  (ref, eventId) => ref
      .watch(firestoreProvider)
      .doc('events/$eventId/ownership/offer')
      .snapshots()
      .map((snap) => OwnershipOffer.fromFirestore(snap.data())),
);

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
    syncs: MirrorSyncsDao(db),
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
  final assigneeId = ref.watch(taskReadScopeProvider(eventId));
  ref.onDispose(() => repo.disposeMirror(eventId));
  return repo.watchTasksByEventId(eventId, assigneeId: assigneeId);
});

/// Sessions repository (Firestore source of truth + Drift mirror), Req 48.
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final repo = SessionRepository(
    dao: SessionsDao(ref.watch(databaseProvider)),
    firestore: ref.watch(firestoreProvider),
    syncs: MirrorSyncsDao(ref.watch(databaseProvider)),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// An event's sessions, unordered. Hidden ones only for `schedule.edit`,
/// following role changes live.
final sessionListProvider = StreamProvider.family<List<SessionModel>, String>((
  ref,
  eventId,
) {
  final repo = ref.watch(sessionRepositoryProvider);
  final me = ref.watch(currentUserIdProvider);
  final withHidden = ref.watch(
    eventByIdProvider(
      eventId,
    ).select((e) => me != null && (e?.can(me, 'schedule.edit') ?? false)),
  );
  ref.onDispose(() => repo.disposeMirror(eventId));
  return repo.watchSessions(eventId, withHidden: withHidden);
});

/// Task budget figures by task ID (Req 36), only for people holding
/// `budget.read`. Everyone else gets none, without a query the rules would
/// refuse. Follows role changes live.
final taskBudgetsProvider = StreamProvider.family<Map<String, double>, String>((
  ref,
  eventId,
) {
  final me = ref.watch(currentUserIdProvider);
  final reads = ref.watch(
    eventByIdProvider(
      eventId,
    ).select((e) => me != null && (e?.can(me, 'budget.read') ?? false)),
  );
  if (!reads) return Stream.value(const {});
  return ref.watch(taskRepositoryProvider).watchBudgets(eventId);
});

/// Participants and groups, read online (Req 43). Never mirrored.
final participantRepositoryProvider = Provider<ParticipantRepository>(
  (ref) => ParticipantRepository(firestore: ref.watch(firestoreProvider)),
);

/// The signed-in person's own member document in an event, live, for what is
/// not on [EventModel], such as their group IDs (Req 26b). Null outside it.
final myMemberProvider = StreamProvider.family<MemberModel?, String>((
  ref,
  eventId,
) {
  final me = ref.watch(currentUserIdProvider);
  if (me == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .doc('events/$eventId/members/$me')
      .snapshots()
      .map((doc) {
        final data = doc.data();
        return data == null ? null : MemberModel.fromFirestore(doc.id, data);
      });
});

/// File choosing (Req 44a). Tests override this.
final filePickerProvider = Provider<IFilePicker>(
  (_) => const FileSelectorPicker(),
);

/// Import file uploads to Storage. Tests override this.
final importUploaderProvider = Provider<IImportUploader>(
  (_) => const FirebaseImportUploader(),
);

/// Roster import jobs (Req 44a, 75).
final importRepositoryProvider = Provider<ImportRepository>(
  (ref) => ImportRepository(
    firestore: ref.watch(firestoreProvider),
    uploader: ref.watch(importUploaderProvider),
  ),
);

/// Calls `getMyBalance`. Tests override this.
typedef MyBalanceCall = Future<MyBalance> Function(String eventId);

final myBalanceCallProvider = Provider<MyBalanceCall>(
  (_) => (eventId) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable('getMyBalance')
        .call<Map<String, dynamic>>({'eventId': eventId});
    return MyBalance.fromMap(result.data);
  },
);

/// The signed-in person's balance from the server (Req 38c), for when they
/// may not read every expense. Asks again whenever the expenses they can see
/// change.
final myBalanceProvider = FutureProvider.family<MyBalance, String>((
  ref,
  eventId,
) {
  ref.watch(expenseListProvider(eventId));
  return ref.watch(myBalanceCallProvider)(eventId);
});

/// Whose tasks the signed-in person lists in an event: null for every task,
/// or their own uid when, as a Vendor or Observer, they read only tasks
/// assigned to them (Req 32). Follows role changes live.
final taskReadScopeProvider = Provider.family<String?, String>((ref, eventId) {
  final me = ref.watch(currentUserIdProvider);
  final event = ref.watch(eventByIdProvider(eventId));
  if (me == null || event == null || event.readsAllTasks(me)) return null;
  return me;
});

/// Whose expenses the signed-in person lists in an event: null for every
/// expense, or their own uid when, as a Vendor or Observer, they read only
/// expenses they paid or share in (Req 32). Follows role changes live.
final expenseReadScopeProvider = Provider.family<String?, String>((
  ref,
  eventId,
) {
  final me = ref.watch(currentUserIdProvider);
  final event = ref.watch(eventByIdProvider(eventId));
  if (me == null || event == null || event.readsAllExpenses(me)) return null;
  return me;
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

/// Default impl wraps `FirebaseFunctions.instance`. Tests override with a fake.
final saveExpenseCallProvider = Provider<SaveExpenseCall>(
  (_) => (expense) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'saveExpense',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    await callable.call<Map<String, dynamic>>({
      'eventId': expense.eventId,
      'expenseId': expense.id,
      'payerId': expense.payerId,
      'amount': expense.amount,
      'description': expense.description,
      'receiptPath': expense.receiptPath,
      'isDonation': expense.isDonation,
      'splits': [
        for (final split in expense.splits)
          {'userId': split.userId, 'amount': split.amount},
      ],
    });
  },
);

/// Default impl wraps `FirebaseFunctions.instance`. Tests override with a fake.
final recordSettlementCallProvider = Provider<RecordSettlementCall>(
  (_) =>
      ({
        required eventId,
        required settlementId,
        required payerId,
        required payeeId,
        required amount,
      }) async {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'recordSettlement',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
        );
        await callable.call<Map<String, dynamic>>({
          'eventId': eventId,
          'settlementId': settlementId,
          'payerId': payerId,
          'payeeId': payeeId,
          'amount': amount,
        });
      },
);

/// Expense repository (Firestore source of truth + Drift mirror).
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = ExpenseRepository(
    expensesDao: ExpensesDao(db),
    splitsDao: ExpenseSplitsDao(db),
    firestore: ref.watch(firestoreProvider),
    saveExpenseCall: ref.watch(saveExpenseCallProvider),
    recordSettlementCall: ref.watch(recordSettlementCallProvider),
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
  final involving = ref.watch(expenseReadScopeProvider(eventId));
  ref.onDispose(() => repo.disposeMirror(eventId));
  return repo.watchExpensesByEventId(eventId, involving: involving);
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
    syncs: MirrorSyncsDao(ref.watch(databaseProvider)),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Live stream of chat messages for an event (Drift-mirrored).
final chatMessagesProvider =
    StreamProvider.family<List<ChatMessageModel>, String>((ref, eventId) {
      // Reading chat needs `chat.send` (Req 32), so a Vendor or Observer
      // without it subscribes to nothing.
      final me = ref.watch(currentUserIdProvider);
      final readsChat = ref.watch(
        eventByIdProvider(
          eventId,
        ).select((e) => e == null || me == null || e.readsChat(me)),
      );
      if (!readsChat) return Stream.value(const []);
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

/// Reloads the page on web, to fetch a newer build. Does nothing natively.
final pageReloaderProvider = Provider<IPageReloader>(
  (_) => createPageReloader(),
);

/// Reads the public `config/app` document (Req 34a).
final appConfigSourceProvider = Provider<IAppConfigSource>(
  (ref) => FirestoreAppConfigSource(ref.watch(firestoreProvider)),
);

/// The running app's version, from `package_info_plus`.
final appInfoProvider = Provider<IAppInfo>((_) => const PackageInfoAppInfo());

/// Crash reporting (Req 68). Sends nothing unless `main` overrides it with
/// the reporter it started, so tests never reach a real one.
final crashReporterProvider = Provider<ICrashReporter>(
  (_) => const NoCrashReporter(),
);

final appPlatformProvider = Provider<AppPlatform>((_) => currentAppPlatform());

/// Checked once at startup. Null means the app carries on, including when
/// the config cannot be read.
final appUpdateRequirementProvider = FutureProvider<AppUpdateRequirement?>(
  (ref) => AppVersionCheck(
    config: ref.watch(appConfigSourceProvider),
    appInfo: ref.watch(appInfoProvider),
    platform: ref.watch(appPlatformProvider),
  ).run(),
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

/// Per-user, per-event push-notification mute store (Phase 5).
/// Backed by Firestore at `users/{uid}/eventMutes/{eventId}`.
final eventMuteRepositoryProvider = Provider<EventMuteRepository>(
  (ref) => EventMuteRepository(firestore: ref.watch(firestoreProvider)),
);

/// Family arg shape for [eventMuteProvider] — Dart records give us
/// value-equality for free, so the family cache hits when the same
/// `(uid, eventId)` pair is observed by multiple widgets.
typedef EventMuteKey = ({String uid, String eventId});

/// Live stream of the current `(uid, eventId)` mute state. Emits null
/// when no mute is set; emits the [EventMute] otherwise.
final eventMuteProvider = StreamProvider.family<EventMute?, EventMuteKey>((
  ref,
  key,
) {
  return ref
      .watch(eventMuteRepositoryProvider)
      .watchEventMute(uid: key.uid, eventId: key.eventId);
});

/// When a mirror last heard from the server, and whether it is reading from
/// the device's cache (Req 74). Keyed like `tasks/{eventId}`.
final mirrorSyncProvider = StreamProvider.autoDispose
    .family<MirrorSync?, String>(
      (ref, key) => MirrorSyncsDao(ref.watch(databaseProvider)).watch(key),
    );

/// The viewer's own records in an event, mirrored for the agenda (Req 51,
/// 74): their participant record, their groups' people and those groups.
final myRecordsRepositoryProvider = Provider<MyRecordsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = MyRecordsRepository(
    dao: MyRecordsDao(db),
    firestore: ref.watch(firestoreProvider),
    syncs: MirrorSyncsDao(db),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

final myRecordsProvider = StreamProvider.family<OwnRecords, String>((
  ref,
  eventId,
) {
  final me = ref.watch(currentUserIdProvider);
  if (me == null) return Stream.value(const OwnRecords());
  final groupIds = ref.watch(
    myMemberProvider(eventId).select((m) => m.value?.groupIds.join(',') ?? ''),
  );
  final repo = ref.watch(myRecordsRepositoryProvider);
  ref.onDispose(() => repo.disposeMirror(eventId));
  return repo.watchMine(
    eventId,
    uid: me,
    groupIds: groupIds.isEmpty ? const [] : groupIds.split(','),
  );
});

/// The time now, from [clockProvider], updated each minute for now and next.
final clockProvider = Provider<Clock>((_) => const Clock());

final minuteProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => clock.now());
});

/// The event's counts (Req 52), or null before the first count. Watch it
/// only for someone holding `counts.read`, since rules refuse anyone else.
/// Read from Firestore, whose cache keeps the last counts offline.
final eventStatsProvider = StreamProvider.autoDispose
    .family<EventStats?, String>(
      (ref, eventId) => ref
          .watch(firestoreProvider)
          .doc('events/$eventId/stats/current')
          .snapshots()
          .map((doc) {
            final data = doc.data();
            return data == null ? null : EventStats.fromFirestore(data);
          }),
    );

/// Counts frozen on a date (Req 54), newest first. Watch it only for
/// someone holding `counts.read`.
final countFreezesProvider = StreamProvider.autoDispose
    .family<List<FrozenCounts>, String>(
      (ref, eventId) => ref
          .watch(firestoreProvider)
          .collection('events/$eventId/countFreezes')
          .orderBy('frozenAt', descending: true)
          .snapshots()
          .map(
            (snap) => [
              for (final doc in snap.docs)
                FrozenCounts.fromFirestore(doc.id, doc.data()),
            ],
          ),
    );

/// The system templates for the picker (Req 62), read from
/// `assets/templates/`, in the index's order.
final templateCatalogueProvider = FutureProvider<List<EventTemplateInfo>>((
  ref,
) async {
  Future<Map<String, dynamic>> read(String file) async =>
      jsonDecode(
            await rootBundle.loadString('${EventTemplateInfo.assetDir}/$file'),
          )
          as Map<String, dynamic>;
  return [
    for (final id in EventTemplateInfo.idsFrom(await read('index.json')))
      EventTemplateInfo.fromJson(await read('$id.json')),
  ];
});

/// The signed-in person's saved templates (Req 65), newest first, from
/// `users/{uid}/templates`, which only they read.
final myTemplatesProvider = StreamProvider<List<EventTemplateInfo>>((ref) {
  final me = ref.watch(currentUserIdProvider);
  if (me == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .collection('users/$me/templates')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (snap) => [
          for (final doc in snap.docs)
            EventTemplateInfo.fromJson({...doc.data(), 'id': doc.id}),
        ],
      );
});
