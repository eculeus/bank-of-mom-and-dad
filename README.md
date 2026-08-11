# Bank of Mom & Dad

A family allowance PWA built on Flutter and Firebase. Parents track the virtual money they hold for their kids; kids see their balance, browse history, and request transactions — all from an installable web app that syncs in real time.

## Features

- Parent dashboard with every kid's balance at a glance
- Kid balances with celebratory animations on new deposits
- Transaction requests with parent approvals/denials
- Recurring allowances on a weekly or monthly schedule
- Push notifications (FCM) for new requests, deposits, and decisions

## Quickstart

```bash
flutter pub get

# In one terminal: start the Firebase emulator suite (auth, firestore, functions)
firebase emulators:start

# In another: run the app against the emulators, with test accounts enabled
flutter run -d chrome --dart-define=USE_EMULATORS=true --dart-define=TEST_MODE=true
```

To seed some sample data for local testing, run `node scripts/test/seedTestData.mjs` against the running emulators — it creates a synthetic test family so real data is never touched by tests.

Seeding real family data (`scripts/seed/seed.mjs`) needs a local, gitignored `scripts/seed/family.config.json` — copy `scripts/seed/family.config.example.json` and fill in your own family's details before running it.
