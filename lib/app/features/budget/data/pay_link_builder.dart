/// Pure utility for building payment-app deep links and HTTPS fallbacks.
///
/// Has no Flutter / Firebase imports; safe to unit-test fast.
abstract final class PayLinkBuilder {
  static final RegExp _handlePattern = RegExp(r'^[A-Za-z0-9_-]{1,30}$');
  static const int _maxNoteLength = 60;

  static String _validateHandle(String handle) {
    if (!_handlePattern.hasMatch(handle)) {
      throw ArgumentError.value(
        handle,
        'handle',
        'Handle must match ^[A-Za-z0-9_-]{1,30}\$',
      );
    }
    return handle;
  }

  static String _formatAmount(double amount) => amount.toStringAsFixed(2);

  static String _truncateNote(String note) =>
      note.length > _maxNoteLength ? note.substring(0, _maxNoteLength) : note;

  /// `venmo://paycharge?txn=pay&recipients={handle}&amount={x.xx}&note={...}`
  static Uri venmo({
    required String handle,
    required double amount,
    required String note,
  }) {
    final h = _validateHandle(handle);
    return Uri(
      scheme: 'venmo',
      host: 'paycharge',
      queryParameters: {
        'txn': 'pay',
        'recipients': h,
        'amount': _formatAmount(amount),
        'note': _truncateNote(note),
      },
    );
  }

  /// HTTPS fallback when the Venmo app isn't installed:
  /// `https://venmo.com/{handle}?txn=pay&amount=...&note=...`
  static Uri venmoWebFallback({
    required String handle,
    required double amount,
    required String note,
  }) {
    final h = _validateHandle(handle);
    return Uri(
      scheme: 'https',
      host: 'venmo.com',
      path: '/$h',
      queryParameters: {
        'txn': 'pay',
        'amount': _formatAmount(amount),
        'note': _truncateNote(note),
      },
    );
  }

  /// CashApp uses universal links cleanly: `https://cash.app/$handle/amount`.
  static Uri cashApp({required String handle, required double amount}) {
    final h = _validateHandle(handle);
    return Uri(
      scheme: 'https',
      host: 'cash.app',
      path: '/\$$h/${_formatAmount(amount)}',
    );
  }
}
