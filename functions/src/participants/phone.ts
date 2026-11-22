/**
 * Phone numbers in international (E.164) form (Spec #233 Req 13, 17, #237),
 * so a number entered on a form, imported or edited by an organizer matches
 * the `phone_number` Firebase puts on a verified account. Pure. The app has
 * the same rules in `phone.dart`; both run `test/fixtures/phone_cases.json`.
 */

/** Where Firebase sends sign-in codes (Technical Decision 5). */
export type PhoneCountry = "US" | "CA" | "GB";

/** Separators people type or paste between digits (`\s` covers a non-breaking space). */
const SEPARATORS = /[\s\-.()/]/g;

/** A North American number's ten digits: area code and exchange from 2. */
const NANP = /^[2-9]\d{2}[2-9]\d{6}$/;

/**
 * [input] as `+<digits>`, or null when it is not a whole phone number.
 * Without a `+` or `00` prefix, it is read in [country].
 */
export function normalisePhone(input: string, country: PhoneCountry): string | null {
  const text = input.replace(SEPARATORS, "");
  let international: string;
  if (/^\+\d+$/.test(text)) {
    international = text.slice(1);
  } else if (/^00\d+$/.test(text)) {
    international = text.slice(2);
  } else if (/^\d+$/.test(text)) {
    international = national(text, country);
  } else {
    return null;
  }
  // "+44 (0)7700 900123": the trunk 0 is written but never dialled.
  if (international.startsWith("440")) international = "44" + international.slice(3);
  if (!/^[1-9]\d{7,14}$/.test(international)) return null;
  if (international.startsWith("1") && !NANP.test(international.slice(1))) return null;
  if (international.startsWith("44") && !/^44[1-9]\d{8,9}$/.test(international)) return null;
  return `+${international}`;
}

/** A number without a prefix, with its country code added. */
function national(digits: string, country: PhoneCountry): string {
  if (country === "GB") return `44${digits.replace(/^0/, "")}`;
  // North America: an 11-digit number keeps its leading 1.
  return digits.length === 11 && digits.startsWith("1") ? digits : `1${digits}`;
}

/** Canadian zones; every other American zone is read as the US. */
const CANADA = new Set([
  "America/Atikokan", "America/Blanc-Sablon", "America/Cambridge_Bay", "America/Creston",
  "America/Dawson", "America/Dawson_Creek", "America/Edmonton", "America/Fort_Nelson",
  "America/Glace_Bay", "America/Goose_Bay", "America/Halifax", "America/Inuvik",
  "America/Iqaluit", "America/Moncton", "America/Montreal", "America/Nipigon",
  "America/Pangnirtung", "America/Rainy_River", "America/Rankin_Inlet", "America/Regina",
  "America/Resolute", "America/St_Johns", "America/Swift_Current", "America/Thunder_Bay",
  "America/Toronto", "America/Vancouver", "America/Whitehorse", "America/Winnipeg",
  "America/Yellowknife",
]);

/**
 * The event's default country for numbers typed without a prefix, from its
 * time zone. Events outside the sign-in regions read as the US, so their
 * numbers need a prefix.
 */
export function countryForTimeZone(timeZone: string | null | undefined): PhoneCountry {
  if (!timeZone) return "US";
  if (timeZone === "Europe/London" || timeZone === "Europe/Belfast") return "GB";
  return CANADA.has(timeZone) ? "CA" : "US";
}
