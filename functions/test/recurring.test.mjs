import test from 'node:test';
import assert from 'node:assert/strict';
import { advanceDue } from '../recurring.js';

test('weekly advances exactly 7 days', () => {
  const start = Date.UTC(2026, 0, 15, 12, 0, 0); // Jan 15 2026 12:00 UTC
  assert.equal(advanceDue(start, 'weekly'), start + 7 * 24 * 60 * 60 * 1000);
});

test('monthly Jan 15 -> Feb 15 (same day-of-month)', () => {
  const start = Date.UTC(2026, 0, 15, 9, 0, 0);
  assert.equal(advanceDue(start, 'monthly'), Date.UTC(2026, 1, 15, 9, 0, 0));
});

test('monthly Jan 31 2026 -> Feb 28 2026 (clamped, non-leap year)', () => {
  const start = Date.UTC(2026, 0, 31, 9, 0, 0);
  assert.equal(advanceDue(start, 'monthly'), Date.UTC(2026, 1, 28, 9, 0, 0));
});

test('monthly Mar 31 -> Apr 30 (clamped)', () => {
  const start = Date.UTC(2026, 2, 31, 9, 0, 0);
  assert.equal(advanceDue(start, 'monthly'), Date.UTC(2026, 3, 30, 9, 0, 0));
});

test('monthly Jan 31 2024 -> Feb 29 2024 (clamped, leap year)', () => {
  assert.equal(advanceDue(Date.UTC(2024, 0, 31), 'monthly'), Date.UTC(2024, 1, 29));
});
