---
effective_date: TBD
last_updated: TBD
counsel_review_date: TBD
counsel_name: TBD
version: 1.1
---

# CrewPoint Privacy Policy

**Effective:** TBD &nbsp;•&nbsp; **Last updated:** TBD

This is a counsel-pending draft (version 1.1, adding children and Canada). It is not in force until a lawyer has approved it. The "Minimum Viable Data" ethos is the spine of how we treat your information. Plain language first; legal precision second.

## Who we are

CrewPoint is operated by **Sookoon** (the "Company", "we", "our", "us"). For privacy questions or to exercise the rights in this policy, contact **privacy@sookoon.space**.

## What this policy covers

Your use of the CrewPoint mobile and web apps, and the information organizers enter about the people attending their events, including people who have no CrewPoint account. The hosted versions of this document and our Terms of Service live at `https://crewpoint.sookoon.space/privacy` and `/terms`.

## Minimum Viable Data — our promise

- **We don't sell your data.** Not to advertisers, not to data brokers, not to "marketing partners". Ever.
- **We don't track your location** (yet). The product roadmap includes geofence reminders. Before any location data is collected, this policy will be updated and you will be notified in-app.
- **Financial records are anonymized — not deleted — when you delete your account.** This protects the historical ledger for the rest of your group; see *Account deletion* below.

## Data we collect

Listed exhaustively against the actual schema:

- **Account identity** (Firebase Authentication): user ID, email address, sign-in provider IDs (`password`, `google.com`, `apple.com`), display name, profile photo URL.
- **Event-domain content**: events you create or join, messages, tasks (titles, assignees, status), expenses (amount, payer, splits), receipt image uploads.
- **Your role in each event**: the roles an organizer gives you (such as Admin, Finance or Volunteer), the crews you are in, and when you joined.
- **Payment handles you choose to add** (such as a Venmo or Cash App name), so people you share an event with can pay you back.
- **Device tokens**: Firebase Cloud Messaging (FCM) registration tokens used to deliver push notifications. Stored in a self-only subcollection of your user document.
- **Preferences**: currency, time zone, notification choices and opt-in flags. Stored in the same self-only subcollection.

### Information organizers enter about attendees

An event's organizers can record the people attending, whether or not they have a CrewPoint account: names, the group they belong to (such as a household or team), arrival and departure times, and any extra questions the organizer chooses to ask, such as dietary needs. Organizers decide what they ask for. We ask them to collect only what the event needs, and to tell attendees why. Details an organizer marks as private are stored separately and shown only to people whose role has permission to see them.

> Counsel to confirm how the roles of organizer and CrewPoint are described for attendee data (for example, controller and processor under the GDPR).

We do **not** collect, for your own account: phone numbers (unless you choose to share one as a payment handle), physical address, birthday, demographics, advertising IDs, contacts, social graph, location, or browsing history. An organizer may ask attendees for some of these for their event; see *Information organizers enter about attendees* above.

## How we use your data

Only to operate the CrewPoint service. Specifically:

1. Authenticate you and keep your session alive.
2. Display the events, messages, tasks, and expenses you and your groups create.
3. Deliver push notifications for urgent in-event activity.
4. Settle balances within your groups using the payment handles you choose to share.
5. Show each person in an event only what their role allows (see *Who can see what* below).

We do not use your data to train external AI/ML models. We do not share your data with third parties for their own marketing purposes. The third-party services we depend on to deliver CrewPoint are listed under *Third-party services* below.

## Who can see what

- **Your name, photo and payment handles** are visible only to people who share an event with you, and only in that event. If you leave an event, people in it still see your name on things you wrote or paid for, but no longer see your payment handles.
- **Event details** such as tasks, expenses and chat are visible according to the roles the event's organizers give people. For example, a Vendor sees only their own tasks and payments.
- **Expenses**: an event's organizers choose who can see every expense: everyone in the event, only the people involved in each expense, or selected roles and people. Whatever they choose, you always see the expenses you paid for or share in, and your own balance.
- **Task budgets** are visible only to roles that can read the event's budget.

## Your rights

### Under the GDPR (EU/EEA) and the UK GDPR

- **Right to access** (Art. 15) — request a copy of your data.
- **Right to rectification** (Art. 16) — correct inaccurate data.
- **Right to erasure** (Art. 17) — delete your account; see *Account deletion* below for the per-record nuance.
- **Right to data portability** (Art. 20) — receive your data in a machine-readable format.
- **Right to restriction** (Art. 18) and **objection** (Art. 21) — limit or stop specific processing activities.
- **Automated decision-making opt-out** (Art. 22) — we don't currently make automated decisions that produce legal effects, but you may opt out of any future ones.

To exercise any of these, email **privacy@sookoon.space** from the email address attached to your account. UK users may also complain to the Information Commissioner's Office (ico.org.uk).

### Under Canadian privacy law

If you are in Canada, the Personal Information Protection and Electronic Documents Act (PIPEDA) and, where they apply, provincial laws such as Quebec's Law 25 and the private-sector privacy laws of Alberta and British Columbia give you these rights:

