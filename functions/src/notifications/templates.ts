import en from "./templates/en.json";

/**
 * Per-locale template registry. Add new locales as a `{ <bcp47>: <json> }`
 * mapping below; `loadTemplate` resolves in this order:
 *
 *   1. exact locale match (e.g. `'es-MX'` → `es-MX.json`)
 *   2. base language match (e.g. `'en-GB'` → `en.json`)
 *   3. unconditional English fallback (`'en'`)
 *
 * Categories without a template entry resolve to `undefined`; callers
 * should fall through to the literal title / body args so a brand-new
 * push category never silently emits an empty string.
 */
const TEMPLATES: Record<string, Record<string, Record<string, string>>> = {
  en,
};

/**
 * Resolves the template string for `(category, field, locale)`. Returns
 * `undefined` when no template exists for that category/field — caller
 * must fall back to a literal title / body in that case.
 */
export function loadTemplate(
  category: string,
  field: string,
  locale: string | null | undefined
): string | undefined {
  const baseLocale = (locale ?? "en").split("-")[0];
  // Try exact, then base-language, then English. The exact + base
  // attempts cover `es-MX` → `es-MX.json` → `es.json` if both are
  // registered; today only `en` is registered so both fall through.
  const candidates = [
    locale ?? "",
    baseLocale,
    "en",
  ].filter((c) => c.length > 0);
  for (const candidate of candidates) {
    const bundle = TEMPLATES[candidate];
    const value = bundle?.[category]?.[field];
    if (typeof value === "string") return value;
  }
  return undefined;
}

/**
 * Substitutes `{{key}}` placeholders in [template] with values from
 * [placeholders]. Unknown keys are left intact so a bad template fails
 * loud (visible braces in the notification) rather than emitting a
 * silent empty string. No `eval`, no JS template literals — pure
 * string-replace.
 */
export function interpolate(
  template: string,
  placeholders: Record<string, string>
): string {
  return template.replace(/\{\{(\w+)\}\}/g, (match, key: string) => {
    return Object.prototype.hasOwnProperty.call(placeholders, key) ?
      placeholders[key] :
      match;
  });
}
