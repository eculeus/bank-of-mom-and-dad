import test from 'node:test';
import assert from 'node:assert/strict';
import { shouldSendRequestPush, REQUEST_PUSH_WINDOW_MS } from '../throttle.js';

test('window is 10 minutes', () => assert.equal(REQUEST_PUSH_WINDOW_MS, 600000));
test('first ever push sends', () => assert.equal(shouldSendRequestPush(null, 1000), true));
test('inside window suppresses', () =>
  assert.equal(shouldSendRequestPush(1000, 1000 + 599999), false));
test('exactly at window sends', () =>
  assert.equal(shouldSendRequestPush(1000, 1000 + 600000), true));
test('after window sends', () =>
  assert.equal(shouldSendRequestPush(1000, 1000 + 600001), true));
