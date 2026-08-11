import { initializeApp } from 'firebase-admin/app';
initializeApp();

export { createFamily, joinFamily, onMemberWritten, onFamilyWritten } from './families.js';
export { onTransactionWritten } from './ledger.js';
export { notifyOnTransaction, onRequestCreated } from './notifications.js';
export { decideRequest } from './requests.js';
export { deleteAccount, recomputeBalances } from './lifecycle.js';
export { processRecurring, runRecurringNow } from './recurring.js';
