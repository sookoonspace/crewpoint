/// Phone numbers in international (E.164) form (Spec #233 Req 13, 17, #237),
/// so a number entered here matches the `phone_number` Firebase puts on a
/// verified account. Pure. The server has the same rules in
/// `functions/src/participants/phone.ts`; both run
/// `functions/test/fixtures/phone_cases.json`, so change them together.
library;

/// Where Firebase sends sign-in codes (Technical Decision 5).
enum PhoneCountry {
  us('US'),
  ca('CA'),
  gb('GB');

  const PhoneCountry(this.code);

  /// ISO 3166 code, as the server and the shared cases write it.
  final String code;

  static PhoneCountry byCode(String code) =>
      values.firstWhere((c) => c.code == code);
}

/// Separators people type or paste between digits (`\s` covers the
/// non-breaking space a paste brings).
final _separators = RegExp(r'[\s\-.()/]');

/// A North American number's ten digits: area code and exchange from 2.
final _nanp = RegExp(r'^[2-9]\d{2}[2-9]\d{6}$');

/// [input] as `+<digits>`, or null when it is not a whole phone number.
/// Without a `+` or `00` prefix, it is read in [country].
String? normalisePhone(String input, PhoneCountry country) {
  final text = input.replaceAll(_separators, '');
  String international;
  if (RegExp(r'^\+\d+$').hasMatch(text)) {
    international = text.substring(1);
  } else if (RegExp(r'^00\d+$').hasMatch(text)) {
    international = text.substring(2);
  } else if (RegExp(r'^\d+$').hasMatch(text)) {
    international = _national(text, country);
  } else {
    return null;
  }
  // "+44 (0)7700 900123": the trunk 0 is written but never dialled.
  if (international.startsWith('440')) {
    international = '44${international.substring(3)}';
  }
  if (!RegExp(r'^[1-9]\d{7,14}$').hasMatch(international)) return null;
  if (international.startsWith('1') &&
      !_nanp.hasMatch(international.substring(1))) {
    return null;
  }
  if (international.startsWith('44') &&
      !RegExp(r'^44[1-9]\d{8,9}$').hasMatch(international)) {
    return null;
  }
  return '+$international';
}

/// A number without a prefix, with its country code added.
String _national(String digits, PhoneCountry country) {
  if (country == PhoneCountry.gb) {
    return '44${digits.replaceFirst(RegExp('^0'), '')}';
  }
  // North America: an 11-digit number keeps its leading 1.
  return digits.length == 11 && digits.startsWith('1') ? digits : '1$digits';
}

/// Canadian zones; every other American zone is read as the US.
const _canada = {
  'America/Atikokan', 'America/Blanc-Sablon', 'America/Cambridge_Bay', //
  'America/Creston', 'America/Dawson', 'America/Dawson_Creek',
  'America/Edmonton', 'America/Fort_Nelson', 'America/Glace_Bay',
  'America/Goose_Bay', 'America/Halifax', 'America/Inuvik',
  'America/Iqaluit', 'America/Moncton', 'America/Montreal',
  'America/Nipigon', 'America/Pangnirtung', 'America/Rainy_River',
  'America/Rankin_Inlet', 'America/Regina', 'America/Resolute',
  'America/St_Johns', 'America/Swift_Current', 'America/Thunder_Bay',
  'America/Toronto', 'America/Vancouver', 'America/Whitehorse',
  'America/Winnipeg', 'America/Yellowknife',
};

/// The event's default country for numbers typed without a prefix, from its
/// time zone. Events outside the sign-in regions read as the US, so their
/// numbers need a prefix.
PhoneCountry countryForTimeZone(String? timeZone) {
  if (timeZone == null || timeZone.isEmpty) return PhoneCountry.us;
  if (timeZone == 'Europe/London' || timeZone == 'Europe/Belfast') {
    return PhoneCountry.gb;
  }
  return _canada.contains(timeZone) ? PhoneCountry.ca : PhoneCountry.us;
}
