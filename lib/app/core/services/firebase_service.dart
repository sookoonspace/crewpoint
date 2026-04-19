import 'package:firebase_core/firebase_core.dart';
import 'package:crewpoint_app/app/core/env/app_flavor.dart';
import 'package:crewpoint_app/app/core/env/env.dart';

/// Initializes Firebase based on the current build flavor.
abstract final class FirebaseService {
  static Future<void> initialize({AppFlavor flavor = AppFlavor.dev}) async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: Env.firebaseAppId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
      ),
    );
  }
}
