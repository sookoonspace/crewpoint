# CrewPoint marketing-microsite brief

Deliverables this repo hands to the Sookoon marketing repo
(`/Users/googoo/Websites/sookoon_space`) so its Phase 5 PR can scaffold
the `/crewpoint/` microsite mirroring the existing `/sanctuary/` shape.

> **Scope.** Everything below is **content for the marketing repo**.
> No app code in `crewpoint_app` changes from this brief. The
> microsite itself (Next.js i18n routes, layouts, components, deploy
> via FTP per `DEPLOY_NAMECHEAP.md`) is authored in the marketing
> repo.

## Web-app URL

The "Open web app" CTA on `https://sookoon.space/crewpoint/` and on
`https://sookoon.space/crewpoint/download/` should link to:

```
https://crewpoint.sookoon.space
```

Open in a new tab: `target="_blank" rel="noopener noreferrer"`. Until
prod custom-domain DNS is live, link to
`https://crewpoint-prod.web.app` and update the marketing repo with a
single-line change once DNS resolves (no other content shifts).

## Brand assets

| Asset | Source path (this repo)              | Notes |
| ----- | ------------------------------------ | ----- |
| Launcher icon (raw 1024×1024) | `assets/icons/launcher_icon.png` | Resize for `/crewpoint/` hero (256×256) and the `/apps/` page card (96×96). Use marketing repo's existing `<Image>` pipeline. |
| Maskable icon set            | `web/icons/Icon-{192,512}.png` + `Icon-maskable-{192,512}.png` | Already in this repo's `web/` folder; ship as-is in the manifest. |
| Brand palette (hex)          | see `lib/app/core/constants/app_colors.dart` | `#2D3436` charcoal · `#6B9080` sage · `#CC704B` terracotta · `#EADDCE` cream. Use these in the `/crewpoint/` Tailwind classes mirror of `/sanctuary/`. |

## Copy strings

Use these as the canonical English source for `messages/en.json` keys
under `crewpointPage.*` and `appsPage.crewpoint.*`. ES + HI
translations can stub-fall-back to English in V1 (Sanctuary's
translation cadence is the precedent).

### Tagline

> **Collaborative event management for crews.**

### Hero subtitle

> Plan trips and group events end-to-end. Tasks with assignees and
> checklists. Splitwise-style expense tracking with deep-link
> Venmo / CashApp payouts. Real-time chat with opt-in urgent push for
> time-sensitive updates. By Sookoon.

### Feature bullets (`/apps/` card + microsite landing)

1. **Events with role-based access** — Owner, admin, and member
   roles enforced server-side. Promote, demote, archive, leave —
   every transition gated.
2. **Tasks** — To-do / in-progress / done status, assignees, due
   dates, and checklists. Server-stamped completion.
3. **Budget & settlements** — Per-event currency, expense splits
   with receipt uploads, and a balance ledger that surfaces the
   minimum payments needed to settle the group. Deep-link payouts
   to Venmo and CashApp.
4. **Chat with urgent push** — Live messaging mirrored locally for
   instant cold-start. Urgent messages fan out via FCM with
   foreground-banner suppression on the chat screen itself.

### "Why CrewPoint" — short-form

> Most apps make you choose: project management OR trip
> management. CrewPoint pairs the two. Plan a backpacking trip,
> coordinate a wedding weekend, run a community event — same app,
> tasks and money in one place, chat that knows when to wake you up.

### CTA copy

| Surface | Label |
| ------- | ----- |
| Primary CTA on `/crewpoint/` and `/crewpoint/download/` | **Open web app** |
| Secondary on `/crewpoint/download/` (when listings ship) | App Store badge / Google Play badge — both deferred until V1 listing approval. |

## FAQ

For `app/[locale]/crewpoint/faq/page.tsx`. Sanctuary's FAQ shape is
the reference.

**Q: What is CrewPoint?**
A: A collaborative app for organizing crews — backpacking trips,
weddings, community events, anything where a small group needs to
share tasks, split expenses, and stay in sync.

**Q: How is it different from Sanctuary?**
A: Sanctuary is anonymous and solo-focused. CrewPoint is the
opposite: identity-aware (you sign in), group-oriented, and centered
on shared work and shared money. Both ship under the Sookoon umbrella
because they solve different needs of the same people.

**Q: Is there a web version?**
A: Yes. Open `crewpoint.sookoon.space` in any modern browser.
Mobile apps are also available *(when listings ship)*.

**Q: How do payouts work?**
A: When the balance ledger flags a settlement, CrewPoint deep-links
into Venmo or CashApp pre-filled with the right amount and a note.
You confirm in the originating app and CrewPoint records the
settlement so the ledger rebalances. CrewPoint never holds funds.

**Q: How is chat secured?**
A: Messages are stored in Firebase Firestore with member-only access
rules. End-to-end encryption is on the roadmap but not in V1.