- **Access** — ask what personal information we hold about you and how it has been used and shared.
- **Correction** — ask us to correct information that is inaccurate or incomplete.
- **Withdraw consent** — withdraw your consent to our use of your information at any time, subject to legal or contractual limits. Withdrawing may mean we can no longer provide parts of CrewPoint, and we will tell you what that means for you.
- **Deletion** — delete your account; see *Account deletion* below.
- **In Quebec**, you may also ask for your information in a structured, commonly used technological format, and to be informed of and object to decisions made only by automated processing. We do not make such decisions.

**Cross-border storage.** CrewPoint stores data in the United States (see *Data residency*). While it is there, it is subject to the laws of the United States, and may be accessible to courts, law enforcement and national security authorities there.

Our privacy contact is **privacy@sookoon.space**. We answer requests within 30 days. If you are not satisfied with our response, you may complain to the Office of the Privacy Commissioner of Canada (priv.gc.ca), or to your provincial commissioner, such as the Commission d'accès à l'information du Québec.

> Counsel to confirm the person in charge of the protection of personal information that Quebec's Law 25 requires us to name, and whether a privacy impact assessment is needed for storing Quebec residents' data outside Quebec.

### Under the CCPA (California)

- **Right to know** what personal information we collect, use, and disclose.
- **Right to delete** your personal information, subject to the lawful exceptions described below.
- **Right to opt out of sale** — moot. We don't sell.
- **Right to non-discrimination** — exercising any of the above will not affect your access to CrewPoint.

## Account deletion

When you delete your CrewPoint account from **Profile → Delete Account**, we run a server-side process that:

1. **Solo events** (events where you are the only member) are permanently deleted, including all messages, tasks, expenses, and receipts.
2. **Shared events** (events with other members) survive. In each one, your account ID is replaced with an anonymous ID in messages, expenses, splits and tasks, so the group's balances still add up. A different anonymous ID is used in each event, and two people who delete their accounts are never merged. Tasks assigned to you become unassigned.
3. If you **own** a shared event, ownership passes automatically to a Co-owner, or else to the longest-standing Admin, or else to the longest-standing member.
4. Your membership, roles, and your name, photo and payment handles in every event are deleted, as are your profile, your private subdocument (email, FCM tokens, preferences), and your chat read and notification settings.
5. **Children you entered** into an event are deleted with your account, unless another linked adult remains in their group.
6. Files in your storage folder (profile photo, etc.) are deleted.
7. Your Firebase Authentication account is deleted last.

This is irreversible.

The anonymized record in shared events is retained indefinitely by default to preserve the historical ledger for the rest of the group. To request **per-event erasure** of an anonymized record, contact **privacy@sookoon.space** after deletion. We process these requests manually for V1.

## Retention

- **Receipts and financial records** in shared events: anonymized indefinitely.
- **Messages** tied to a deleted account: anonymized indefinitely.
- **FCM tokens**: deleted on sign-out and on account deletion.
- **Profile photos and storage files**: deleted on account deletion.

## Children

**Accounts.** You must be 13 or older to create a CrewPoint account, or older where the law where you live requires it (for example, 14 in Quebec, and up to 16 in some EU countries). We do not knowingly let a child below that age create an account. If you believe one has, contact **privacy@sookoon.space** and we will delete it.

> Counsel to confirm these ages for each country we serve, and whether to raise the floor to 16 everywhere.

**Children at events.** Many events include children, such as a convention registering a household with young children. Children do not have CrewPoint accounts. Their details can be entered only by:

- a **parent or guardian** linked to the child's group in the event, or
- an **organizer** whose role has permission to manage the event's attendees.

The person entering a child's details is responsible for having the right to do so. Organizers should collect only what the event needs, such as a name, an age or age group, and dietary or medical needs that keep the child safe.

**Who sees a child's details.** A child's birth date, and any detail the organizer marks as private, are shown only to people whose role has permission to read private attendee details. Event reports and counts show age bands, such as "child" or "adult", rather than birth dates. Volunteers and committee members see only what their role allows.

**Parents' choices.** A parent or guardian can ask the event's organizers, or us at **privacy@sookoon.space**, to see, correct or delete their child's details. When a parent or guardian deletes their account, the children they entered are deleted too, unless another linked adult remains in the child's group. We never use children's details for advertising, profiling or anything other than running the event.

> Counsel to review this section against COPPA (where it applies), the GDPR and UK Age Appropriate Design Code, and Canadian guidance on minors' information, including whether a parent's consent must be recorded when a child's details are entered.

## Data residency

CrewPoint runs on Google Firebase. Default region is `us-central1` (Iowa, USA). If we add additional regions or migrate to a new default, this policy will be updated and you will be notified in-app at least 30 days before the move.

## Security

- Firebase Authentication for sign-in. We never see or store your password — Google does, hashed and salted.
- TLS 1.2+ in transit. Encryption at rest is provided by Google Cloud Platform.
- Per-document Firestore security rules gate every read and write, following each person's role in each event. PII (email, FCM tokens, preferences) lives in a self-only subcollection that no other CrewPoint user can read. Money figures and attendees' private details are kept in separate records that only permitted roles can read.
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

If you feel your concern was not adequately addressed, you may contact your local data protection authority: in the EU/EEA, your national authority; in the UK, the Information Commissioner's Office; in Canada, the Office of the Privacy Commissioner of Canada or your provincial commissioner.
