# Premium / Freemium Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a $9.99/yr annual Premium tier (Apple IAP on iOS, unlocks on iOS + web) that gates unlimited kids, receipt photos, recurring templates, and CSV export behind a server-authoritative per-family entitlement.

**Architecture:** Premium is a Functions-only `premium` map on `families/{fid}` (same trust model as `balanceCents`). Purchases validated server-side against Apple's App Store Server API; lifecycle kept current by an App Store Server Notifications v2 webhook. Every gate enforced in Firestore/Storage rules **and** client. Web reads the flag, has no checkout.

**Tech Stack:** Flutter (Riverpod), `in_app_purchase` + `in_app_purchase_storekit`, Firebase (Firestore, Cloud Functions v2 nodejs22 ESM, Storage), `app-store-server-library` (npm) for Apple JWS verification, `image_picker` + `flutter_image_compress`.

Design spec: `docs/superpowers/specs/2026-09-01-premium-freemium-design.md`.

## Global Constraints

- **Entitlement is server-authoritative.** `families/{fid}.premium` is written ONLY by Cloud Functions (Admin SDK). Client writes to it are denied by rules. Never trust a client claim of premium.
- **All Apple receipts/transactions validated server-side** before writing `premium` — verify the JWS signature and `originalTransactionId` with `app-store-server-library`. Reject unsigned/expired/mismatched.
- **Every gate enforced twice:** client (UX) + Firestore/Storage rules (security). Free = max 2 kids; receipts/recurring writes require `premium.active`.
- **Non-destructive downgrade:** lapsed premium never deletes data; extra kids, recurring, receipts stay visible/read-only; only *adding* new gated items is blocked.
- **Product ID:** `bomad_premium_yearly`. Entitlement fields: `active, productId, expiresAt, inGracePeriod, originalTransactionId, purchasedByUid, updatedAt`.
- **`premiumActive(fid)`** everywhere means `premium.active == true` (grace period folded into `active`).
- Money is involved → **App Check must be enforcing before launch** (Task 9).
- Keep existing conventions: integer cents, ESM functions, emulator-guarded test paths, `--dart-define` flags. Follow existing file/style patterns.

---

### Task 1: Entitlement model + `premiumActive` + read plumbing

**Files:**
- Modify: `lib/models/models.dart` (Family/FamilyEntry — add `premium`)
- Create: `lib/state/premium.dart` (entitlement provider + `PremiumStatus`)
- Test: `test/premium_test.dart`

**Interfaces:**
- Produces: `class PremiumStatus { final bool active; final DateTime? expiresAt; }`, `PremiumStatus premiumFromMap(Map?)`, and a Riverpod `premiumProvider(familyId)` reading `families/{fid}.premium`.

- [ ] **Step 1: Write the failing test**
```dart
// test/premium_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bank_of_mom_and_dad/state/premium.dart';
void main() {
  test('premiumFromMap parses active + expiry, defaults inactive', () {
    expect(premiumFromMap(null).active, false);
    expect(premiumFromMap({'active': false}).active, false);
    final p = premiumFromMap({'active': true, 'expiresAt': null});
    expect(p.active, true);
  });
}
```
- [ ] **Step 2: Run it, verify it fails** — `flutter test test/premium_test.dart` → FAIL (no `premium.dart`).
- [ ] **Step 3: Implement** `PremiumStatus` + `premiumFromMap` in `lib/state/premium.dart`; add a `StreamProvider.family` `premiumProvider(String familyId)` that watches the family doc and maps `.premium`.
- [ ] **Step 4: Run tests** → PASS.
- [ ] **Step 5: Commit** — `feat(premium): entitlement model + provider`.

### Task 2: Firestore rules — protect `premium`, gate kids & recurring

**Files:**
- Modify: `firestore.rules`
- Test: `functions/test/rules.premium.test.mjs` (extend the existing rules test harness)

