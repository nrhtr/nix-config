#!/usr/bin/env node
// Usage: PDFTOTEXT_PATH=... node bank-import-preview.mjs statement.pdf
// Prints parsed transactions so you can verify before importing.
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

const PDFTOTEXT = process.env.PDFTOTEXT_PATH ?? 'pdftotext';
const pdfPath = process.argv[2];
if (!pdfPath) { console.error('Usage: bank-import-preview.mjs <file.pdf>'); process.exit(1); }

// --- parser (kept in sync with bank-import.mjs) ---

const MONTHS = { Jan:1, Feb:2, Mar:3, Apr:4, May:5, Jun:6, Jul:7, Aug:8, Sep:9, Oct:10, Nov:11, Dec:12 };
const TYPE_RE = /\s*(?:Eftpos|Visa|Mastercard)\s+Purchase\s*-\s*Card\s+\d+\s*$/i;
const TXN_DATE_RE = /^\s{1,15}(\d{2}-\w{3})\s{2,15}(\d{2}-\w{3})\s+/;
const AMOUNT_RE = /(-?[\d,]+\.\d{2})/g;
const SKIP_RE = /Date\s+Processed|SpendME|Page\s+\d+\s+of|Statement\s+continues|ABN\s+\d+|division\s+of\s+Bank|^\s*Transactions\s*$/i;

function parseDate(dayMon, year) {
  const [day, mon] = dayMon.split('-');
  const m = MONTHS[mon];
  if (!m) throw new Error(`Unknown month: ${mon}`);
  return `${year}-${String(m).padStart(2, '0')}-${day.padStart(2, '0')}`;
}
function parseCents(str) { return Math.round(parseFloat(str.replace(/,/g, '')) * 100); }
function parseTransactionLine(line) {
  const dateMatch = line.match(TXN_DATE_RE);
  if (!dateMatch) return null;
  const amounts = [...line.matchAll(AMOUNT_RE)];
  if (amounts.length < 2) return null;
  const amountEntry = amounts[amounts.length - 2];
  return { txnDate: dateMatch[1], descStart: line.slice(dateMatch[0].length, amountEntry.index).trim(), amount: amountEntry[1] };
}

function parsePdf(pdfPath) {
  const raw = execFileSync(PDFTOTEXT, ['-layout', pdfPath, '-'], { encoding: 'utf8' });
  let currentYear = new Date().getFullYear();
  const rawTxns = [];
  let current = null;
  for (const line of raw.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.length < 2) continue;
    if (SKIP_RE.test(trimmed)) continue;
    if (/Closing Balance/i.test(trimmed) && (rawTxns.length > 0 || current)) {
      if (current) rawTxns.push(current);
      current = null;
      break;
    }
    if (/^\d{4}$/.test(trimmed)) {
      const y = parseInt(trimmed, 10);
      if (y >= 2000 && y <= 2100) { currentYear = y; continue; }
    }
    const parsed = parseTransactionLine(line);
    if (parsed) {
      if (current) rawTxns.push(current);
      current = { txnDate: parsed.txnDate, year: currentYear, descParts: [parsed.descStart], amount: parsed.amount };
      continue;
    }
    if (current) current.descParts.push(trimmed);
  }
  if (current) rawTxns.push(current);
  return rawTxns.map(t => {
    const fullDesc = t.descParts.join(' ').replace(/\s+/g, ' ').trim();
    const payee = fullDesc.replace(TYPE_RE, '').trim();
    const date = parseDate(t.txnDate, t.year);
    const amount = parseCents(t.amount);
    const imported_id = createHash('sha256').update(`${date}|${amount}|${fullDesc}`).digest('hex').slice(0, 16);
    return { date, amount, payee_name: payee, notes: fullDesc, imported_id };
  });
}

// --- display ---

const txns = parsePdf(pdfPath);
const credits = txns.filter(t => t.amount > 0);
const debits  = txns.filter(t => t.amount < 0);
const total   = txns.reduce((s, t) => s + t.amount, 0);

const fmt = cents => {
  const sign = cents < 0 ? '-' : '+';
  return `${sign}$${(Math.abs(cents) / 100).toFixed(2).padStart(9)}`;
};
const trunc = (s, n) => s.length > n ? s.slice(0, n - 1) + '…' : s.padEnd(n);

console.log(`\nFile: ${pdfPath}`);
console.log(`Transactions: ${txns.length}  (${credits.length} credits, ${debits.length} debits)`);
console.log(`Net: ${fmt(total)}\n`);
console.log(`${'Date'.padEnd(12)}${'Amount'.padStart(12)}  Payee`);
console.log('─'.repeat(70));
for (const t of txns) {
  console.log(`${t.date.padEnd(12)}${fmt(t.amount).padStart(12)}  ${trunc(t.payee_name ?? '', 44)}`);
}
console.log('─'.repeat(70));
console.log(`${'Net'.padEnd(12)}${fmt(total).padStart(12)}\n`);
