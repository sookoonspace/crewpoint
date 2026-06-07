/**
 * Pure-helper guards for the Phase 6 localization framework.
 *
 * Two responsibilities:
 *   - `loadTemplate(category, field, locale)` — resolves the requested
 *     template string, falling back to English when the locale is
 *     missing / unknown.
 *   - `interpolate(template, placeholders)` — substitutes `{{key}}`
 *     placeholders. No `eval`, no JS template literals; just string
 *     replace so the helper stays safe to call with server-trusted but
 *     not-strictly-validated input.
 */
import {interpolate, loadTemplate} from '../../src/notifications/templates';

describe('interpolate', () => {
  test('substitutes a single {{key}} placeholder', () => {
    expect(interpolate('Hello {{name}}', {name: 'Ada'})).toBe('Hello Ada');
  });

  test('substitutes multiple distinct placeholders', () => {
    expect(
      interpolate('{{greeting}}, {{name}}!', {greeting: 'Hi', name: 'Ada'}),
    ).toBe('Hi, Ada!');
  });

  test('substitutes the same placeholder more than once', () => {
    expect(
      interpolate('{{n}} + {{n}} = {{sum}}', {n: '2', sum: '4'}),
    ).toBe('2 + 2 = 4');
  });

  test('leaves unknown {{keys}} intact (visible-on-purpose to expose template bugs)', () => {
    expect(
      interpolate('Hello {{name}} ({{unknown}})', {name: 'Ada'}),
    ).toBe('Hello Ada ({{unknown}})');
  });

  test('empty placeholders map returns the template unchanged', () => {
    expect(interpolate('Hello {{name}}', {})).toBe('Hello {{name}}');
  });

  test('handles a placeholder-free template', () => {
    expect(interpolate('Static body text.', {name: 'Ada'})).toBe(
      'Static body text.',
    );
  });
});

describe('loadTemplate', () => {
  test('returns the English string for `en`', () => {
    expect(loadTemplate('chat_urgent', 'title', 'en')).toBe(
      '🚨 Urgent in {{eventTitle}}',
    );
  });

  test('falls back to English when locale is null / undefined', () => {
    expect(loadTemplate('chat_urgent', 'title', null)).toBe(
      '🚨 Urgent in {{eventTitle}}',
    );
    expect(loadTemplate('chat_urgent', 'title', undefined)).toBe(
      '🚨 Urgent in {{eventTitle}}',
    );
  });

  test('falls back to English when locale is unknown', () => {
    expect(loadTemplate('chat_urgent', 'title', 'kl')).toBe(
      '🚨 Urgent in {{eventTitle}}',
    );
  });

  test('falls back to English when only the base language is registered', () => {
    // `'en-GB'` should resolve via base-language fallback to `'en'`.
    expect(loadTemplate('chat_urgent', 'title', 'en-GB')).toBe(
      '🚨 Urgent in {{eventTitle}}',
    );
  });

  test('returns undefined when category or field is missing', () => {
    // Forces the caller to keep the literal title/body fallback for
    // any categories without templates yet — guards against silent
    // empty-string pushes.
    expect(
      loadTemplate('nonexistent_category', 'title', 'en'),
    ).toBeUndefined();
    expect(
      loadTemplate('chat_urgent', 'nonexistent_field', 'en'),
    ).toBeUndefined();
  });
});
