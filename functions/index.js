import { initializeApp } from 'firebase-admin/app';
import { setGlobalOptions } from 'firebase-functions/v2';

// Cost circuit-breaker: cap how far a spam loop (or a client bug) can autoscale
// billed invocations. A single family needs a handful of instances at most; 10
// leaves generous headroom while bounding worst-case spend. Independent of App
// Check — this is containment, not prevention.
setGlobalOptions({ maxInstances: 10 });

initializeApp();

export { createFamily, joinFamily, onMemberWritten, onFamilyWritten } from './families.js';
export { onTransactionWritten } from './ledger.js';
export { notifyOnTransaction, onRequestCreated } from './notifications.js';
export { decideRequest } from './requests.js';
export { deleteAccount, recomputeBalances } from './lifecycle.js';
export { processRecurring, runRecurringNow } from './recurring.js';
