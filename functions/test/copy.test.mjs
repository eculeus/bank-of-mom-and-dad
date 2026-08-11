import test from 'node:test';
import assert from 'node:assert/strict';
import {
  dollars, kidTransactionCopy, requestApprovedCopy, requestDeniedCopy,
  newRequestCopy, parentTransactionCopy, kidDeletedCopy, recurringDueCopy,
} from '../copy.js';

test('dollars formats abs cents with grouping', () => {
  assert.equal(dollars(3000), '$30.00');
  assert.equal(dollars(-13337), '$133.37');
  assert.equal(dollars(123456), '$1,234.56');
});
test('kid deposit copy (spec verbatim)', () =>
  assert.equal(kidTransactionCopy(3000), 'You received a new deposit of $30.00 in your account!'));
test('kid deduction copy (spec verbatim)', () =>
  assert.equal(kidTransactionCopy(-500), 'A deduction of $5.00 was made from your account.'));
test('approved copy (spec verbatim)', () =>
  assert.equal(requestApprovedCopy(3000), 'Your request for $30.00 was approved and added to your account!'));
test('denied copy (spec verbatim)', () =>
  assert.equal(requestDeniedCopy(3000, 'Mom'), 'Your request for $30.00 was denied — please talk to Mom.'));
test('new request copy', () =>
  assert.equal(newRequestCopy('Alex'), 'New transaction request from Alex'));
test('parent create copy positive/negative', () => {
  assert.equal(parentTransactionCopy('Mom', 'Alex', 3000, 'Worship', 'create'), 'Mom added $30.00 to Alex: Worship');
  assert.equal(parentTransactionCopy('Mom', 'Alex', -500, 'Candy', 'create'), 'Mom deducted $5.00 from Alex: Candy');
});
test('parent edit/delete copy', () => {
  assert.equal(parentTransactionCopy('Mom', 'Alex', 0, '', 'update'), 'Mom edited a transaction for Alex');
  assert.equal(parentTransactionCopy('Mom', 'Alex', 0, '', 'delete'), 'Mom deleted a transaction for Alex');
});
test('kid deleted copy', () =>
  assert.equal(kidDeletedCopy('Alex'), 'Alex deleted their Bank of Mom and Dad account.'));
test('recurring due copy positive', () =>
  assert.equal(recurringDueCopy('Alex', 1000, 'Allowance'), 'Recurring due for Alex: Allowance (+$10.00)'));
test('recurring due copy negative', () =>
  assert.equal(recurringDueCopy('Alex', -500, 'Dues'), 'Recurring due for Alex: Dues (−$5.00)'));
