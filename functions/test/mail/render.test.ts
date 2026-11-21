/**
 * Spec #233 Req 53: each email is rendered on the server from a template, in
 * the recipient's language, with the event's own words and no money amounts.
 */
import {renderEmail, MailRenderError} from '../../src/mail/render';

describe('renderEmail', () => {
  test('renders the English template with its placeholders', () => {
    const mail = renderEmail({template: 'deliveryCheck', language: 'en', data: {name: 'Asha'}});
    expect(mail.subject).toBe('CrewPoint email check');
    expect(mail.text).toContain('Hello Asha');
    expect(mail.html).toContain('Hello Asha');
  });

  test('renders Gujarati when the recipient chose it', () => {
    const mail = renderEmail({template: 'deliveryCheck', language: 'gu', data: {name: 'Savita'}});
    expect(mail.subject).toBe('CrewPoint ઇમેઇલ તપાસ');
    expect(mail.text).toContain('Savita');
  });

  test('falls back to English for an unknown language', () => {
    const mail = renderEmail({template: 'deliveryCheck', language: 'fr', data: {name: 'A'}});
    expect(mail.subject).toBe('CrewPoint email check');
  });

  test('fills event words from the event labels, else the defaults', () => {
    const renamed = renderEmail({
      template: 'deliveryCheck', language: 'en', data: {name: 'A'},
      labels: {group: {one: 'Family', other: 'Families'}},
    });
    expect(renamed.text).toContain('your family');
    const plain = renderEmail({template: 'deliveryCheck', language: 'en', data: {name: 'A'}});
    expect(plain.text).toContain('your group');
  });

  test('escapes HTML in placeholder values but not in plain text', () => {
    const mail = renderEmail({template: 'deliveryCheck', language: 'en', data: {name: '<b>x</b>'}});
    expect(mail.html).toContain('&lt;b&gt;x&lt;/b&gt;');
    expect(mail.html).not.toContain('<b>x</b>');
    expect(mail.text).toContain('<b>x</b>');
  });

  test('refuses money values', () => {
    for (const key of ['amount', 'totalDue', 'fee', 'price', 'balance', 'cost']) {
      expect(() => renderEmail({template: 'deliveryCheck', language: 'en', data: {name: 'A', [key]: '10'}}))
        .toThrow(MailRenderError);
    }
  });

  test('refuses an unknown template', () => {
    expect(() => renderEmail({template: 'nope', language: 'en', data: {}})).toThrow(MailRenderError);
  });

  test('gives a short push title and body from the same template', () => {
    const mail = renderEmail({template: 'deliveryCheck', language: 'en', data: {name: 'A'}});
    expect(mail.push.title).toBe('CrewPoint email check');
    expect(mail.push.body.length).toBeGreaterThan(0);
  });

  test('every template has the same keys and placeholders in every language', () => {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const en = require('../../src/mail/templates/en.json');
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const gu = require('../../src/mail/templates/gu.json');
    const holes = (s: string) => (s.match(/\{\{[\w.]+\}\}/g) ?? []).sort();
    expect(Object.keys(gu).sort()).toEqual(Object.keys(en).sort());
    for (const name of Object.keys(en)) {
      for (const part of Object.keys(en[name])) {
        expect(holes(gu[name][part])).toEqual(holes(en[name][part]));
        expect(en[name][part]).not.toMatch(/\{\{[^}]*(amount|price|fee|total|balance|cost)/i);
      }
    }
  });
});
