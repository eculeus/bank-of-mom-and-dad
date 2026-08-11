import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

export const PUSH_TITLE = 'Bank of Mom & Dad';

export async function sendPushToUid(uid, title, body) {
  const db = getFirestore();
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    await db.collection('_pushLog').add({ uid, title, body, at: FieldValue.serverTimestamp() });
    return;
  }
  const snap = await db.doc(`users/${uid}`).get();
  const tokens = snap.get('fcmTokens') ?? [];
  if (!tokens.length) return;
  const res = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    webpush: { fcmOptions: { link: 'https://bank-of-mom-and-dad-ho.web.app/' } },
  });
  const dead = [];
  res.responses.forEach((r, i) => {
    const code = r.error?.code;
    if (!r.success && code === 'messaging/registration-token-not-registered') dead.push(tokens[i]);
  });
  if (dead.length) await snap.ref.update({ fcmTokens: FieldValue.arrayRemove(...dead) });
}

export async function activeParents(db, familyId) {
  const snap = await db.collection(`families/${familyId}/members`)
    .where('role', '==', 'parent').where('status', '==', 'active').get();
  return snap.docs.filter((d) => d.get('uid'));
}
