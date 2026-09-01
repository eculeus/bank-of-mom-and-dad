# Premium / Freemium — Design Spec

**Date:** 2026-09-01
**Status:** Draft (for owner review)

## Overview

Add a paid **Premium** tier to Bank of Mom and Dad, gated behind an
auto‑renewing annual subscription bought through Apple in‑app purchase on iOS.
Premium unlocks on **every platform** (iOS + web) by syncing the entitlement to
the family's Firestore document. There is no web checkout (no Stripe); web users
who want premium subscribe from the iOS app.

### Decisions (owner-confirmed 2026-09-01)

| Decision | Choice |
|---|---|
| Purchase surface | iOS only (Apple IAP). Unlocks on iOS **and** web. |
| Price / model | **Annual only, $9.99/yr.** No monthly, no lifetime. |
| Entitlement scope | **Per family** — one parent buys, the whole family gets premium. |
| Free tier | 2 kids + full ledger (add/subtract, history, requests, approvals). |
| Premium adds | Unlimited kids · **receipt photos** · **CSV export** · **recurring templates**. |

Price is configured in App Store Connect (referenced by product ID in code), so
it can change later without an app update.

## Architecture

### Entitlement is server-authoritative (mirrors the balance model)

Premium status lives on the family document and is **written only by Cloud
Functions** (Admin SDK bypasses rules; client writes denied):

```
families/{familyId}
  premium: {
    active: bool,                 // true while the subscription is valid
    productId: string,            // "bomad_premium_yearly"
    expiresAt: timestamp,         // Apple's current period end
    inGracePeriod: bool,          // billing-retry window still counts as active
    originalTransactionId: string,// Apple's stable subscription id
    purchasedByUid: string,       // which parent bought it
    updatedAt: timestamp,
  }
```

Clients and Firestore rules **read** `premium.active` to gate features; they can
never write it. This is the same trust boundary as `balanceCents` — the one that
the security review confirmed is sound.

`premiumActive(fid)` helper (rules + client): `premium.active == true` (Apple's
grace period is folded into `active`, so no separate check needed client-side).

### Two ways the entitlement gets written

1. **Purchase / restore (callable):** `activatePremium(familyId, verificationData)`
   — the client hands over the StoreKit transaction; the function validates it
   with Apple and, on success, writes `families/{fid}.premium`.
2. **App Store Server Notifications v2 (HTTPS trigger):** `appStoreNotifications`
   — Apple POSTs lifecycle events (renewed, expired, refunded, grace-period,
   revoked) to a Cloud Function that updates `premium` without the app being
   open. This is what keeps `active` accurate over time and what makes the
   **wind-down clean**: stop selling, and expirations flip `active:false` on
   their own as terms lapse.

Both resolve the subscription to a family via `originalTransactionId` →
`premium.originalTransactionId` (stored at purchase), so renewals/expirations
map back to the right family even though Apple only knows the Apple ID.

## The purchase flow (iOS)

- **Package:** `in_app_purchase` (official Flutter plugin) + `in_app_purchase_storekit`.
- **Product:** one auto‑renewable subscription, ID `bomad_premium_yearly`,
  $9.99/yr, in an App Store Connect subscription group `Premium`.
- **Flow:**
  1. Parent taps **Upgrade** → paywall sheet → `buyNonConsumable`/`buy` for the
     subscription product.
  2. StoreKit returns a `PurchaseDetails` with `verificationData` (the signed
     transaction / JWS).
  3. Client calls `activatePremium(familyId, verificationData)`.
  4. Function verifies with Apple's **App Store Server API** (JWS signature +
     `originalTransactionId` + expiry), then writes `premium`.
  5. Client calls `completePurchase`. UI reacts to the Firestore `premium` change
     (real-time), so unlock is automatic across the parent's devices.
- **Restore:** a **Restore Purchases** button calls `restorePurchases()`; each
  restored transaction runs the same `activatePremium` path. (Required by Apple
  for subscriptions.)
- **Receipt validation is server-side only.** Never trust the client's word that
  it's premium — the function validates the signed transaction with Apple before
  writing `premium`. (Same principle as `decideRequest`.)

## Enforcement — client for UX, rules for security

Every gate is enforced **twice**: the client hides/blocks it for a clean
experience, and Firestore/Storage rules (or the callable) enforce it for real so
a modified client can't bypass it.

| Feature | Client gate | Server enforcement |
|---|---|---|
| **Unlimited kids** (free = 2) | "Upgrade to add more kids" when a 3rd kid is added | `createFamily`/`addMember` count existing kids; rules `create` on `members` requires `premiumActive(fid)` once kid count ≥ 2 |
| **Receipt photos** | Upload UI shown only when premium | Storage rules: write allowed only if `premiumActive(fid)` (+ image type + size < 2 MB + ≤ 2 files) |
| **Recurring templates** | Recurring screen shows upsell when free | Firestore rules: `create` on `recurring` requires `premiumActive(fid)` |
| **CSV export** | Export button premium-only | Not security-sensitive (read-only of own data); client gate is sufficient |

