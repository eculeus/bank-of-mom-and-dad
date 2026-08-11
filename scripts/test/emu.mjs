import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const firebasercPath = path.resolve(__dirname, '../../.firebaserc');

export const PROJECT_ID = JSON.parse(readFileSync(firebasercPath, 'utf8')).projects.default;
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099';
const FUNCTIONS = '127.0.0.1:5001';

export async function signUp(email, password) {
  const res = await fetch(
    `http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }) },
  );
  const body = await res.json();
  if (!res.ok) throw new Error(`signUp failed: ${JSON.stringify(body)}`);
  return { uid: body.localId, idToken: body.idToken };
}

export async function callable(name, idToken, data = {}) {
  const res = await fetch(`http://${FUNCTIONS}/${PROJECT_ID}/us-central1/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${idToken}` },
    body: JSON.stringify({ data }),
  });
  const text = await res.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    // not JSON — fall through to the res.ok check below for a clear error
  }
  if (!res.ok && !body?.error) throw new Error(`${name}: HTTP ${res.status} ${text}`);
  if (body?.error) throw new Error(`${name}: ${JSON.stringify(body.error)}`);
  return body?.result;
}

export function adminDb() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error('Refusing to run: FIRESTORE_EMULATOR_HOST not set');
  }
  if (!getApps().length) initializeApp({ projectId: PROJECT_ID });
  return getFirestore();
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export async function waitFor(fn, { timeoutMs = 10000, everyMs = 250 } = {}) {
  const start = Date.now();
  for (;;) {
    const value = await fn();
    if (value) return value;
    if (Date.now() - start > timeoutMs) throw new Error('waitFor timed out');
    await sleep(everyMs);
  }
}