**Q: How do I delete my account?**
A: Profile → Delete account. A server-side Cloud Function anonymizes
shared data, deletes solo events, removes your storage objects, and
deletes your Auth user. Group event content (where other members
contributed) is anonymized rather than deleted to preserve the
shared record.

**Q: Who is Sookoon?**
A: Sookoon Space is the umbrella brand. CrewPoint is one of two
apps; Sanctuary (anonymous reflection) is the other. See
**[About Sookoon](/about)**.

## Privacy policy (English V1)

Use as the body of `app/[locale]/crewpoint/privacy/page.tsx`. Keep
Sanctuary's React/TSX page shell; replace the body with this content.

> **Effective date:** 2026-04-29 · **Version:** 1.0
>
> CrewPoint is a collaborative app — unlike Sanctuary, we do collect
> data tied to your identity. This page tells you exactly what,
> why, and how long.
>
> ### What we collect
>
> - **Account**: email address, display name, profile photo (if you
>   add one), and the authentication provider you used (email,
>   Google, or Apple).
> - **Profile (optional)**: Venmo handle, CashApp handle. Used only
>   to construct deep links into those apps when settling balances.
>   We never call those services on your behalf.
> - **Event content you create**: events, tasks, expenses, expense
>   splits, receipt images, chat messages.
> - **Membership data**: which events you belong to and your role in
>   each (owner, admin, member).
> - **Push tokens**: Firebase Cloud Messaging tokens for opt-in
>   urgent message notifications. Stored under your user document.
>
> ### What we don't collect
>
> - Location data.
> - Browsing history outside CrewPoint.
> - Contacts list.
> - Payment card details — settlements happen inside Venmo /
>   CashApp; CrewPoint only opens the deep link.
>
> ### Where it lives
>
> All data is stored in Google Firebase (Cloud Firestore for
> structured data, Cloud Storage for receipt images). Receipts are
> served only to authenticated members of the event the receipt
> belongs to. Server-side Firebase rules enforce access at the
> protocol layer; client-side gating is double-enforcement, not the
> sole defense.
>
> ### Sharing
>
> We do not sell your data. We do not run ads. We do not share your
> data with third parties except:
>
> - Google Firebase, our infrastructure provider, processes data on
>   our behalf under their data-processing terms.
> - Apple, Google, or your email provider, when you sign in via that
>   provider.
> - Venmo and CashApp, only the deep links you trigger by tapping
>   "Settle"; we don't share data outside those URLs.
>
> ### Retention and deletion
>
> Account data persists until you request deletion. Profile →
> Delete account triggers a Cloud Function that:
>
> - Anonymizes your contributions to events that have other members
>   (so the group's shared record stays intact but your name is
>   replaced with "(no longer in event)").
> - Deletes events where you were the sole member.
> - Removes your receipt images from Cloud Storage.
> - Removes your Firestore user document and your Firebase Auth
>   account.
>
> Backups may persist for a short window beyond deletion as part of
> Firebase's standard backup cadence; we don't restore individual
> users from those backups.
>
> ### Your rights
>
> Whatever your jurisdiction grants you (GDPR, CCPA, etc.) applies
> here. You can request a data export or deletion at
> **privacy@sookoon.space** — we'll respond within the deadline
> required by your local law.
>
> ### Changes
>
> Material changes are flagged on the home screen on next sign-in.
> Minor edits update the Effective Date at the top of this page.
>
> Questions? **privacy@sookoon.space**.

## Terms of Service (English V1)

Use as the body of `app/[locale]/crewpoint/terms/page.tsx`.

> **Effective date:** 2026-04-29 · **Version:** 1.0
>
> By using CrewPoint you agree to these terms. They're short.
>
> ### What CrewPoint is
>
> CrewPoint is a software service operated by Sookoon Space, a US
> company. It helps small groups coordinate events, tasks, expenses,
> and chat. CrewPoint does not move money on your behalf — it deep
> links to Venmo and CashApp, and you settle inside those apps.
>
> ### Your account
>
> You're responsible for the accuracy of the email address you sign
> in with and for keeping access to your account secure. We can
> suspend or close accounts that violate these terms, abuse other
> members, or attempt to compromise the service.
>
> ### Your content
>
> Anything you write, upload, or contribute (events, tasks, expense
> details, receipt images, chat messages) stays yours. By posting it
> in CrewPoint you grant Sookoon Space a non-exclusive license to
> store and display it back to you and to the members of the event
> it belongs to, for the duration of your membership in that event.
> Deleting your account anonymizes your contributions to shared
> events; see the privacy policy.
>
> ### Acceptable use
>
> Don't use CrewPoint for harassment, illegal coordination, fraud,
> or to scrape other members' data. Don't impersonate someone else
> or pay around the deep-link flow with the intent to deceive.
>
> ### Service availability
>
> We aim for high availability but don't promise uninterrupted
> service. Maintenance, infrastructure outages, and bugs happen. We
> ship fixes as fast as we reasonably can.
>
> ### Liability
>
> CrewPoint is provided "as is." Sookoon Space is not liable for
> indirect, incidental, or consequential damages arising from your
> use of the service to the maximum extent allowed by law.
>
> ### Disputes
>
> If you and Sookoon Space disagree, we'll try to resolve it
> directly first (legal@sookoon.space). Unresolved disputes go to
> binding arbitration in the state where Sookoon Space is registered.
>
> ### Changes
>
> Material changes flag on the home screen on next sign-in. Continued
> use after the effective date is acceptance.
>
> Questions? **legal@sookoon.space**.

