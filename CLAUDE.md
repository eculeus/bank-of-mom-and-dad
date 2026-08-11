# Bank of Mom and Dad

Family allowance ledger. Parents track virtual money they hold for their kids; kids see balances and request transactions. Flutter web PWA now, same codebase to the App Store later.

## Tech stack (locked)

- **Flutter** (single codebase: web PWA today, native iOS/Android later for App Store)
- **Firebase**: Auth (Google sign-in), Firestore, Cloud Functions (Blaze plan — approved), FCM push, Hosting
- Target devices: iPhone/iPad first (install via Safari → Add to Home Screen; push needs iOS 16.4+ and Home Screen install). Android/Chrome must also work. Desktop Chrome used for testing.

## Product decisions (ground truth — confirmed with the owner)

- **Roles**: parent and kid. Family creator is the **primary owner**. Parents can invite co-parents. Any parent can add/subtract money and approve/deny requests.
- **Multiple families**: a parent can create/belong to multiple families and switch between them. Kids auto-join the family (or families) that invited their email.
- **Onboarding**: new sign-in → asked "parent or kid?" Parent → create-family wizard + add kids/co-parents by email. Kid → auto-join family matching their email; if no family has invited that email, show "ask your parent to add you" screen with sign-out.
- **Transactions**: parent's big red button → pick kid, amount (+/−), reason, date, optional note. Parents can **edit/delete their own** ledger entries (typo fixes). USD only. Negative balances allowed.
- **Kid requests**: date + amount (+/− allowed) + reason (+ optional note). Immutable once submitted — no edits, resubmit anew. Parent approves (creates ledger transaction) or denies. Kid has a Requests tab showing all requests; kid can hide processed (approved/denied) requests from view (never deleted from DB).
- **Kid home screen**: big balance number with slight font-size bounce animation when opening after a while away; new-since-last-visit transactions briefly highlighted; history below, sorted descending by transaction date; long notes truncated with an expand affordance.
- **Parent home screen**: all kids' balances at a glance, nice and large. Plus transaction entry, per-kid history, pending requests.
- **Account lifecycle**: deletion NEVER deletes transaction data — history kept forever; data belongs to the family (parent side). Parent removes a kid → kid account disabled (kid sees history + "account inactive, talk to your parents or delete your account"). Primary parent deletes account → all kids in that family disabled. Kid deletes account → parents notified.
- **Notifications** (via Cloud Functions + FCM):
  - Parents: new transaction request → push, throttled to max 1 per 10 minutes per parent (batched: "new request(s)" even if several arrived).
  - Parents: when another parent records a transaction → push (not throttled).
  - Kids: new transaction ("You received a new deposit of $30.00!"), request approved ("Your request for $30.00 was approved and added to your account!"), request denied ("Your request for $30.00 was denied — please talk to <parent name>").
- **Recurring**: parents set weekly/monthly recurring payment/debit templates per kid (multiple allowed, hard-deletable, no edits). Daily 09:00 America/New_York sweep turns due templates into pending approval requests in the parent inbox (origin 'recurring'); approve → ledger tx; either way advances next due date.
- **Style**: bright, festive, kid-attractive, animations wherever they add delight.

## Real family seed data

Real family data lives in gitignored scripts/seed/family.config.json + export.csv (see the example config).

- Sheet data is messy: some dates lack years (infer from neighboring rows), some amounts lack $ formatting, occasional typo years get corrected (exact dates matter less than totals). Seed script parses best-effort, then adds a final "Balance adjustment" transaction per kid if needed so totals match the sheet's stated totals exactly.

## Testing

- Test in Chrome with dedicated **email/password test accounts** (both parent and kid side), NOT tied to real Gmail accounts. Email/password sign-in UI is only exposed in test mode (`--dart-define=TEST_MODE=true`).
- Use Firebase Emulator Suite (auth, firestore, functions) for local dev/E2E; seed a separate test family so real family data is never touched by tests.

## Firebase

- Project ID: **bank-of-mom-and-dad-ho** (`bank-of-mom-and-dad` was taken). Blaze plan ACTIVE (linked to "My Billing Account"). Firestore `(default)` in nam5, production mode. Auth providers enabled: Google, Email/Password.
