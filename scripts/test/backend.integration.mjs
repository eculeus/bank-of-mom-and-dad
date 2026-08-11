import test from 'node:test';
import assert from 'node:assert/strict';
import { signUp, callable, adminDb, waitFor, PROJECT_ID } from './emu.mjs';

const db = adminDb();

test('createFamily + joinFamily + mirror sync', async () => {
  const parent = await signUp('greg@test.com', 'testtest1');
  const { familyId } = await callable('createFamily', parent.idToken, {
    name: 'Test Family',
    kids: [{ name: 'Alex', email: 'AlexKid@Test.com' }],
    coParents: ['co@test.com'],
  });
  assert.ok(familyId);

  const members = await db.collection(`families/${familyId}/members`).get();
  assert.equal(members.size, 3);
  const kidMember = members.docs.find((d) => d.get('role') === 'kid');
  assert.equal(kidMember.get('email'), 'alexkid@test.com'); // lowercased
  assert.equal(kidMember.get('status'), 'invited');

  const parentUser = await db.doc(`users/${parent.uid}`).get();
  assert.equal(parentUser.get(`families.${familyId}.role`), 'parent');
  assert.equal(parentUser.get('activeFamilyId'), familyId);

  // Kid joins by signing in with the invited email
  const kid = await signUp('alexkid@test.com', 'testtest1');
  const joinResult = await callable('joinFamily', kid.idToken, {});
  assert.equal(joinResult.families.length, 1);
  assert.equal(joinResult.families[0].familyId, familyId);
  assert.equal(joinResult.families[0].role, 'kid');

  const kidUser = await waitFor(async () => {
    const snap = await db.doc(`users/${kid.uid}`).get();
    return snap.get(`families.${familyId}.status`) === 'active' ? snap : null;
  });
  assert.equal(kidUser.get(`families.${familyId}.memberId`), kidMember.id);

  // Parent disables the kid client-side; onMemberWritten syncs the mirror
  await db.doc(`families/${familyId}/members/${kidMember.id}`).update({ status: 'disabled' });
  await waitFor(async () => {
    const snap = await db.doc(`users/${kid.uid}`).get();
    return snap.get(`families.${familyId}.status`) === 'disabled' ? snap : null;
  });
});

test('unauthenticated createFamily rejects', async () => {
  const res = await fetch(`http://127.0.0.1:5001/${PROJECT_ID}/us-central1/createFamily`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ data: { name: 'Nope' } }),
  });
  const body = await res.json();
  assert.ok(body.error, 'expected an error for an unauthenticated call');
  assert.notEqual(res.status, 200);
});

test('joinFamily never steals an already-claimed member doc', async () => {
  const parent = await signUp('steal-parent@test.com', 'testtest1');
  const { familyId } = await callable('createFamily', parent.idToken, {
    name: 'Steal Family', kids: [{ name: 'Kid', email: 'steal-kid@test.com' }], coParents: [],
  });
  const kid = await signUp('steal-kid@test.com', 'testtest1');
  await callable('joinFamily', kid.idToken, {});
  const members = await db.collection(`families/${familyId}/members`).get();
  const kidMember = members.docs.find((d) => d.get('role') === 'kid');

  // Simulate the doc having since been claimed by a different account (admin write bypasses rules).
  await db.doc(`families/${familyId}/members/${kidMember.id}`).update({ uid: 'someone-else' });

  const joinResult = await callable('joinFamily', kid.idToken, {});
  assert.equal(joinResult.families.length, 0);
  const after = await db.doc(`families/${familyId}/members/${kidMember.id}`).get();
  assert.equal(after.get('uid'), 'someone-else');
});

test('user with two families keeps both mirror entries', async () => {
  const parent = await signUp('two-fam-parent@test.com', 'testtest1');
  const fam1 = await callable('createFamily', parent.idToken, { name: 'Fam One', kids: [], coParents: [] });
  const fam2 = await callable('createFamily', parent.idToken, { name: 'Fam Two', kids: [], coParents: [] });
  const userDoc = await db.doc(`users/${parent.uid}`).get();
  const families = userDoc.get('families');
  assert.ok(families[fam1.familyId]);
  assert.ok(families[fam2.familyId]);
});