**Interfaces:**
- Consumes: existing `isActiveParent(fid)`, family-doc update rule (currently `hasOnly(['name'])`).
- Produces: rule helper `premiumActive(fid)` = `get(family).data.premium.active == true`; kid-count and recurring gates.

- [ ] **Step 1: Write failing rules tests** — using `@firebase/rules-unit-testing`: (a) client update to `families/{fid}.premium` is DENIED; (b) creating a 3rd `members` doc with `role=='kid'` is DENIED when `premium.active!=true`, ALLOWED when true; (c) creating a `recurring` doc DENIED without premium, ALLOWED with premium. (Seed premium via the admin context.)
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement rules:**
  - `function premiumActive(fid) { return get(/databases/$(database)/documents/families/$(fid)).data.premium.active == true; }`
  - Family update rule: keep `hasOnly(['name'])` for parents; `premium` remains unwritable by clients (not in the allowed key set).
  - `members` create: add `&& (premiumActive(fid) || existingKidCount < 2)` — since rules can't count a collection, enforce the count in the `addMember` callable (Task 3) and keep the rule as `premiumActive(fid) || request.resource.data.role != 'kid' || <grandfathered>`; document that the authoritative kid-count check lives in the callable. Rule provides the premium backstop for direct writes.
  - `recurring` create/update: prepend `premiumActive(fid) &&` to the existing condition.
- [ ] **Step 4: Run rules tests → PASS.**
- [ ] **Step 5: Commit** — `feat(premium): rules protect entitlement + gate kids/recurring`.

### Task 3: `addMember` callable with server-side kid-count gate + `grantPremium` comp

**Files:**
- Modify: `functions/families.js` (add `addMember`, move client member-create here)
- Create: `functions/premium.js` (`grantPremium` owner-comp callable)
- Modify: `functions/index.js` (exports)
- Modify: `lib/features/parent/manage_family_screen.dart` (call `addMember` instead of direct Firestore write)
- Test: `functions/test/premium.test.mjs`

**Interfaces:**
- Produces: `addMember({familyId, name, email, role})` — active-parent only; if `role=='kid'` and family not premium, counts existing non-deleted kids and throws `failed-precondition('premium-required')` at ≥2. `grantPremium({familyId})` — owner-uid-only, sets `premium.active:true, productId:'comp', expiresAt:2099`.

- [ ] **Step 1: Write failing test** — `addMember` adds a 2nd kid on a free family (ok), rejects the 3rd with `premium-required`, and allows the 3rd after `premium.active` is set. (Firestore emulator.)
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** `addMember` (transactional count of `role=='kid' && status in [invited,active]`), `grantPremium` (hard-coded owner uid check). Repoint `manage_family_screen` at the callable.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `feat(premium): addMember kid-count gate + owner comp`.

### Task 4: `activatePremium` callable — validate an Apple transaction, write entitlement

**Files:**
- Modify: `functions/package.json` (add `app-store-server-library`)
- Create: `functions/appstore.js` (Apple client + JWS verify helpers)
- Modify: `functions/premium.js` (`activatePremium`)
- Modify: `functions/index.js`
- Test: `functions/test/activatePremium.test.mjs`
- Secret: App Store Connect **in-app-purchase key** (.p8) → `secrets/` (gitignored), loaded via Functions secret.

**Interfaces:**
- Produces: `activatePremium({familyId, transactionJws})` — verifies signature + product + not-expired via App Store Server API, resolves `originalTransactionId`, writes `families/{fid}.premium{active,expiresAt,inGracePeriod,originalTransactionId,productId,purchasedByUid,updatedAt}`. Rejects on invalid signature / wrong product / expired.

