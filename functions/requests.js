import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { sendPushToUid, PUSH_TITLE } from './push.js';
import { requestApprovedCopy, requestDeniedCopy } from './copy.js';

export const decideRequest = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const { familyId, requestId, decision } = req.data ?? {};
  if (!familyId || !requestId || !['approve', 'deny'].includes(decision))
    throw new HttpsError('invalid-argument', 'familyId, requestId, decision required.');
  if (typeof familyId !== 'string' || familyId.includes('/')
      || typeof requestId !== 'string' || requestId.includes('/'))
    throw new HttpsError('invalid-argument', 'Bad familyId/requestId.');
  const db = getFirestore();
  const userSnap = await db.doc(`users/${uid}`).get();
  const entry = userSnap.get(`families.${familyId}`);
  if (!entry || entry.role !== 'parent' || entry.status !== 'active')
    throw new HttpsError('permission-denied', 'Active parents only.');

  const reqRef = db.doc(`families/${familyId}/requests/${requestId}`);
  const status = decision === 'approve' ? 'approved' : 'denied';
  const reqData = await db.runTransaction(async (t) => {
    const snap = await t.get(reqRef);
    if (!snap.exists) throw new HttpsError('not-found', 'Request not found.');
    const data = snap.data();
    if (data.status !== 'pending') throw new HttpsError('failed-precondition', 'Already decided.');
    t.update(reqRef, { status, decidedByUid: uid, decidedAt: FieldValue.serverTimestamp() });
    if (decision === 'approve') {
      t.set(db.collection(`families/${familyId}/transactions`).doc(), {
        kidMemberId: data.kidMemberId, amountCents: data.amountCents, reason: data.reason,
        date: data.date, note: data.note ?? null, source: 'request', requestId,
        createdByUid: uid, createdAt: FieldValue.serverTimestamp(), editedAt: null,
      });
    }
    return data;
  });

  try {
    const kidSnap = await db.doc(`families/${familyId}/members/${reqData.kidMemberId}`).get();
    if (kidSnap.get('uid')) {
      const deciderName = userSnap.get('displayName') || 'your parent';
      await sendPushToUid(kidSnap.get('uid'), PUSH_TITLE,
        decision === 'approve'
          ? requestApprovedCopy(reqData.amountCents)
          : requestDeniedCopy(reqData.amountCents, deciderName));
    }
  } catch (err) {
    console.error('decideRequest: post-commit kid push failed', err);
  }
  return { status };
});
