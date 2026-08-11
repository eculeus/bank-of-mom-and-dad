import test, { before, after } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, deleteDoc, getDoc } from 'firebase/firestore';

const PROJECT = 'bomad-rules-test';
let env;

const PARENT = { uid: 'parent1', email: 'p1@x.com' };
const KID = { uid: 'kid1', email: 'k1@x.com' };

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { rules: readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/parent1'), {
      email: 'p1@x.com',
      families: { f1: { role: 'parent', memberId: 'mp1', status: 'active', isOwner: true, familyName: 'F' } },
    });
    await setDoc(doc(db, 'users/kid1'), {
      email: 'k1@x.com',
      families: { f1: { role: 'kid', memberId: 'mk1', status: 'active', isOwner: false, familyName: 'F' } },
    });
    await setDoc(doc(db, 'families/f1'), { name: 'F', ownerUid: 'parent1' });
    await setDoc(doc(db, 'families/f1/members/mp1'), { email: 'p1@x.com', uid: 'parent1', role: 'parent', displayName: 'P', status: 'active', isOwner: true, balanceCents: 0 });
    await setDoc(doc(db, 'families/f1/members/mk1'), { email: 'k1@x.com', uid: 'kid1', role: 'kid', displayName: 'K', status: 'active', isOwner: false, balanceCents: 500 });
    await setDoc(doc(db, 'families/f1/transactions/t1'), { kidMemberId: 'mk1', amountCents: 500, reason: 'seeded', date: new Date(), source: 'parent', createdByUid: 'parent1' });
    await setDoc(doc(db, 'families/f1/transactions/t2'), { kidMemberId: 'mk1', amountCents: 100, reason: 'other parent', date: new Date(), source: 'parent', createdByUid: 'parent2' });
    await setDoc(doc(db, 'families/f1/requests/rPending'), {
      kidMemberId: 'mk1', amountCents: 1500, reason: 'pending one', date: new Date(),
      note: null, status: 'pending', decidedByUid: null, hiddenByKid: false, createdAt: new Date(),
    });

    // Second kid in f1, for cross-kid read isolation.
    await setDoc(doc(db, 'families/f1/members/mk2'), { email: 'k2@x.com', uid: 'kid2', role: 'kid', displayName: 'K2', status: 'active', isOwner: false, balanceCents: 0 });
    await setDoc(doc(db, 'families/f1/transactions/t3'), { kidMemberId: 'mk2', amountCents: 200, reason: 'other kid', date: new Date(), source: 'parent', createdByUid: 'parent1' });

    // A second, unrelated family — for multi-tenant isolation checks.
    await setDoc(doc(db, 'families/f2'), { name: 'F2', ownerUid: 'parent9' });
    await setDoc(doc(db, 'families/f2/members/mp9'), { email: 'p9@x.com', uid: 'parent9', role: 'parent', displayName: 'P9', status: 'active', isOwner: true, balanceCents: 0 });

    // An outsider with no membership in any family.
    await setDoc(doc(db, 'users/outsider1'), { email: 'o1@x.com', families: {} });
  });
});
after(async () => env.cleanup());

const asParent = () => env.authenticatedContext(PARENT.uid, { email: PARENT.email }).firestore();
const asKid = () => env.authenticatedContext(KID.uid, { email: KID.email }).firestore();
const asOutsider = () => env.authenticatedContext('outsider1', { email: 'o1@x.com' }).firestore();
const asUnauthenticated = () => env.unauthenticatedContext().firestore();

test('parent can create a valid transaction', () =>
  assertSucceeds(setDoc(doc(asParent(), 'families/f1/transactions/tNew'), {
    kidMemberId: 'mk1', amountCents: 3000, reason: 'Worship', date: new Date(),
    note: null, source: 'parent', requestId: null, createdByUid: 'parent1', createdAt: new Date(),
  })));

test('kid cannot create a transaction', () =>
  assertFails(setDoc(doc(asKid(), 'families/f1/transactions/tKid'), {
    kidMemberId: 'mk1', amountCents: 100, reason: 'sneaky', date: new Date(),
    source: 'parent', createdByUid: 'kid1',
  })));

