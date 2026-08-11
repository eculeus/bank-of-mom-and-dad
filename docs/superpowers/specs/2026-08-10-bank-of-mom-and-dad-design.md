# Bank of Mom and Dad — Design Spec

**Date:** 2026-08-10
**Status:** Approved

## Overview

A family allowance ledger. Parents track virtual money they hold for their kids; kids see their balance, browse history, and request transactions. Ships as an installable Flutter web PWA with push notifications; the same codebase later compiles to native iOS for the App Store (Approach A — approved).

## Architecture

- **Client:** Flutter (stable channel), single codebase. Web/PWA is the first deploy target; native iOS/Android later.
  - State: Riverpod. Routing: go_router. Money handling: integer cents everywhere; `intl` for `$1,234.56` formatting.
- **Backend:** Firebase on the owner's account, Blaze plan (approved).
  - **Auth:** Google sign-in (popup on web). Email/password provider enabled solely for test accounts, UI exposed only under `--dart-define=TEST_MODE=true`.
  - **Firestore:** all app data. Security rules enforce membership + role.
  - **Cloud Functions (Node 20+):** balance maintenance, request decisions, notifications (with throttle), account lifecycle, seeding support.
  - **FCM:** web push via `firebase-messaging-sw.js` service worker; native push later reuses the same topics/token model.
  - **Hosting:** serves the PWA (manifest.json, icons, service workers).

### Platform constraints (accepted)

- iOS/iPadOS: push requires iOS 16.4+ AND installation via Safari → Share → Add to Home Screen. In a plain Safari tab, the app shows a friendly install banner with step-by-step instructions. iOS web push can be delayed relative to native push — accepted for the pilot; App Store build fixes it later.
- Android/desktop Chrome: standard PWA install + push, no caveats.

## Data model (Firestore)

```
users/{uid}
  displayName, email, photoURL
  fcmTokens: array<string>  // FCM registration tokens
  activeFamilyId: string | null
  createdAt, deletedAt: timestamp | null

families/{familyId}
  name, ownerUid, createdAt

families/{familyId}/members/{memberId}
  email            // lowercase; the invite key
  uid              // null until the invited person first signs in
  role             // 'parent' | 'kid'
  displayName      // set by inviting parent; editable by the member after join
  status           // 'invited' | 'active' | 'disabled' | 'deleted'
  isOwner          // true for the family creator only
  balanceCents     // kids only; maintained ONLY by Cloud Function
  lastSeenAt       // set when the member opens the app (drives kid animations)
  createdAt, joinedAt

families/{familyId}/transactions/{txId}
  kidMemberId
  amountCents      // signed integer; positive = deposit, negative = deduction
  reason           // required, short text
  date             // user-picked transaction date (not necessarily createdAt)
  note             // optional, long text
  source           // 'parent' | 'request' | 'seed' | 'adjustment'
  requestId        // set when source == 'request'
  createdByUid, createdAt, editedAt: timestamp | null

families/{familyId}/requests/{reqId}
  kidMemberId
  amountCents      // signed; kids may request deposits or cash-outs
  reason           // required
  date             // required, defaults to today
  note             // optional
  status           // 'pending' | 'approved' | 'denied'
  decidedByUid, decidedAt
  hiddenByKid      // kid can hide processed requests from their view; never deleted
  createdAt

families/{familyId}/notificationState/{parentUid}
  lastRequestPushAt   // drives the 10-minute throttle
```

### Design notes

- **Balances are server-authoritative.** A Firestore trigger on transaction create/update/delete recomputes the kid's `balanceCents` (transactional read-modify-write of the delta; full re-sum available as a repair function). Clients never write balances; rules forbid it.
- **Email-keyed invites.** On first sign-in, a callable function looks up `members` docs (collection-group query on `email`) matching the user's verified email, sets `uid`, flips `invited → active`. This is how kids auto-join and how co-parents join.
- **Multi-family:** membership docs make family membership many-to-many. Users with >1 active membership get a family switcher in the app bar; `activeFamilyId` remembers the last choice. Parents can create additional families at any time.
- **All deletion is soft.** Transaction history is never deleted, per the owner. Statuses do the work.

