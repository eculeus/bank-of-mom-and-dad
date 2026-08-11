import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';

// Pure: advance a due date by one interval. Monthly clamps the day-of-month
// to the target month's length (e.g. Jan 31 -> Feb 28/29). Uses UTC math
// throughout so DST transitions never shift the result.
export function advanceDue(dateMillis, interval) {
  const d = new Date(dateMillis);
  if (interval === 'weekly') {
    return dateMillis + 7 * 24 * 60 * 60 * 1000;
  }
  if (interval === 'monthly') {
    const year = d.getUTCFullYear();
    const month = d.getUTCMonth();
    const day = d.getUTCDate();
    const hours = d.getUTCHours();
    const minutes = d.getUTCMinutes();
    const seconds = d.getUTCSeconds();
    const ms = d.getUTCMilliseconds();
    const targetMonth = month + 1;
    // Day 0 of (targetMonth + 1) is the last day of targetMonth.
    const lastDayOfTargetMonth = new Date(Date.UTC(year, targetMonth + 1, 0)).getUTCDate();
    const clampedDay = Math.min(day, lastDayOfTargetMonth);
    return Date.UTC(year, targetMonth, clampedDay, hours, minutes, seconds, ms);
  }
  throw new Error(`Unknown recurring interval: ${interval}`);
}

// Sweeps due recurring templates (across all families, or a single family
// when familyId is given) and creates one pending request per due template,
// then advances nextDueAt past `now` (catching up in one jump after downtime
// rather than creating a backlog of requests).
//
// Request creation and template advancement happen inside a single
// transaction, keyed by a deterministic request doc ID
// (`${templateId}_${dueMillis}`), so that:
//   - a crash between the two writes can't happen (they're atomic), and
//   - a scheduled sweep racing a manual runRecurringNow sweep for the same
//     family can't create a duplicate request for the same occurrence: the
//     loser's transaction re-reads the template and either finds the
//     request doc already there (idempotent retry — still safe to advance)
//     or finds nextDueAt already moved past dueMillis (the winner already
//     advanced it — skip entirely, no double-advance).
//
// Each template's transaction is isolated in its own try/catch so one bad
// template (e.g. a corrupt doc) can't abort the sweep for the rest.
// Returns { created, errors } — created is only incremented when a new
// request doc was actually written this call.
export async function runRecurringSweep(db, nowMillis, familyId = null) {
  const base = familyId
    ? db.collection(`families/${familyId}/recurring`)
    : db.collectionGroup('recurring');
  const dueSnap = await base
    .where('active', '==', true)
    .where('nextDueAt', '<=', Timestamp.fromMillis(nowMillis))
    .get();

  let created = 0;
  const errors = [];
  for (const doc of dueSnap.docs) {
    const templateRef = doc.ref;
    try {
      const fid = familyId ?? templateRef.parent.parent.id;
      const dueMillis = doc.get('nextDueAt').toMillis();
      const requestRef = db.doc(`families/${fid}/requests/${templateRef.id}_${dueMillis}`);

      const madeRequest = await db.runTransaction(async (t) => {
        const [requestSnap, templateSnap] = await Promise.all([
          t.get(requestRef),
          t.get(templateRef),
        ]);
        if (!templateSnap.exists) return false;
        const data = templateSnap.data();
        // Another sweep already handled (and advanced) this occurrence.
        if (!data.active || data.nextDueAt.toMillis() !== dueMillis) return false;

        if (!requestSnap.exists) {
          t.set(requestRef, {
            kidMemberId: data.kidMemberId,
            amountCents: data.amountCents,
            reason: data.reason,
            note: data.note ?? null,
            date: data.nextDueAt,
            status: 'pending',
            decidedByUid: null,
            hiddenByKid: false,
            origin: 'recurring',
            recurringId: templateRef.id,
            createdAt: FieldValue.serverTimestamp(),
          });
        }

        let nextMillis = dueMillis;
        do {
          nextMillis = advanceDue(nextMillis, data.interval);
        } while (nextMillis <= nowMillis);
        t.update(templateRef, { nextDueAt: Timestamp.fromMillis(nextMillis) });

        return !requestSnap.exists;
      });

      if (madeRequest) created += 1;
    } catch (err) {
      console.error(`runRecurringSweep: template ${templateRef.path} failed`, err);
      errors.push({ path: templateRef.path, message: err?.message ?? String(err) });
    }
  }
  return { created, errors };
}

export const processRecurring = onSchedule(
  { schedule: 'every day 09:00', timeZone: 'America/New_York' },
  async () => {
    const { created, errors } = await runRecurringSweep(getFirestore(), Date.now());
    console.log(`processRecurring: created ${created} request(s), ${errors.length} error(s)`);
    if (errors.length) console.error('processRecurring errors', errors);
  },
);

export const runRecurringNow = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const { familyId } = req.data ?? {};
  if (typeof familyId !== 'string' || !familyId || familyId.includes('/'))
    throw new HttpsError('invalid-argument', 'Bad familyId.');
  const db = getFirestore();
  const entry = (await db.doc(`users/${uid}`).get()).get(`families.${familyId}`);
  if (!entry || entry.role !== 'parent' || entry.status !== 'active')
    throw new HttpsError('permission-denied', 'Active parents only.');
  const { created, errors } = await runRecurringSweep(db, Date.now(), familyId);
  return { created, errors };
});