test('parent cannot edit another parent’s transaction', () =>
  assertFails(updateDoc(doc(asParent(), 'families/f1/transactions/t2'), { amountCents: 1 })));

test('parent can delete own transaction', () =>
  assertSucceeds(deleteDoc(doc(asParent(), 'families/f1/transactions/t1'))));

test('kid can create own pending request only', async () => {
  await assertSucceeds(setDoc(doc(asKid(), 'families/f1/requests/r1'), {
    kidMemberId: 'mk1', amountCents: 2000, reason: 'book', date: new Date(),
    note: null, status: 'pending', decidedByUid: null, hiddenByKid: false, createdAt: new Date(),
  }));
  await assertFails(setDoc(doc(asKid(), 'families/f1/requests/r2'), {
    kidMemberId: 'mk1', amountCents: 2000, reason: 'book', date: new Date(), status: 'approved',
  }));
});

test('kid cannot write balanceCents; can write own lastSeenAt', async () => {
  await assertFails(updateDoc(doc(asKid(), 'families/f1/members/mk1'), { balanceCents: 99999 }));
  await assertSucceeds(updateDoc(doc(asKid(), 'families/f1/members/mk1'), { lastSeenAt: new Date() }));
});

test('client cannot touch users.families mirror', () =>
  assertFails(updateDoc(doc(asParent(), 'users/parent1'), {
    families: { f2: { role: 'parent', memberId: 'x', status: 'active', isOwner: true, familyName: 'X' } },
  })));

test('notificationState is server-only', () =>
  assertFails(setDoc(doc(asParent(), 'families/f1/notificationState/parent1'), { lastRequestPushAt: new Date() })));

test('kid cannot create a doc in families/f1/recurring', () =>
  assertFails(setDoc(doc(asKid(), 'families/f1/recurring/rec1'), {
    kidMemberId: 'mk1', amountCents: 1000, reason: 'r', interval: 'weekly',
    nextDueAt: new Date(), active: true, createdByUid: 'kid1', createdAt: new Date(),
  })));

test('parent can create a valid recurring doc', () =>
  assertSucceeds(setDoc(doc(asParent(), 'families/f1/recurring/rec2'), {
    kidMemberId: 'mk1', amountCents: 1000, reason: 'r', interval: 'weekly',
    nextDueAt: new Date(), active: true, createdByUid: 'parent1', createdAt: new Date(),
  })));

test('kid cannot update their own pending request to approved', () =>
  assertFails(updateDoc(doc(asKid(), 'families/f1/requests/rPending'), { status: 'approved' })));

test('kid cannot read another kid\'s transaction', () =>
  assertFails(getDoc(doc(asKid(), 'families/f1/transactions/t3'))));

test('multi-tenant: outsider cannot read family f1 or its subdocs', async () => {
  await assertFails(getDoc(doc(asOutsider(), 'families/f1')));
  await assertFails(getDoc(doc(asOutsider(), 'families/f1/members/mk1')));
  await assertFails(getDoc(doc(asOutsider(), 'families/f1/transactions/t2')));
});

test('multi-tenant: unauthenticated cannot read family f1', () =>
  assertFails(getDoc(doc(asUnauthenticated(), 'families/f1'))));

test('parent creating a member with isOwner true fails', () =>
  assertFails(setDoc(doc(asParent(), 'families/f1/members/mBad'), {
    email: 'bad@x.com', uid: null, role: 'parent', displayName: 'Bad',
    status: 'invited', isOwner: true, balanceCents: 0,
  })));

test('parent cannot flip the owner (or another parent) member status', () =>
  assertFails(updateDoc(doc(asParent(), 'families/f1/members/mp1'), { status: 'disabled' })));

test('parent can still disable a kid member', () =>
  assertSucceeds(updateDoc(doc(asParent(), 'families/f1/members/mk1'), { status: 'disabled' })));