## Roles & permissions

| Action | Kid | Parent | Primary owner |
|---|---|---|---|
| View own balance/history | ✔ | — | — |
| View all kids' balances/history | — | ✔ | ✔ |
| Create transactions (±) | — | ✔ | ✔ |
| Edit/delete transactions | — | own entries only | own entries only |
| Submit requests | ✔ | — | — |
| Approve/deny requests | — | ✔ | ✔ |
| Add/remove kids | — | ✔ | ✔ |
| Add co-parents | — | ✔ | ✔ |
| Delete/disable the family | — | — | ✔ |
| Create additional families | — | ✔ | ✔ |

USD only. Negative kid balances allowed. Requests are immutable once submitted (no edits — kid resubmits anew if denied).

## Flows

### Onboarding
1. Google sign-in.
2. Existing membership(s) found → straight to the right home screen (role from membership).
3. No membership → "Are you a Parent or a Kid?"
   - **Parent** → create-family wizard: family name → add kids (name + email each) → optionally add co-parent emails → dashboard.
   - **Kid** → check invites by email. Match → celebratory join animation → kid home. No match → "Ask your parent to add your email (<email>)" screen with sign-out button.

### Parent: record a transaction (the Big Red Button)
FAB visible on the dashboard → sheet: kid picker → amount keypad with +/− toggle → reason → date (defaults today) → optional note → confirm with a satisfying animation. Notifies the kid and other parents immediately.

### Parent: requests inbox
Dashboard badge with pending count → list → detail → Approve or Deny.
- **Approve** (callable function, atomic): create ledger transaction (`source: 'request'`), mark request `approved`, push to kid: "Your request for $X was approved and added to your account!"
- **Deny:** mark `denied`, push to kid: "Your request for $X was denied — please talk to <deciding parent's name>."

### Kid: home
- Big balance. If `now − lastSeenAt ≥ 1 hour`: count-up + slight font-size bounce animation; transactions with `createdAt > lastSeenAt` get a highlight glow that fades after a few seconds. Then `lastSeenAt` updates.
- History below, sorted by `date` descending. Notes clamp to 2 lines (~80 chars) with an expand chevron.
- Requests tab: submit new (amount ±, reason, date, note); list all own requests with status chips (pending/approved/denied); "hide" action on processed requests (sets `hiddenByKid`; DB retains everything).
- Confetti when viewing a newly-approved deposit.

## Notifications (Cloud Functions + FCM)

| Event | Recipient | Timing | Copy |
|---|---|---|---|
| Kid submits request | all parents in family | throttled: max 1 push per 10 min per parent; extra requests inside the window are absorbed (in-app badge is source of truth) | "New transaction request from <kid>" / "You have new transaction requests" |
| Parent creates transaction | affected kid | immediate | "You received a new deposit of $30.00 in your account!" (or "…a deduction of $5.00…") |
| Parent creates/edits/deletes transaction | other parents | immediate | "<Parent> added $30.00 to <kid>: <reason>" |
| Request approved | kid | immediate | "Your request for $30.00 was approved and added to your account!" |
| Request denied | kid | immediate | "Your request for $30.00 was denied — please talk to <parent>." |
| Kid deletes account | all parents | immediate | "<Kid> deleted their Bank of Mom and Dad account." |

Throttle mechanics: on request creation, the trigger checks `notificationState/{parentUid}.lastRequestPushAt`; if ≥10 min ago, push and update it, else skip. Token hygiene: prune FCM tokens on `messaging/registration-token-not-registered` errors.

## Account lifecycle

- **Parent removes a kid** → member `status: 'disabled'`. Kid still signs in, sees balance + full history (read-only) under a clear "Your account is inactive — talk to your parents, or delete your account" banner. No requests allowed.
- **Kid deletes own account** → membership `status: 'deleted'`, parents notified, Firebase Auth user deleted, all ledger data retained.
- **Co-parent deletes own account** → their membership marked deleted; family unaffected.
- **Primary owner deletes account** → every kid membership in every family they own → `disabled`; family data retained forever.

