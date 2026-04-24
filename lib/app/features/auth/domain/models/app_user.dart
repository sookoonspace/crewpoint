/// Domain model representing an authenticated user.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.paymentMethod,
    this.paymentHandle,
    this.currency = 'USD',
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? paymentMethod; // venmo, zelle, cashapp, paypal, cash
  final String? paymentHandle; // @username, phone, or email
  final String currency;
}
