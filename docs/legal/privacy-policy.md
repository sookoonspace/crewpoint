---
effective_date: TBD
last_updated: TBD
counsel_review_date: TBD
counsel_name: TBD
version: 1.0
---

# CrewPoint Privacy Policy

**Effective:** TBD &nbsp;•&nbsp; **Last updated:** TBD

This is a V1 counsel-pending draft. The "Minimum Viable Data" ethos is the spine of how we treat your information. Plain language first; legal precision second.

## Who we are

CrewPoint is operated by **Sookoon** (the "Company", "we", "our", "us"). For privacy questions or to exercise the rights in this policy, contact **privacy@sookoon.space**.

## What this policy covers

Your use of the CrewPoint mobile and web apps. The hosted versions of this document and our Terms of Service live at `https://crewpoint.sookoon.space/privacy` and `/terms`.

## Minimum Viable Data — our promise

- **We don't sell your data.** Not to advertisers, not to data brokers, not to "marketing partners". Ever.
- **We don't track your location** (yet). The product roadmap includes geofence reminders. Before any location data is collected, this policy will be updated and you will be notified in-app.
- **Financial records are anonymized — not deleted — when you delete your account.** This protects the historical ledger for the rest of your group; see *Account deletion* below.

## Data we collect

Listed exhaustively against the actual schema:

- **Account identity** (Firebase Authentication): user ID, email address, sign-in provider IDs (`password`, `google.com`, `apple.com`), display name, profile photo URL.
- **Event-domain content**: events you create or join, messages, tasks (titles, assignees, status), expenses (amount, payer, splits), receipt image uploads.
- **Device tokens**: Firebase Cloud Messaging (FCM) registration tokens used to deliver push notifications. Stored in a self-only subcollection of your user document.
- **Preferences**: currency, opt-in flags. Stored in the same self-only subcollection.

We do **not** collect: phone numbers (unless you choose to share one as a payment handle), physical address, birthday, demographics, advertising IDs, contacts, social graph, location, or browsing history.

## How we use your data

Only to operate the CrewPoint service. Specifically:

1. Authenticate you and keep your session alive.
2. Display the events, messages, tasks, and expenses you and your groups create.
3. Deliver push notifications for urgent in-event activity.
4. Settle balances within your groups using the payment handles you choose to share.

We do not use your data to train external AI/ML models. We do not share your data with third parties for their own marketing purposes. The third-party services we depend on to deliver CrewPoint are listed under *Third-party services* below.

## Your rights

### Under the GDPR (EU/EEA/UK)

- **Right to access** (Art. 15) — request a copy of your data.
- **Right to rectification** (Art. 16) — correct inaccurate data.
- **Right to erasure** (Art. 17) — delete your account; see *Account deletion* below for the per-record nuance.
- **Right to data portability** (Art. 20) — receive your data in a machine-readable format.
- **Right to restriction** (Art. 18) and **objection** (Art. 21) — limit or stop specific processing activities.
- **Automated decision-making opt-out** (Art. 22) — we don't currently make automated decisions that produce legal effects, but you may opt out of any future ones.

To exercise any of these, email **privacy@sookoon.space** from the email address attached to your account.

### Under the CCPA (California)

- **Right to know** what personal information we collect, use, and disclose.
- **Right to delete** your personal information, subject to the lawful exceptions described below.
- **Right to opt out of sale** — moot. We don't sell.
- **Right to non-discrimination** — exercising any of the above will not affect your access to CrewPoint.

## Account deletion

When you delete your CrewPoint account from **Profile → Delete Account**, we run a server-side process that:

1. **Solo events** (events where you are the only member) are permanently deleted, including all messages, tasks, expenses, and receipts.
2. **Shared events** (events with other members) survive. Your name and account ID are replaced with `deleted_user` in messages, expenses, and task assignments. Ownership is transferred to the first remaining admin (or, if none, the first remaining member).
3. Your profile data (public projection) and your private subdocument (email, FCM tokens, preferences) are deleted.
4. Files in your storage folder (profile photo, etc.) are deleted.
5. Your Firebase Authentication account is deleted last.

This is irreversible.

The anonymized record in shared events is retained indefinitely by default to preserve the historical ledger for the rest of the group. To request **per-event erasure** of an anonymized record, contact **privacy@sookoon.space** after deletion. We process these requests manually for V1.

## Retention

- **Receipts and financial records** in shared events: anonymized indefinitely.
- **Messages** tied to a deleted account: anonymized indefinitely.
- **FCM tokens**: deleted on sign-out and on account deletion.
- **Profile photos and storage files**: deleted on account deletion.

## Children

CrewPoint is intended for users 13 years of age or older. We do not knowingly collect data from children under 13. If you believe a child under 13 has created a CrewPoint account, contact **privacy@sookoon.space** and we will delete the account.

> Counsel may move this floor to 16 to align with the GDPR's strictest interpretation. To be confirmed at counsel review.

## Data residency

CrewPoint runs on Google Firebase. Default region is `us-central1` (Iowa, USA). If we add additional regions or migrate to a new default, this policy will be updated and you will be notified in-app at least 30 days before the move.

## Security

- Firebase Authentication for sign-in. We never see or store your password — Google does, hashed and salted.
- TLS 1.2+ in transit. Encryption at rest is provided by Google Cloud Platform.
- Per-document Firestore security rules gate every read and write. PII (email, FCM tokens, preferences) lives in a self-only subcollection that no other CrewPoint user can read.
- Cloud Functions use the Firebase Admin SDK and run in an isolated environment.

We do **not** offer end-to-end encryption for chat messages in V1. Server-side admins have technical access to message contents. E2EE is on the roadmap but not part of V1; we'll update this policy before it ships.

## Third-party services

CrewPoint depends on the following Google services to operate. Each has its own privacy policy.

- Firebase Authentication, Cloud Firestore, Firebase Storage, Cloud Functions, Firebase Cloud Messaging, Firebase Hosting.
- Google Sign-In (OAuth).
- Sign in with Apple (OAuth).

We do not share data with advertising networks, analytics-for-advertising networks, or data brokers.

## Changes to this policy

We will publish material changes both in-app (via a notice the next time you open the app) and via email to the address attached to your account, at least 30 days before the change takes effect. Minor wording or formatting changes will be reflected in the `last_updated` field above without separate notice.

## Contact

Questions? Concerns? Rights requests? **privacy@sookoon.space**.

If you are an EU/EEA/UK user and feel your concern was not adequately addressed, you may contact your local data protection authority.
