/// Domain model representing an authenticated user.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.paymentMethod,
    this.paymentHandle,
    this.venmoHandle,
    this.cashappHandle,
    this.fcmTokens = const [],
    this.currency = 'USD',
    this.emailVerified = false,
    this.providerIds = const [],
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? paymentMethod; // venmo, zelle, cashapp, paypal, cash
  final String? paymentHandle; // @username, phone, or email
  final String? venmoHandle;
  final String? cashappHandle;
  final List<String> fcmTokens;
  final String currency;

  /// True iff Firebase considers this user's email verified.
  final bool emailVerified;

  /// Firebase provider IDs attached to this user (`password`, `apple.com`,
  /// `google.com`, ...).
  final List<String> providerIds;

  /// True when the only attached provider is `password`. Drives the
  /// "Verify your email" banner — OAuth-linked accounts don't need it.
  bool get isPasswordOnly =>
      providerIds.length == 1 && providerIds.first == 'password';
}
