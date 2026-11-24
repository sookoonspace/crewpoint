import 'package:shared_preferences/shared_preferences.dart';

/// The email a sign-in link was sent to on this device (#241), so opening
/// the link here signs in at once. Opened on another device, the address
/// is asked for instead. Cleared once signed in.
class PendingSignInStore {
  const PendingSignInStore(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'pending_sign_in_email_v1';

  String? get email => _prefs.getString(_key);

  Future<void> save(String email) => _prefs.setString(_key, email);

  Future<void> clear() => _prefs.remove(_key);
}