test('balances recompute on tx create/edit/delete', async () => {
  const parent = await signUp('bal-parent@test.com', 'testtest1');
  const { familyId } = await callable('createFamily', parent.idToken, {
    name: 'Bal Family', kids: [{ name: 'Kid', email: 'bal-kid@test.com' }], coParents: [],
  });
  const members = await db.collection(`families/${familyId}/members`).get();
  const kidId = members.docs.find((d) => d.get('role') === 'kid').id;
  const txCol = db.collection(`families/${familyId}/transactions`);

  const t1 = await txCol.add({ kidMemberId: kidId, amountCents: 3000, reason: 'a', date: new Date(), source: 'parent', createdByUid: parent.uid, createdAt: new Date() });
  await txCol.add({ kidMemberId: kidId, amountCents: -500, reason: 'b', date: new Date(), source: 'parent', createdByUid: parent.uid, createdAt: new Date() });
  await waitFor(async () =>
    (await db.doc(`families/${familyId}/members/${kidId}`).get()).get('balanceCents') === 2500);

  await t1.update({ amountCents: 1000 });
  await waitFor(async () =>
    (await db.doc(`families/${familyId}/members/${kidId}`).get()).get('balanceCents') === 500);

  await t1.delete();
  await waitFor(async () =>
    (await db.doc(`families/${familyId}/members/${kidId}`).get()).get('balanceCents') === -500);
});

async function pushLogWhere(pred) {
  const snap = await db.collection('_pushLog').get();
  return snap.docs.map((d) => d.data()).filter(pred);
}

test('request notifications throttle per parent', async () => {
  const parent = await signUp('thr-parent@test.com', 'testtest1');
  const { familyId } = await callable('createFamily', parent.idToken, {
    name: 'Thr Family', kids: [{ name: 'Kid', email: 'thr-kid@test.com' }], coParents: [],
  });
  const members = await db.collection(`families/${familyId}/members`).get();
  const kidId = members.docs.find((d) => d.get('role') === 'kid').id;
  const reqCol = db.collection(`families/${familyId}/requests`);
  const mk = (r) => ({ kidMemberId: kidId, amountCents: 2000, reason: r, date: new Date(), note: null, status: 'pending', decidedByUid: null, hiddenByKid: false, createdAt: new Date() });

  await reqCol.add(mk('one'));
  await waitFor(async () =>
    (await pushLogWhere((p) => p.uid === parent.uid && p.body.startsWith('New transaction request'))).length === 1);
  await reqCol.add(mk('two')); // inside 10-min window → absorbed
  await new Promise((r) => setTimeout(r, 3000));
  const after = await pushLogWhere((p) => p.uid === parent.uid && p.body.startsWith('New transaction request'));
  assert.equal(after.length, 1);

  // Age the throttle state 11 minutes → next request pushes again
  await db.doc(`families/${familyId}/notificationState/${parent.uid}`)
    .set({ lastRequestPushAt: new Date(Date.now() - 11 * 60 * 1000) });
  await reqCol.add(mk('three'));
  await waitFor(async () =>
    (await pushLogWhere((p) => p.uid === parent.uid && p.body.startsWith('New transaction request'))).length === 2);
});

test('decideRequest approve creates ledger tx and notifies kid; deny notifies kid', async () => {
  const parent = await signUp('dec-parent@test.com', 'testtest1');
  const { familyId } = await callable('createFamily', parent.idToken, {
    name: 'Dec Family', kids: [{ name: 'Kid', email: 'dec-kid@test.com' }], coParents: [],
  });
  const kid = await signUp('dec-kid@test.com', 'testtest1');
  await callable('joinFamily', kid.idToken, {});
  const members = await db.collection(`families/${familyId}/members`).get();
  const kidId = members.docs.find((d) => d.get('role') === 'kid').id;
  const reqCol = db.collection(`families/${familyId}/requests`);

  const r1 = await reqCol.add({ kidMemberId: kidId, amountCents: 3000, reason: 'lego', date: new Date(), note: null, status: 'pending', decidedByUid: null, hiddenByKid: false, createdAt: new Date() });
  await callable('decideRequest', parent.idToken, { familyId, requestId: r1.id, decision: 'approve' });
  assert.equal((await r1.get()).get('status'), 'approved');
  const txs = await db.collection(`families/${familyId}/transactions`).where('requestId', '==', r1.id).get();
  assert.equal(txs.size, 1);
  assert.equal(txs.docs[0].get('source'), 'request');
  await waitFor(async () =>
    (await db.doc(`families/${familyId}/members/${kidId}`).get()).get('balanceCents') === 3000);
  await waitFor(async () =>
    (await pushLogWhere((p) => p.uid === kid.uid && p.body === 'Your request for $30.00 was approved and added to your account!')).length === 1);

  const r2 = await reqCol.add({ kidMemberId: kidId, amountCents: 500, reason: 'candy', date: new Date(), note: null, status: 'pending', decidedByUid: null, hiddenByKid: false, createdAt: new Date() });
  await callable('decideRequest', parent.idToken, { familyId, requestId: r2.id, decision: 'deny' });
  await waitFor(async () =>
    (await pushLogWhere((p) => p.uid === kid.uid && p.body.startsWith('Your request for $5.00 was denied'))).length === 1);
  // double-decide rejected
  await assert.rejects(
    () => callable('decideRequest', parent.idToken, { familyId, requestId: r2.id, decision: 'approve' }),
    (err) => err.message.includes('failed-precondition') || err.message.includes('Already decided'),
  );
  const r2Txs = await db.collection(`families/${familyId}/transactions`).where('requestId', '==', r2.id).get();
  assert.equal(r2Txs.size, 0);
});