- [ ] **Step 1: Write failing test** — with a mocked verifier: a valid signed transaction for `bomad_premium_yearly` writes `premium.active:true`; a wrong product or a verifier-throws case leaves `premium` unset and throws. (Mock `app-store-server-library` verification.)
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** the Apple `SignedDataVerifier` wiring in `appstore.js` (bundle `com.eculeus.bomad`, environment from payload), and `activatePremium` calling it, guarding active-parent, writing `premium`. Store the in-app-purchase key as a Functions secret.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `feat(premium): activatePremium with Apple server-side validation`.

### Task 5: Client purchase + restore (`in_app_purchase`)

**Files:**
- Modify: `pubspec.yaml` (`in_app_purchase`, `in_app_purchase_storekit`)
- Create: `lib/services/purchase_service.dart`
- Modify: `lib/services/functions_service.dart` (`activatePremium` call)
- Test: `test/purchase_service_test.dart` (pure logic: map `PurchaseDetails` → activate args; ignore already-processed)

**Interfaces:**
- Consumes: `activatePremium` (Task 4).
- Produces: `PurchaseService` with `buyPremium()`, `restore()`, and a purchase-stream listener that, on `purchased`/`restored`, calls `activatePremium(familyId, jws)` then `completePurchase`. Idempotent on transaction id.

- [ ] **Step 1: Write failing test** — a fake `PurchaseDetails` (status purchased, product `bomad_premium_yearly`) yields exactly one `activatePremium` call with its verification data; a duplicate id is skipped.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** `PurchaseService` (query product, buy, listen, restore). App-Store-only (`if (!Platform.isIOS) return`); web never instantiates it.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `feat(premium): StoreKit buy + restore wiring`.

### Task 6: App Store Server Notifications v2 webhook

**Files:**
- Modify: `functions/premium.js` (`appStoreNotifications` onRequest)
- Modify: `functions/index.js`
- Test: `functions/test/appStoreNotifications.test.mjs`

**Interfaces:**
- Produces: HTTPS `appStoreNotifications` — verifies the signed payload, maps `DID_RENEW/EXPIRED/DID_FAIL_TO_RENEW(grace)/REFUND/REVOKE` → updates the family found by `originalTransactionId` (`premium.active`, `expiresAt`, `inGracePeriod`). Rejects unsigned payloads with 400.

- [ ] **Step 1: Write failing test** — a signed `DID_RENEW` extends `expiresAt` + keeps `active:true`; `EXPIRED` sets `active:false`; unverifiable payload → 400, no write. (Mock verifier; seed a family with a known `originalTransactionId`.)
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** the handler (reuse `appstore.js` verifier), look up family by `originalTransactionId` (collection-group query on `families` where `premium.originalTransactionId ==`), update. Register the URL in App Store Connect (manual, noted in report).
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `feat(premium): App Store server notifications lifecycle`.

### Task 7: Paywall UI + per-feature upsells + web "manage on iOS"

**Files:**
- Create: `lib/features/premium/paywall_sheet.dart`, `lib/features/premium/upgrade_gate.dart` (reusable "locked" affordance)
- Modify: parent screens that expose gated actions (`manage_family_screen`, `recurring_screen`, `kid_detail_screen`, an export entry, receipts entry)
- Test: `test/paywall_test.dart` (paywall renders price/benefits, buy button disabled until product loaded; upgrade_gate shows iOS-vs-web message by platform)

**Interfaces:**
- Consumes: `premiumProvider` (Task 1), `PurchaseService` (Task 5).
- Produces: `PaywallSheet` (benefits list, "$9.99/year", Subscribe, Restore) shown on iOS; `UpgradeGate` widget that on web shows *"Premium is managed in the Bank of Mom & Dad iOS app."*

- [ ] **Step 1: Write failing widget test** — paywall shows "$9.99/year" and the four benefits; on a non-iOS platform the gate shows the "manage in the iOS app" copy and no buy button.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** the sheet + gate; wire upsell entry points (adding 3rd kid, recurring screen, receipts button, export button) to open the paywall (iOS) or the info gate (web).
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `feat(premium): paywall + upsells + web messaging`.

