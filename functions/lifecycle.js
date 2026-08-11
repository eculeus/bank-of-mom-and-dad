import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';
import { sendPushToUid, activeParents, PUSH_TITLE } from './push.js';
import { kidDeletedCopy } from './copy.js';
import { recomputeKidBalance } from './ledger.js';

export const deleteAccount = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const userSnap = await userRef.get();
  const families = userSnap.get('families') ?? {};
  const myName = userSnap.get('displayName') || 'Someone';

  for (const [familyId, entry] of Object.entries(families)) {
    const memberRef = db.doc(`families/${familyId}/members/${entry.memberId}`);
    const memberSnap = await memberRef.get();
    if (!memberSnap.exists || memberSnap.get('status') === 'deleted') continue;
    if (entry.role === 'kid') {
      const parents = await activeParents(db, familyId);
      await memberRef.update({ status: 'deleted' });
      await Promise.all(parents.map((p) =>
        sendPushToUid(p.get('uid'), PUSH_TITLE, kidDeletedCopy(myName))));
    } else if (entry.isOwner) {
      const kids = await db.collection(`families/${familyId}/members`)
        .where('role', '==', 'kid').get();
      for (const kid of kids.docs) {
        if (kid.get('status') === 'active' || kid.get('status') === 'invited') {
          await kid.ref.update({ status: 'disabled' });
        }
      }
      await memberRef.update({ status: 'deleted' });
    } else {
      await memberRef.update({ status: 'deleted' });
    }
  }
  await userRef.set({ deletedAt: FieldValue.serverTimestamp(), fcmTokens: [] }, { merge: true });
  await getAuth().deleteUser(uid);
  return { ok: true };
});

export const recomputeBalances = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const { familyId } = req.data ?? {};
  const db = getFirestore();
  const entry = (await db.doc(`users/${uid}`).get()).get(`families.${familyId}`);
  if (!entry || entry.role !== 'parent' || entry.status !== 'active')
    throw new HttpsError('permission-denied', 'Parents only.');
  const kids = await db.collection(`families/${familyId}/members`)
    .where('role', '==', 'kid').get();
  const balances = {};
  for (const kid of kids.docs) {
    balances[kid.id] = await recomputeKidBalance(db, familyId, kid.id);
  }
  return { balances };
});
