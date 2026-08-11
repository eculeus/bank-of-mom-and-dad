import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

function requireAuth(req) {
  if (!req.auth?.uid) throw new HttpsError('unauthenticated', 'Sign in first.');
  const email = (req.auth.token.email ?? '').toLowerCase();
  if (!email) throw new HttpsError('failed-precondition', 'Account has no email.');
  if (!req.auth.token.email_verified && process.env.FUNCTIONS_EMULATOR !== 'true')
    throw new HttpsError('failed-precondition', 'Please verify your email first.');
  return { uid: req.auth.uid, email, name: req.auth.token.name ?? email };
}

export const createFamily = onCall(async (req) => {
  const { uid, email, name: callerName } = requireAuth(req);
  const { name, kids = [], coParents = [] } = req.data ?? {};
  if (typeof name !== 'string' || !name.trim())
    throw new HttpsError('invalid-argument', 'Family name required.');
  if (!Array.isArray(kids) || !Array.isArray(coParents))
    throw new HttpsError('invalid-argument', 'kids and coParents must be arrays.');
  if (kids.length + coParents.length > 100)
    throw new HttpsError('invalid-argument', 'Too many invitees.');
  for (const kid of kids)
    if (!kid?.name?.trim() || !kid?.email?.trim() || !kid.email.includes('@'))
      throw new HttpsError('invalid-argument', 'Each kid needs a name and a valid email.');
  for (const coEmail of coParents)
    if (coEmail != null && coEmail.trim() && !coEmail.includes('@'))
      throw new HttpsError('invalid-argument', 'Invalid co-parent email.');

  const db = getFirestore();
  const famRef = db.collection('families').doc();
  const batch = db.batch();
  batch.set(famRef, { name: name.trim(), ownerUid: uid, createdAt: FieldValue.serverTimestamp() });

  const ownerRef = famRef.collection('members').doc();
  batch.set(ownerRef, {
    email, uid, role: 'parent', displayName: callerName, status: 'active',
    isOwner: true, balanceCents: 0, colorIndex: 0, lastSeenAt: null,
    createdAt: FieldValue.serverTimestamp(), joinedAt: FieldValue.serverTimestamp(),
  });
  const seenEmails = new Set([email]); // dedupe invitees against each other and against the caller
  let colorIndex = 0;
  for (const kid of kids) {
    const kidEmail = kid.email.trim().toLowerCase();
    if (seenEmails.has(kidEmail)) continue;
    seenEmails.add(kidEmail);
    batch.set(famRef.collection('members').doc(), {
      email: kidEmail, uid: null, role: 'kid',
      displayName: kid.name.trim(), status: 'invited', isOwner: false,
      balanceCents: 0, colorIndex: colorIndex % 6, lastSeenAt: null,
      createdAt: FieldValue.serverTimestamp(), joinedAt: null,
    });
    colorIndex += 1;
  }
  for (const coEmail of coParents) {
    if (!coEmail?.trim()) continue;
    const normalized = coEmail.trim().toLowerCase();
    if (seenEmails.has(normalized)) continue;
    seenEmails.add(normalized);
    batch.set(famRef.collection('members').doc(), {
      email: normalized, uid: null, role: 'parent',
      displayName: normalized, status: 'invited', isOwner: false,
      balanceCents: 0, colorIndex: 0, lastSeenAt: null,
      createdAt: FieldValue.serverTimestamp(), joinedAt: null,
    });
  }
  batch.set(db.doc(`users/${uid}`), {
    email, displayName: callerName, activeFamilyId: famRef.id,
    families: {
      [famRef.id]: { role: 'parent', memberId: ownerRef.id, status: 'active', isOwner: true, familyName: name.trim() },
    },
  }, { merge: true });
  await batch.commit();
  return { familyId: famRef.id };
});

export const joinFamily = onCall(async (req) => {
  const { uid, email, name: callerName } = requireAuth(req);
  const db = getFirestore();
  const snap = await db.collectionGroup('members').where('email', '==', email).get();
  const families = [];
  const mirror = {};
  let invitedDisplayName = null;
  // Families where the caller already has a genuine member doc (uid == caller's uid).
  // Guards against claiming a second, duplicate invited row in the same family.
  const ownedFamilyIds = new Set(
    snap.docs.filter((d) => d.data().uid === uid).map((d) => d.ref.parent.parent.id),
  );
  for (const memberDoc of snap.docs) {
    const famRef = memberDoc.ref.parent.parent;
    const famSnap = await famRef.get();
    if (!famSnap.exists) continue;
    const data = memberDoc.data();
    let status = data.status;
    if (data.uid == null && data.status === 'invited') {
      if (ownedFamilyIds.has(famRef.id)) continue; // caller already has a member doc in this family
      const freshData = await db.runTransaction(async (tx) => {
        const fresh = await tx.get(memberDoc.ref);
        if (!fresh.exists || fresh.get('uid') != null || fresh.get('status') !== 'invited') return null;
        tx.update(memberDoc.ref, { uid, status: 'active', joinedAt: FieldValue.serverTimestamp() });
        return fresh.data();
      });
      if (!freshData) continue; // lost the race between read and write: skip, don't throw
      status = 'active';
      invitedDisplayName ??= freshData.displayName;
      ownedFamilyIds.add(famRef.id);
    } else if (data.uid !== uid) {
      continue; // same email claimed by a different account: never steal
    }
    const entry = {
      role: data.role, memberId: memberDoc.id, status,
      isOwner: !!data.isOwner, familyName: famSnap.get('name') ?? '',
    };
    mirror[famRef.id] = entry;
    families.push({ familyId: famRef.id, ...entry });
  }
  const userRef = db.doc(`users/${uid}`);
  const userSnap = await userRef.get();
  const update = { email, displayName: userSnap.get('displayName') ?? invitedDisplayName ?? callerName };
  if (Object.keys(mirror).length) update.families = mirror;
  if (!userSnap.get('activeFamilyId') && families.length) update.activeFamilyId = families[0].familyId;
  await userRef.set(update, { merge: true });
  return { families };
});

export const onMemberWritten = onDocumentWritten(
  'families/{familyId}/members/{memberId}',
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const data = after.data();
    if (!data.uid) return;
    const before = event.data?.before;
    const beforeData = before?.exists ? before.data() : null;
    if (
      beforeData
      && beforeData.uid === data.uid
      && beforeData.role === data.role
      && beforeData.status === data.status
      && !!beforeData.isOwner === !!data.isOwner
    ) {
      return; // only irrelevant fields changed (lastSeenAt, colorIndex, displayName, ...)
    }
    const db = getFirestore();
    const famSnap = await db.doc(`families/${event.params.familyId}`).get();
    await db.doc(`users/${data.uid}`).set({
      families: {
        [event.params.familyId]: {
          role: data.role, memberId: event.params.memberId, status: data.status,
          isOwner: !!data.isOwner, familyName: famSnap.get('name') ?? '',
        },
      },
    }, { merge: true });
  },
);

export const onFamilyWritten = onDocumentWritten('families/{familyId}', async (event) => {
  const before = event.data?.before, after = event.data?.after;
  if (!after?.exists) return;
  const newName = after.get('name') ?? '';
  if (before?.exists && (before.get('name') ?? '') === newName) return;
  const db = getFirestore();
  const members = await db.collection(`families/${event.params.familyId}/members`).get();
  await Promise.all(members.docs.filter((m) => m.get('uid')).map((m) =>
    db.doc(`users/${m.get('uid')}`).set({ families: { [event.params.familyId]: { familyName: newName } } }, { merge: true })));
});