test('deleteAccount: kid soft-deletes and parents notified; owner disables kids', async () => {
  const owner = await signUp('own-parent@test.com', 'testtest1');
  const { familyId } = await callable('createFamily', owner.idToken, {
    name: 'Del Family', kids: [{ name: 'Kid', email: 'del-kid@test.com' }], coParents: [],
  });
  const kid = await signUp('del-kid@test.com', 'testtest1');
  await callable('joinFamily', kid.idToken, {});
  const members = await db.collection(`families/${familyId}/members`).get();
  const kidId = members.docs.find((d) => d.get('role') === 'kid').id;

  await callable('deleteAccount', kid.idToken, {});
  assert.equal((await db.doc(`families/${familyId}/members/${kidId}`).get()).get('status'), 'deleted');
  await waitFor(async () =>
    (await pushLogWhere((p) => p.uid === owner.uid && p.body === 'Kid deleted their Bank of Mom and Dad account.')).length === 1);

  // Owner deletes: remaining kids (re-invite one) become disabled
  const kid2Ref = await db.collection(`families/${familyId}/members`).add({ email: 'del-kid2@test.com', uid: null, role: 'kid', displayName: 'Kid2', status: 'invited', isOwner: false, balanceCents: 0, colorIndex: 1, lastSeenAt: null, createdAt: new Date(), joinedAt: null });
  await callable('deleteAccount', owner.idToken, {});
  assert.equal((await kid2Ref.get()).get('status'), 'disabled');
});

test('runRecurringNow sweeps a due template, creates a request, and approving it pays out', async () => {
  const parent = await signUp('rec-parent@test.com', 'testtest1');
  const { familyId } = await callable('createFamily', parent.idToken, {
    name: 'Rec Family', kids: [{ name: 'Kid', email: 'rec-kid@test.com' }], coParents: [],
  });
  const members = await db.collection(`families/${familyId}/members`).get();
  const kidId = members.docs.find((d) => d.get('role') === 'kid').id;

  const eightDaysAgo = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000);
  const recRef = await db.collection(`families/${familyId}/recurring`).add({
    kidMemberId: kidId,
    amountCents: 1000,
    reason: 'Allowance',
    note: null,
    interval: 'weekly',
    nextDueAt: eightDaysAgo,
    active: true,
    createdByUid: parent.uid,
    createdAt: new Date(),
  });

  const result = await callable('runRecurringNow', parent.idToken, { familyId });
  assert.equal(result.created, 1);

  // Idempotency: calling the sweep again immediately must not create a
  // second request for the same occurrence (money-safety: no duplicate pay).
  const result2 = await callable('runRecurringNow', parent.idToken, { familyId });
  assert.equal(result2.created, 0);

  const reqSnap = await db.collection(`families/${familyId}/requests`)
    .where('recurringId', '==', recRef.id).get();
  assert.equal(reqSnap.size, 1);
  const reqDoc = reqSnap.docs[0];
  assert.equal(reqDoc.get('origin'), 'recurring');
  assert.equal(reqDoc.get('status'), 'pending');
  assert.equal(reqDoc.get('amountCents'), 1000);

  const afterRec = await recRef.get();
  assert.ok(afterRec.get('nextDueAt').toMillis() > Date.now());

  await waitFor(async () =>
    (await pushLogWhere((p) => p.uid === parent.uid && p.body.startsWith('Recurring due for'))).length === 1);

  await callable('decideRequest', parent.idToken, { familyId, requestId: reqDoc.id, decision: 'approve' });
  const txs = await db.collection(`families/${familyId}/transactions`)
    .where('requestId', '==', reqDoc.id).get();
  assert.equal(txs.size, 1);
  await waitFor(async () =>
    (await db.doc(`families/${familyId}/members/${kidId}`).get()).get('balanceCents') === 1000);
});

test('family rename propagates to the parent user mirror', async () => {
  const parent = await signUp('rename-parent@test.com', 'testtest1');
  const { familyId } = await callable('createFamily', parent.idToken, {
    name: 'Original Name', kids: [], coParents: [],
  });
  await db.doc(`families/${familyId}`).update({ name: 'Renamed Bank' });
  await waitFor(async () =>
    (await db.doc(`users/${parent.uid}`).get()).get(`families.${familyId}.familyName`) === 'Renamed Bank');
});
