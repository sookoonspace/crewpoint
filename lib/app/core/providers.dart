import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crewpoint_app/app/core/database/app_database.dart';
import 'package:crewpoint_app/app/core/database/daos/tasks_dao.dart';
import 'package:crewpoint_app/app/core/services/account_deletion_service.dart';
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
  ),
);

/// Onboarding state notifier.
final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(
  () => OnboardingNotifier(
    storageService: SecureStorageService(storage: const FlutterSecureStorage()),
  ),
);

/// App database (Drift). Uses in-memory for now; swap with native connection
/// via connection/native.dart when platform-specific init is wired.
final databaseProvider = Provider<AppDatabase>(
  (_) => AppDatabase(NativeDatabase.memory()),
);

/// Image service (pick, take, upload).
final imageServiceProvider = Provider<IImageService>(
  (_) => FirebaseImageService(),
);

/// User profile repository (Firestore).
final userRepositoryProvider = Provider<IUserRepository>(
  (_) => FirestoreUserRepository(),
);

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

/// Task repository (Firestore source of truth + Drift mirror).
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final repo = TaskRepository(
    tasksDao: TasksDao(ref.watch(databaseProvider)),
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