Rules read premium via `get(/databases/…/families/$(fid)).data.premium.active`.
This adds one document read per gated write — acceptable and cheap.

**Kid-count rule detail:** free families may hold at most 2 members with
`role == 'kid'` and `status in ['invited','active']`. The `addMember` callable
(preferred) does the count in a transaction; the rules provide the backstop.
Removing/disabling a kid frees a slot.

## Receipt photos (new feature, premium)

- **Storage:** `families/{familyId}/receipts/{txId}/{n}.jpg` (n ∈ {0,1}).
- **Client:** `image_picker` (camera or library) → compress to ≤ 1600 px, JPEG
  ~0.8 quality (target < 1 MB) → upload. Max **2 per transaction**.
- **Data:** transaction/request docs gain `receiptPaths: string[]` (≤ 2 Storage
  paths). Parents attach on a ledger transaction; kids attach on a request.
- **Storage rules:** read = active/disabled family member; write = (active
  parent for a tx, or the kid for their own request) **AND** `premiumActive(fid)`
  **AND** `request.resource.contentType.matches('image/.*')` **AND**
  `request.resource.size < 2 * 1024 * 1024`. Firestore rule caps
  `receiptPaths.size() <= 2`.
- **iOS:** add `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` to
  Info.plist (App Store requirement).
- **Viewing:** thumbnails in the transaction tile; tap → full-screen viewer.
- **Deletion:** deleting a transaction deletes its receipt objects (in the
  ledger trigger / a cleanup function), consistent with "history kept forever"
  only for the ledger, not for attached images.

## CSV export (premium)

- Parent-only. Client builds a CSV from the family's transactions (per kid or
  all), triggers a download on web / share sheet on iOS. Pure client feature; no
  backend.

## Cross-platform unlock (web)

- Web reads `families/{fid}.premium.active` and unlocks the same features.
- Web shows **no purchase UI**. Where a free web user hits a gate, show:
  *"Premium is managed in the Bank of Mom & Dad iOS app."* (Informational only —
  no external payment link, per Apple guideline 3.1.1.)

## Subscription lifecycle & edge cases

- **Renewal / expiry / refund / revoke / grace period:** handled by
  `appStoreNotifications`; `premium.active` and `expiresAt` always reflect
  Apple's truth. Grace period keeps `active:true` during billing retries.
- **Multi-family:** premium is per-family; a purchase unlocks the family the
  parent had active at purchase time (`activeFamilyId`). A parent who owns two
  families and wants premium in both buys twice. (Simple, explicit; revisit only
  if it becomes a real complaint.)
- **Co-parents:** any parent in the family can buy; all members benefit.
- **Owner's own family (grandfathering):** a one-off admin write (or a
  `grantPremium` callable restricted to a hard-coded owner uid) sets
  `premium.active:true` with a far-future `expiresAt` and `productId:'comp'` for
  the Ho family, so real usage isn't paywalled.
- **Downgrade behavior when premium lapses:** existing data is never deleted.
  Extra kids beyond 2, recurring templates, and receipts remain **visible and
  read-only**; the family just can't *add* new gated items until they re-subscribe.
  (No destructive downgrade — matches the app's "never delete" ethos.)

## Security review hooks (must hold before ship)

- `premium` is Functions-only-writable; client writes denied (add to
  firestore.rules; extend the existing family-doc update rule which currently
  allows only `name`).
- `activatePremium` validates the Apple transaction server-side; rejects unsigned
  / mismatched / expired transactions. Rate-limited per uid.
- `appStoreNotifications` verifies Apple's JWS signature before trusting a
  payload (never trust an unauthenticated POST).
- Kid-count / receipt / recurring gates enforced in rules, not just UI.
- App Check (currently monitor mode) should be **enforcing** before this ships,
  since money is now involved — the callables are a higher-value target.

## Testing

- **Unit:** kid-count gate logic; entitlement helper; CSV formatting; receipt
  compression bounds.
- **Rules tests:** free family blocked from 3rd kid / recurring / receipt write;
  premium family allowed; client cannot write `premium`.
- **IAP:** StoreKit **sandbox** testers for buy / renew (sandbox renews fast) /
  restore / expire; verify `premium` transitions via `appStoreNotifications`
  (sandbox notifications).
- **Manual:** buy on iOS → confirm web unlocks; let sandbox sub expire → confirm
  gates re-lock but data stays visible.

## Out of scope (v1)

Web/Stripe checkout, monthly plan, lifetime tier, family-plan multi-family
bundle, promo codes / free trials (can add a StoreKit intro offer later without
a code change).

## Rough build order (for the plan step)

1. Entitlement model + rules (`premium` field, gates) — testable with a manual/comp write.
2. StoreKit product in App Store Connect + `in_app_purchase` buy/restore + `activatePremium` with Apple validation.
3. `appStoreNotifications` webhook + lifecycle.
4. Paywall UI + per-feature upsells + web "manage on iOS" messaging.
5. Receipt photos (Storage + rules + UI + Info.plist).
6. CSV export.
7. App Check enforcement + full security-rules test pass.
