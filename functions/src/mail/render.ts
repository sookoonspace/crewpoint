import en from "./templates/en.json";
import gu from "./templates/gu.json";
import defaults from "../shared/label_defaults.json";
import {resolveLabel} from "../notifications/labels";

/**
 * Email templates by language (Spec #233 Req 53, 56). Each template has a
 * `subject`, a plain `text` body and a short `push` line sent alongside.
 * Placeholders are `{{name}}` for values the sender passes, and
 * `{{word.<concept>.<one|other>}}` (with `.lower`) for the event's own words.
 */
type Template = {subject: string; text: string; push: string};
const TEMPLATES: Record<string, Record<string, Template>> = {en, gu};

export type MailLanguage = "en" | "gu";

/** Languages emails can be sent in; anything else is sent in English. */
export const MAIL_LANGUAGES: readonly MailLanguage[] = ["en", "gu"];

export class MailRenderError extends Error {}

export interface RenderedEmail {
  subject: string;
  text: string;
  html: string;
  push: {title: string; body: string};
}

/**
 * Data keys that would carry money. Emails never show amounts in 2A
 * (Req 53), so a sender passing one is a bug, refused before anything goes.
 */
const MONEY_KEY = /amount|price|fee|total|balance|cost/i;

export function languageOf(value: unknown): MailLanguage {
  return MAIL_LANGUAGES.includes(value as MailLanguage) ? value as MailLanguage : "en";
}

function wordPlaceholders(labels: Record<string, unknown> | undefined): Record<string, string> {
  const out: Record<string, string> = {};
  for (const concept of Object.keys(defaults) as (keyof typeof defaults)[]) {
    for (const form of ["one", "other"] as const) {
      const word = resolveLabel(labels, concept, form);
      out[`word.${concept}.${form}`] = word;
      out[`word.${concept}.${form}.lower`] = word.toLowerCase();
    }
  }
  return out;
}

function fill(template: string, values: Record<string, string>): string {
  // Unknown keys stay visible, so a broken template fails loudly.
  return template.replace(/\{\{([\w.]+)\}\}/g, (match, key: string) =>
    Object.prototype.hasOwnProperty.call(values, key) ? values[key] : match);
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/**
 * Renders [template] in [language] (English when missing) with [data] and
 * the event's [labels]. Throws [MailRenderError] for an unknown template or
 * a money value.
 */
export function renderEmail(args: {
  template: string;
  language: unknown;
  data: Record<string, string>;
  labels?: Record<string, unknown>;
}): RenderedEmail {
  const language = languageOf(args.language);
  const chosen = TEMPLATES[language][args.template] ?? TEMPLATES.en[args.template];
  if (!chosen) throw new MailRenderError(`Unknown email template: ${args.template}`);
  const moneyKey = Object.keys(args.data).find((k) => MONEY_KEY.test(k));
  if (moneyKey) throw new MailRenderError(`Emails carry no money amounts: ${moneyKey}`);

  const values = {...wordPlaceholders(args.labels), ...args.data};
  const escaped = Object.fromEntries(
    Object.entries(values).map(([k, v]) => [k, escapeHtml(v)]));
  const subject = fill(chosen.subject, values);
  const text = fill(chosen.text, values);
  const htmlBody = fill(escapeHtml(chosen.text), escaped)
    .split("\n\n")
    .map((para) => `<p>${para.replace(/\n/g, "<br>")}</p>`)
    .join("\n");
  const html = `<!doctype html><html lang="${language}"><head><meta charset="utf-8">` +
    `<title>${escapeHtml(subject)}</title></head>` +
    `<body style="font: 16px/1.5 sans-serif;">\n${htmlBody}\n</body></html>`;
  return {subject, text, html, push: {title: subject, body: fill(chosen.push, values)}};
}
