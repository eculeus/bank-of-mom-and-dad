import { existsSync, readFileSync } from 'node:fs';
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { parseKidBlocks } from './parse.mjs';

const CSV_PATH = process.argv.includes('--csv')
  ? process.argv[process.argv.indexOf('--csv') + 1]
  : 'scripts/seed/export.csv';

const CONFIG_PATH = process.argv.includes('--config')
  ? process.argv[process.argv.indexOf('--config') + 1]
  : 'scripts/seed/family.config.json';

if (!existsSync(CONFIG_PATH)) {
  console.error(
    `Missing seed config at "${CONFIG_PATH}". Copy scripts/seed/family.config.example.json ` +
    `to ${CONFIG_PATH} and fill in your real family details (this file is gitignored).`);
  process.exit(1);
}
const config = JSON.parse(readFileSync(CONFIG_PATH, 'utf8'));

const FAMILY_NAME = config.familyName;
const OWNER = config.owner;
const CO_PARENTS = config.coParents;
const KIDS = config.kids;
// Stated totals from the sheet — MUST match exactly after seeding.
const EXPECTED_TOTALS_CENTS = config.expectedTotalsCents;

const emulated = !!process.env.FIRESTORE_EMULATOR_HOST;
if (emulated) {
  initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? 'bank-of-mom-and-dad' });
} else {
  const keyPath = process.env.SEED_SA_KEY;
  if (!keyPath) {
    console.error('Refusing to touch production without SEED_SA_KEY (service-account JSON path).');
    process.exit(1);
  }
  initializeApp({ credential: cert(JSON.parse(readFileSync(keyPath, 'utf8'))) });
}
const db = getFirestore();

const existing = await db.collection('families').where('name', '==', FAMILY_NAME).get();
if (!existing.empty) {
  console.error(`A family named "${FAMILY_NAME}" already exists (${existing.docs[0].id}). Aborting.`);
  process.exit(1);
}

const blocks = parseKidBlocks(readFileSync(CSV_PATH, 'utf8'));
console.log(`Parsed ${blocks.length} kid blocks: ${blocks.map((b) => b.name).join(', ')}`);
for (const block of blocks) {
  if (!(block.name in EXPECTED_TOTALS_CENTS)) {
    console.error(`Unexpected kid block "${block.name}" — aborting.`);
    process.exit(1);
  }
}

const famRef = db.collection('families').doc();
await famRef.set({ name: FAMILY_NAME, ownerUid: null, createdAt: Timestamp.now() });

const memberIds = {};
async function addMember({ name, email }, role, { isOwner = false, colorIndex = 0 } = {}) {
  const ref = famRef.collection('members').doc();
  await ref.set({
    email: email.toLowerCase(), uid: null, role, displayName: name,
    status: 'invited', isOwner, balanceCents: 0, colorIndex,
    lastSeenAt: null, createdAt: Timestamp.now(), joinedAt: null,
  });
  memberIds[name] = ref.id;
}
await addMember(OWNER, 'parent', { isOwner: true });
for (const p of CO_PARENTS) await addMember(p, 'parent');
for (const [i, kid] of KIDS.entries()) await addMember(kid, 'kid', { colorIndex: i });

let corrections = 0;
for (const block of blocks) {
  const kidMemberId = memberIds[block.name];
  let batch = db.batch();
  let inBatch = 0;
  let sum = 0;
  for (const row of block.rows) {
    sum += row.amountCents;
    if (row.corrected) { corrections++; console.log(`  [corrected year] ${block.name}: ${row.dateIso} ${row.reason}`); }
    batch.set(famRef.collection('transactions').doc(), {
      kidMemberId, amountCents: row.amountCents, reason: row.reason,
      date: Timestamp.fromDate(new Date(`${row.dateIso}T12:00:00`)),
      note: null, source: 'seed', requestId: null,
      createdByUid: 'seed-script', createdAt: Timestamp.now(),
    });
    if (++inBatch === 450) { await batch.commit(); batch = db.batch(); inBatch = 0; }
  }
  if (inBatch) await batch.commit();

  const expected = EXPECTED_TOTALS_CENTS[block.name];
  const diff = expected - sum;
  console.log(`${block.name}: ${block.rows.length} rows, parsed sum ${(sum / 100).toFixed(2)}, `
      + `stated ${(expected / 100).toFixed(2)}, diff ${(diff / 100).toFixed(2)}, `
      + `skipped ${block.skipped.length}`);
  for (const s of block.skipped) console.log(`  [skipped] ${s}`);
  if (diff !== 0) {
    await famRef.collection('transactions').add({
      kidMemberId, amountCents: diff, reason: 'Balance adjustment — spreadsheet import',
      date: Timestamp.now(), note: null, source: 'adjustment', requestId: null,
      createdByUid: 'seed-script', createdAt: Timestamp.now(),
    });
  }
  await famRef.collection('members').doc(kidMemberId).update({ balanceCents: expected });
}

// Final verification: re-sum straight from Firestore.
let allGood = true;
for (const kid of KIDS) {
  const txs = await famRef.collection('transactions')
      .where('kidMemberId', '==', memberIds[kid.name]).get();
  const total = txs.docs.reduce((acc, d) => acc + d.get('amountCents'), 0);
  const ok = total === EXPECTED_TOTALS_CENTS[kid.name];
  if (!ok) allGood = false;
  console.log(`VERIFY ${kid.name}: ${(total / 100).toFixed(2)} — ${ok ? 'OK' : 'MISMATCH'}`);
}
console.log(`Corrections: ${corrections}. Family: ${famRef.id}. ${allGood ? 'SEED OK ✅' : 'SEED FAILED ❌'}`);
process.exit(allGood ? 0 : 1);