### Task 8: Receipt photos (premium)

**Files:**
- Create: `storage.rules`; Modify: `firebase.json` (add storage rules), `lib/models/models.dart` (`receiptPaths` on transaction/request), `lib/features/parent/transaction_sheet.dart` + `lib/features/kid/new_request_sheet.dart` (attach UI), tile widgets (thumbnails/viewer), `ios/Runner/Info.plist` (camera/photo usage strings)
- Modify: `functions/ledger.js` or a cleanup trigger (delete receipt objects when a tx is deleted)
- Create: `lib/services/receipt_service.dart` (pick → compress → upload, max 2)
- Add deps: `image_picker`, `flutter_image_compress`
- Test: `test/receipt_service_test.dart` (compression target + max-2 guard, pure logic)

**Interfaces:**
- Consumes: `premiumProvider`.
- Produces: `ReceiptService.attach(familyId, docPath)` returning ≤2 Storage paths; Firestore `receiptPaths: string[]` (≤2).

- [ ] **Step 1: Write failing tests** — service rejects a 3rd image; a `storage.rules` test (emulator) denies upload when family not premium / wrong content-type / >2 MB, allows a ≤2 MB image when premium.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** storage rules (`premiumActive` + image type + size + read for members), `ReceiptService`, attach UI + thumbnail/full-screen viewer, `receiptPaths` on docs (rule caps `size()<=2`), Info.plist strings, delete-cleanup.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `feat(premium): receipt photo attachments`.

### Task 9: CSV export (premium)

**Files:**
- Create: `lib/features/parent/export.dart`
- Test: `test/export_test.dart` (CSV rows/escaping for a fixed transaction list)

**Interfaces:**
- Produces: `buildCsv(List<BankTransaction>)` → String; a parent-only button that shares (iOS) / downloads (web).

- [ ] **Step 1: Write failing test** — `buildCsv` produces a header + one row per tx with amounts as dollars and reasons quoted/escaped.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** `buildCsv` + the export action (premium-gated).
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `feat(premium): CSV export`.

### Task 10: App Check enforcement + full security pass

**Files:**
- Modify: (console) enforce App Check on Firestore + callables; `firestore.rules`/`storage.rules` final review.
- Test: run the full rules suite + `flutter test` + `functions` tests.

- [ ] **Step 1:** Confirm App Check monitor metrics show ~all real traffic sending valid tokens and all testers on ≥0.1.0+3.
- [ ] **Step 2:** Enable enforcement (Firestore, callable functions, Storage) — with owner sign-off.
- [ ] **Step 3:** Full test pass: rules tests (premium protected, gates hold), `flutter test`, functions tests. Manual sandbox: buy → web unlocks → expire → re-locks, data intact.
- [ ] **Step 4: Commit** — `chore(premium): enforce App Check + final security pass`.

## Manual / out-of-band steps (owner)

1. App Store Connect → create auto-renewable subscription `bomad_premium_yearly` ($9.99/yr) in group `Premium`, with localized display name/description + review screenshot.
2. App Store Connect → generate an **in-app-purchase key** (.p8) → hand off for `secrets/` (gitignored), stored as a Functions secret.
3. App Store Connect → set the **App Store Server Notifications v2** URL to the deployed `appStoreNotifications` function.
4. Add sandbox testers for IAP testing.
5. Sign off on flipping App Check enforcement (Task 10).

## Self-review notes

- Spec coverage: entitlement, purchase, restore, lifecycle webhook, all four gates (kids/receipts/recurring/export), web unlock, grandfathering, downgrade — each maps to a task above. ✓
- Type consistency: `premiumActive`, `premium` field shape, product ID `bomad_premium_yearly`, `receiptPaths` used consistently across tasks. ✓
- Ordering: entitlement + rules first (testable via comp write) before purchase wiring; App Check enforcement last, after monitor confirms. ✓