## Seeding (real family)

Family membership and target balances are defined in a local, gitignored config (`scripts/seed/family.config.json`, copied from the example config) — never committed. The older archive tab of the source spreadsheet ("STOP" markers, 2020–2022) is excluded from seeding.

- One-time Node script using `firebase-admin` against production, run manually.
- Creates the family and its members (parents + kids) as defined in the config.
- Parses a CSV export of the source spreadsheet. Handles the mess: missing years inferred from neighboring rows' years (monotonic-ish ordering), bare numbers → dollars, `-$X` and `\-$X` forms, obvious typo years corrected; the script logs every such correction. Exact per-row dates matter less than the closing balances matching.
- All rows inserted as transactions with `source: 'seed'`.
- Reconciliation: after insert, computed balance per kid is compared to the config's expected totals. Any difference is closed with one final `source: 'adjustment'` transaction ("Balance adjustment — spreadsheet import") so the app matches the source exactly on day one.

## Security rules (shape)

- `users/{uid}`: read/write self only.
- Family docs: readable by active members; family creation via authenticated client; membership edits by parents only (kids can update only their own `lastSeenAt`, `displayName`, and `hiddenByKid` on their requests).
- Transactions: create/update/delete by parents of that family only, and update/delete only where `createdByUid == auth.uid`; `balanceCents` writable by Functions (Admin SDK bypasses rules; client writes to it denied).
- Requests: create by the kid member themselves (`status` forced to `'pending'`); decisions only via the callable function.
- All money fields validated as integers; `email` fields lowercased.

## Error handling

- Offline/poor network: Firestore's built-in offline cache keeps reads working; writes queue. UI shows a subtle offline chip.
- Callable function failures (approve/deny, join): inline retryable error states, never silent.
- Push permission denied: app works fully without push; a dismissible card explains what they're missing and how to enable.
- Balance drift (should never happen): admin "recompute balances" function; a scheduled daily audit compares stored vs summed balances and logs discrepancies.

## Testing

- **Unit:** money parsing/formatting, date-year inference (seed parser), throttle window logic, balance delta math.
- **Widget:** kid home (animation trigger conditions, highlight logic, note clamp/expand), parent dashboard (badge counts), big-red-button flow validation.
- **E2E:** Chrome + browser automation against `flutter run -d chrome` with the **Firebase Emulator Suite** (auth/firestore/functions). Email/password test accounts (`test-parent@bomad.test`, `test-parent2@bomad.test`, `test-kid@bomad.test`) exist only in the emulator/test project and the sign-in form for them only renders under `TEST_MODE`. A seed-test-data script creates a synthetic test family; real family data never touched by tests.

## Visual style

Bright, festive, kid-first: saturated palette with a signature color per kid, big rounded cards, playful display typeface for balances, count-up number animations, springy press effects, confetti on deposits/approvals. Deposits green with ＋, deductions warm red with −. Parent screens share the design language, slightly calmer. Light theme only for v1.

## Recurring payments/debits (added 2026-08-10 during build, per the owner)

Parents can create recurring templates per kid (multiple per kid): amount (±), reason, optional note, interval (weekly or monthly), first due date. A daily scheduled function (09:00 America/New_York) turns due templates into `pending` requests (`origin: 'recurring'`) in the existing parent inbox — approving creates the ledger transaction, denying skips that occurrence; either way the template advances to its next due date (monthly clamps day to month length). Parents get the standard throttled request push with recurring-specific copy. Templates are hard-deletable (config, not history); no editing — delete and recreate. Kids see recurring-origin requests in their Requests tab like any other. A parent-only `runRecurringNow` callable sweeps one family on demand (testing/catch-up).

## Out of scope (v1)

Recurring/scheduled allowances, interest, multi-currency, request editing, hard data deletion, App Store build (later phase), Android-specific polish beyond "works correctly."
