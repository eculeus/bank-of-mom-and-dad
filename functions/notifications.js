import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { sendPushToUid, activeParents, PUSH_TITLE } from './push.js';
import { shouldSendRequestPush } from './throttle.js';
import { kidTransactionCopy, parentTransactionCopy, newRequestCopy, recurringDueCopy } from './copy.js';

export const notifyOnTransaction = onDocumentWritten(
  'families/{familyId}/transactions/{txId}',
  async (event) => {
    const db = getFirestore();
    const before = event.data?.before;
    const after = event.data?.after;
    const eventType = !before?.exists ? 'create' : !after?.exists ? 'delete' : 'update';
    const data = (after?.exists ? after : before).data();
    if (data.source === 'seed' || data.source === 'adjustment') return;
    const { familyId } = event.params;
    const kidSnap = await db.doc(`families/${familyId}/members/${data.kidMemberId}`).get();
    if (!kidSnap.exists) return;
    const actorUid = data.createdByUid;
    const actorSnap = await db.doc(`users/${actorUid}`).get();
    const actorName = actorSnap.get('displayName') || 'A parent';

    if (eventType === 'create' && data.source === 'parent' && kidSnap.get('uid')) {
      await sendPushToUid(kidSnap.get('uid'), PUSH_TITLE, kidTransactionCopy(data.amountCents));
    }
    const parents = await activeParents(db, familyId);
    await Promise.all(parents
      .filter((p) => p.get('uid') !== actorUid)
      .map((p) => sendPushToUid(p.get('uid'), PUSH_TITLE,
        parentTransactionCopy(actorName, kidSnap.get('displayName'), data.amountCents, data.reason, eventType))));
  },
);

export const onRequestCreated = onDocumentCreated(
  'families/{familyId}/requests/{reqId}',
  async (event) => {
    const db = getFirestore();
    const data = event.data.data();
    const { familyId } = event.params;
    const kidSnap = await db.doc(`families/${familyId}/members/${data.kidMemberId}`).get();
    const kidName = kidSnap.get('displayName') || 'your kid';
    for (const p of await activeParents(db, familyId)) {
      const stateRef = db.doc(`families/${familyId}/notificationState/${p.get('uid')}`);
      const send = await db.runTransaction(async (t) => {
        const s = await t.get(stateRef);
        const last = s.exists ? (s.get('lastRequestPushAt')?.toMillis() ?? null) : null;
        if (!shouldSendRequestPush(last, Date.now())) return false;
        t.set(stateRef, { lastRequestPushAt: Timestamp.now() }, { merge: true });
        return true;
      });
      if (send) {
        try {
          const body = data.origin === 'recurring'
            ? recurringDueCopy(kidName, data.amountCents, data.reason)
            : newRequestCopy(kidName);
          await sendPushToUid(p.get('uid'), PUSH_TITLE, body);
        } catch (err) {
          console.warn('sendPushToUid failed after throttle timestamp committed', err);
        }
      }
    }
  },
);
