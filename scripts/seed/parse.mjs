const MAX_YEAR = 2026;

export function parseAmount(raw) {
  if (raw == null) return null;
  let s = String(raw).trim().replace(/\\/g, '').replace(/[$,]/g, '').replace(/−/g, '-');
  if (!s) return null;
  const m = /^(-?)(\d+)(?:\.(\d{1,2}))?$/.exec(s);
  if (!m) return null;
  const cents = Number(m[2]) * 100 + Number((m[3] ?? '0').padEnd(2, '0'));
  return m[1] === '-' ? -cents : cents;
}

export function parseSheetDate(raw, fallbackYear) {
  const m = /^\s*(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?\s*$/.exec(String(raw ?? ''));
  if (!m) return null;
  let year = m[3] ? Number(m[3]) : fallbackYear;
  if (year == null) return null;
  if (year < 100) year += 2000;
  const corrected = year > MAX_YEAR;
  if (corrected) year = MAX_YEAR;
  return { year, month: Number(m[1]), day: Number(m[2]), corrected };
}

export function parseCsv(text) {
  const rows = [[]];
  let field = '';
  let inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') inQuotes = false;
      else field += c;
    } else if (c === '"') inQuotes = true;
    else if (c === ',') { rows.at(-1).push(field); field = ''; }
    else if (c === '\n') { rows.at(-1).push(field); field = ''; rows.push([]); }
    else if (c !== '\r') field += c;
  }
  rows.at(-1).push(field);
  if (rows.at(-1).length === 1 && rows.at(-1)[0] === '') rows.pop();
  return rows;
}

const iso = (d) =>
  `${d.year}-${String(d.month).padStart(2, '0')}-${String(d.day).padStart(2, '0')}`;

export function parseKidBlocks(csvText) {
  const grid = parseCsv(csvText);
  const cell = (r, c) => (grid[r]?.[c] ?? '').trim();

  // Anchor: the row whose cells read Date / Total under each kid-name cell.
  let headerRow = -1;
  const cols = [];
  for (let r = 0; r < grid.length; r++) {
    for (let c = 0; c < (grid[r]?.length ?? 0); c++) {
      if (cell(r, c) === 'Date' && cell(r, c + 1).startsWith('Total')) {
        if (headerRow === -1) headerRow = r;
        if (r === headerRow) cols.push(c);
      }
    }
    if (headerRow !== -1) break;
  }
  if (headerRow === -1) throw new Error('No Date/Total header row found');

  return cols.map((c) => {
    const block = {
      name: cell(headerRow - 1, c),
      statedTotalCents: parseAmount(cell(headerRow, c + 2)),
      rows: [],
      skipped: [],
    };
    let contextYear = null;
    const rawRows = [];
    for (let r = headerRow + 1; r < grid.length; r++) {
      const [d, reason, amt] = [cell(r, c), cell(r, c + 1), cell(r, c + 2)];
      if (d === 'STOP') break;
      if (!d && !reason && !amt) continue;
      rawRows.push({ d, reason, amt });
    }
    // Pass 1: forward-fill explicit years; note first explicit year for backfill.
    let firstExplicitYear = null;
    for (const row of rawRows) {
      const withYear = /\/\d{2,4}\s*$/.test(row.d);
      if (withYear) {
        const parsed = parseSheetDate(row.d, null);
        if (parsed && firstExplicitYear == null) firstExplicitYear = parsed.year;
      }
    }
    for (const { d, reason, amt } of rawRows) {
      const amountCents = parseAmount(amt);
      const date = parseSheetDate(d, contextYear ?? firstExplicitYear ?? 2023);
      if (date == null || amountCents == null) {
        block.skipped.push(`${d} | ${reason} | ${amt}`);
        continue;
      }
      contextYear = date.year;
      block.rows.push({ dateIso: iso(date), reason, amountCents, corrected: date.corrected });
    }
    return block;
  });
}