## Community guidelines (English V1)

Use as the body of `app/[locale]/crewpoint/guidelines/page.tsx`.

> **Effective date:** 2026-04-29 · **Version:** 1.0
>
> CrewPoint is small-group software. The "community" is the people
> in your event. These guidelines are about how to use chat,
> expenses, and shared content responsibly within those groups.
>
> ### In chat
>
> - Mark a message **urgent** only when timing actually matters. The
>   urgent flag wakes other members' phones; abuse breaks the
>   trust the feature depends on.
> - Don't share other members' personal information (phone numbers,
>   addresses, payment details beyond what the deep-link flow needs)
>   in chat.
> - If a settlement is disputed, use the dispute path in chat to
>   record it — don't escalate in side channels first.
>
> ### In expenses
>
> - Use the donation toggle when the payer is also the entire group
>   (the split should exclude them).
> - Use the payment toggle when recording a real-world transfer that
>   you want reflected in the ledger (a cash-given-back-to-the-group
>   refund, for example).
> - Tag receipts honestly. Receipts are visible to every member of
>   the event.
>
> ### In tasks
>
> - Status changes are server-stamped. Don't try to forge completion
>   timestamps; the rules layer rejects it anyway.
> - Assign realistically. Tasks without an assignee are open to
>   anyone in the event.
>
> ### Reporting concerns
>
> - **Urgent safety issues**: contact local authorities first, then
>   email **safety@sookoon.space**.
> - **Other concerns** (harassment, fraud, abuse of the service):
>   email **safety@sookoon.space** with the event ID and message
>   IDs if relevant.
>
> ### Consequences
>
> We can remove offending content, suspend accounts, or kick
> accounts out of CrewPoint entirely. We do this rarely and never
> arbitrarily.

## `DEPLOY_NAMECHEAP.md` test-list update

The marketing repo's `DEPLOY_NAMECHEAP.md` Step 4 currently lists
Sanctuary URLs only. Add CrewPoint:

```
### CrewPoint App Pages
- https://sookoon.space/crewpoint/
- https://sookoon.space/crewpoint/about/
- https://sookoon.space/crewpoint/how-it-works/
- https://sookoon.space/crewpoint/download/
- https://sookoon.space/crewpoint/faq/
- https://sookoon.space/crewpoint/privacy/
- https://sookoon.space/crewpoint/terms/
- https://sookoon.space/crewpoint/guidelines/
- https://sookoon.space/crewpoint/contact/
```

## Marketing PR checklist

For the maintainer opening the PR in `sookoon_space`:

- [ ] `app/[locale]/crewpoint/page.tsx` + `layout.tsx` mirror the
      `/sanctuary/` shape; CrewPoint brand colors per the palette
      table above.
- [ ] Subroutes: `about, how-it-works, download, faq, privacy,
      terms, guidelines, contact` — each `page.tsx` lifted from
      this brief's body content, wrapped in the same React/TSX
      shell Sanctuary uses.
- [ ] Top-level `app/crewpoint/page.tsx` mirroring
      `app/sanctuary/page.tsx`'s `useRouter().replace('/${defaultLocale}/crewpoint')`.
- [ ] `app/[locale]/apps/page.tsx` adds a CrewPoint entry to the
      `apps` array (cream/sage/terracotta accents per the brand
      palette).
- [ ] `messages/en.json` adds `crewpointPage.*` and
      `appsPage.crewpoint.*` keys; `es.json` and `hi.json` mirror
      the keys with English fallback values.
- [ ] Primary "Open web app" CTA on `/crewpoint/` and
      `/crewpoint/download/` → `https://crewpoint.sookoon.space`,
      `target="_blank" rel="noopener noreferrer"`.
- [ ] `DEPLOY_NAMECHEAP.md` Step 4 test list extended (snippet
      above).
- [ ] Local smoke: `npm run build`; preview the routes; FTP-deploy
      to Namecheap per `DEPLOY_NAMECHEAP.md`.
- [ ] Final smoke: `curl https://sookoon.space/crewpoint/privacy/`
      returns the privacy page; "Open web app" navigates
      correctly; the apex marketing site is unchanged.
