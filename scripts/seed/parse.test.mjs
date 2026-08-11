import test from 'node:test';
import assert from 'node:assert/strict';
import { parseAmount, parseSheetDate, parseCsv, parseKidBlocks } from './parse.mjs';

test('parseAmount handles the sheet mess', () => {
  assert.equal(parseAmount('$10.00'), 1000);
  assert.equal(parseAmount('-$133.37'), -13337);
  assert.equal(parseAmount('\\-$7.00'), -700);
  assert.equal(parseAmount('60'), 6000);
  assert.equal(parseAmount('-2'), -200);
  assert.equal(parseAmount('$1,234.56'), 123456);
  assert.equal(parseAmount(''), null);
  assert.equal(parseAmount('Total'), null);
});

test('parseSheetDate full, short, and typo years', () => {
  assert.deepEqual(parseSheetDate('1/14/2023', null), { year: 2023, month: 1, day: 14, corrected: false });
  assert.deepEqual(parseSheetDate('2/15', 2025), { year: 2025, month: 2, day: 15, corrected: false });
  assert.deepEqual(parseSheetDate('8/28/2028', null), { year: 2026, month: 8, day: 28, corrected: true });
  assert.equal(parseSheetDate('STOP', 2023), null);
  assert.equal(parseSheetDate('', 2023), null);
});

test('parseCsv handles quoted commas', () => {
  assert.deepEqual(parseCsv('a,"b, c",d\n1,2,3'), [['a', 'b, c', 'd'], ['1', '2', '3']]);
});

const FIXTURE = [
  ',,,,,,,',
  'Alex,,,,Bailey,,,',
  'Date,Total ,-$5.00,,Date,Total ,$61.00,,',
  ',,,,,,,',
  '1/1/2023,Worship,$10.00,,1/2/2023,"Toilet, clean",$2.00,,',
  '2/15,Red Envelope,60,,8/28/2028,Backpack,-$1.00,,',
  '3/1/2024,Candy,-$75.00,,junkdate,junk,junk,,',
].join('\n');

test('parseKidBlocks splits columns, infers years, keeps stated totals', () => {
  const blocks = parseKidBlocks(FIXTURE);
  assert.equal(blocks.length, 2);
  const [alex, bailey] = blocks;
  assert.equal(alex.name, 'Alex');
  assert.equal(alex.statedTotalCents, -500);
  assert.deepEqual(alex.rows.map((r) => r.dateIso), ['2023-01-01', '2023-02-15', '2024-03-01']);
  assert.deepEqual(alex.rows.map((r) => r.amountCents), [1000, 6000, -7500]);
  assert.equal(bailey.name, 'Bailey');
  assert.equal(bailey.statedTotalCents, 6100);
  assert.equal(bailey.rows[0].reason, 'Toilet, clean');
  assert.equal(bailey.rows[1].dateIso, '2026-08-28');
  assert.equal(bailey.rows[1].corrected, true);
  assert.equal(bailey.skipped.length, 1);
});
