import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { getFirestore } from 'firebase-admin/firestore';

export async function recomputeKidBalance(db, familyId, kidMemberId) {
  const txs = await db
    .collection(`families/${familyId}/transactions`)
    .where('kidMemberId', '==', kidMemberId)
    .get();
  const total = txs.docs.reduce((sum, d) => sum + d.get('amountCents'), 0);
  await db.doc(`families/${familyId}/members/${kidMemberId}`)
    .set({ balanceCents: total }, { merge: true });
  return total;
}

export const onTransactionWritten = onDocumentWritten(
  'families/{familyId}/transactions/{txId}',
  async (event) => {
    const db = getFirestore();
    const kidIds = new Set();
    if (event.data?.before?.exists) kidIds.add(event.data.before.get('kidMemberId'));
    if (event.data?.after?.exists) kidIds.add(event.data.after.get('kidMemberId'));
    for (const kidId of kidIds) {
      await recomputeKidBalance(db, event.params.familyId, kidId);
    }
  },
);
