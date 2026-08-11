import { signUp, callable, adminDb } from './emu.mjs';

const db = adminDb();
const parent = await signUp('test-parent@bomad.test', 'testtest1');
const { familyId } = await callable('createFamily', parent.idToken, {
  name: 'Test Family',
  kids: [{ name: 'Testy', email: 'test-kid@bomad.test' }],
  coParents: ['test-parent2@bomad.test'],
});
const parent2 = await signUp('test-parent2@bomad.test', 'testtest1');
await callable('joinFamily', parent2.idToken, {});
const kid = await signUp('test-kid@bomad.test', 'testtest1');
await callable('joinFamily', kid.idToken, {});

const members = await db.collection(`families/${familyId}/members`).get();
const kidId = members.docs.find((d) => d.get('role') === 'kid').id;
const tx = (amountCents, reason, daysAgo, note = null) => ({
  kidMemberId: kidId, amountCents, reason, note,
  date: new Date(Date.now() - daysAgo * 86400000),
  source: 'parent', requestId: null, createdByUid: parent.uid, createdAt: new Date(),
});
await db.collection(`families/${familyId}/transactions`).add(tx(2500, 'Allowance', 7));
await db.collection(`families/${familyId}/transactions`).add(tx(-800, 'Candy run', 3));
await db.collection(`families/${familyId}/transactions`).add(
    tx(1000, 'Chores', 1, 'This is a very long note that should absolutely get clamped at two lines in the kid view because it just keeps going and going and going.'));
await db.collection(`families/${familyId}/requests`).add({
  kidMemberId: kidId, amountCents: 3000, reason: 'Lego set', note: null,
  date: new Date(), status: 'pending', decidedByUid: null, hiddenByKid: false,
  createdAt: new Date(),
});
console.log(`Test family ${familyId} ready. parent/parent2/kid = test-parent@bomad.test, test-parent2@bomad.test, test-kid@bomad.test (password testtest1)`);
