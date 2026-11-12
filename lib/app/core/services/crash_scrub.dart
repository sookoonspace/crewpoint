/// Keeps personal data out of crash reports (Req 68). Pure Dart, so the
/// rules are tested without a reporter.
library;

final _email = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');

/// A run of digits with the separators phone numbers use. Whether it is a
/// phone number is decided by [_isPhone].
final _digitRun = RegExp(r'\+?\(?\d[\d ().-]{5,}\d');
final _date = RegExp(r'\d{4}-\d{2}-\d{2}');

/// Nine to fifteen digits (E.164 allows fifteen), and not a date.
bool _isPhone(String run) {
  final digits = run.replaceAll(RegExp(r'\D'), '').length;
  return digits >= 9 && digits <= 15 && !_date.hasMatch(run);
}

/// Firestore document IDs are 20 letters and digits and Firebase user IDs
/// 28, so a run of 16 or more with a digit in it is taken as an ID. Long
/// words, which have no digits, stay.
final _id = RegExp(r'\b[A-Za-z0-9]{16,}\b');

/// [text] with email addresses, IDs and phone numbers masked.
String maskPersonalText(String text) => text
    .replaceAll(_email, '<email>')
    .replaceAllMapped(
      _id,
      (m) => m[0]!.contains(RegExp(r'\d')) ? '<id>' : m[0]!,
    )
    .replaceAllMapped(_digitRun, (m) => _isPhone(m[0]!) ? '<phone>' : m[0]!);

/// Route names are lower-case words (`event`, `dev-tools`, `new`); anything
/// else in a path is an ID or an invite code.
final _routeName = RegExp(r'^(:[a-zA-Z]+|[a-z]+(-[a-z]+)*)$');

/// [location] as it may appear in a report: IDs and codes become `:id`, and
/// the query (`?from=`, `?group=`) is dropped.
String routeForReport(String location) {
  final path = location.split('?').first.split('#').first;
  return path
      .split('/')
      .map((s) => s.isEmpty || _routeName.hasMatch(s) ? s : ':id')
      .join('/');
}
