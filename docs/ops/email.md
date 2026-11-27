# Email

Registration emails (Spec #233 Req 51–54) go out through one provider, **Resend**, from an outbox that only server code writes.

## How a message travels

1. Server code calls `enqueueEmail` (`functions/src/mail/outbox.ts`). This writes `mailOutbox/{id}` with `status: queued`, the recipient, the template, its values, and optionally the account, the event and whether to push as well.
2. `onMailQueued` (`functions/src/mail/send.ts`) picks the message up and handles it once. It renders the template from `functions/src/mail/templates/{en,gu}.json` in the recipient's language: the message's `language`, otherwise the account's `language`, otherwise English. It fills in the event's own words, and refuses any money value.
3. It checks `serverConfig/mail`, then sends through the `EmailTransport`.
4. The message document is its own delivery log. It ends with:
   - `status`: one of `sent`, `failed` or `notSent`;
   - `reason`, `providerId`, `subject` and `attempts`;
   - `sentAt` or `updatedAt`.
5. If the message asked for a push and the email went, the recipient's devices also get a push (category `registration`).

Clients can't read or write `mailOutbox` or `serverConfig` (`firestore.rules`).

## Settings: `serverConfig/mail`

Set these from the console or with the Admin SDK. A missing document means nothing is sent.

| Field | Meaning |
|---|---|
| `deliveryEnabled` | `true` to send at all. Leave it `false` until the sending domain's SPF, DKIM and DMARC records are in place. |
| `from` | The sender, for example `CrewPoint <no-reply@mail.example.org>`. It must be on the domain verified in Resend. |
| `allowedRecipients` | The only addresses emailed in dev and staging (Req 51a). Anyone else is logged as "Not sent: not on the dev allowed list". A plus-address of a listed address (`name+family2@gmail.com` for `name@gmail.com`) counts as listed, because it reaches the same inbox, so testers can sign up as many people as they need. |

Only `crewpoint-prod` emails everyone.

## Before the first deploy that includes `onMailQueued`

The function declares the `RESEND_API_KEY` secret, and a deploy fails if the secret is missing from that project. Create it first, once per project:

```bash
firebase functions:secrets:set RESEND_API_KEY --project crewpoint-dev
```

## Turning on real delivery

1. Choose the sending domain (an Open Question in Spec #233, needed by early January 2027 so the domain can warm up before February).
2. Add the domain in Resend and publish its SPF, DKIM and DMARC records.
3. Set `from` and `allowedRecipients`, then set `deliveryEnabled: true`.
4. Send the `deliveryCheck` template to Gmail, Outlook and Yahoo inboxes on the allowed list (O-04), and check that the messages show `sent` and arrive outside spam. This is a manual check on the release checklist.

## Tests

Automated tests never send real email (N-00):
- Under the emulators and `demo-` projects, the default transport refuses to send, so messages end as `notSent` with "Not sent: test environment".
- Tests pass `MockTransport` to `processOutboxMessage`.
- `ResendTransport` is tested with a fake `fetch`.
