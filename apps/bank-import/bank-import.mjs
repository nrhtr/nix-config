#!/usr/bin/env node
import * as api from '@actual-app/api';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync, readdirSync, mkdirSync, renameSync } from 'node:fs';
import { join } from 'node:path';

const SERVER_URL    = process.env.ACTUAL_SERVER_URL;
const SYNC_ID       = process.env.ACTUAL_SYNC_ID;
const PASSWORD      = readFileSync(process.env.ACTUAL_PASSWORD_FILE, 'utf8').trim();
const ACCOUNT_NAME  = process.env.ACCOUNT_NAME ?? 'Bank';
const INBOX_DIR     = process.env.INBOX_DIR;
const DONE_DIR      = join(INBOX_DIR, '..', 'done');
const DATA_DIR      = join(INBOX_DIR, '..', 'actual-data');
const PDFTOTEXT     = process.env.PDFTOTEXT_PATH ?? 'pdftotext';

const MONTHS = { Jan:1, Feb:2, Mar:3, Apr:4, May:5, Jun:6, Jul:7, Aug:8, Sep:9, Oct:10, Nov:11, Dec:12 };

// Strips trailing transaction-type from description to get a cleaner payee name
const TYPE_RE = /\s*(?:Eftpos|Visa|Mastercard)\s+Purchase\s*-\s*Card\s+\d+\s*$/i;

// Marks beginning of each transaction row (two dates at the start of the line)
const TXN_DATE_RE = /^\s{1,15}(\d{2}-\w{3})\s{2,15}(\d{2}-\w{3})\s+/;

// All monetary-value tokens on a line (covers negatives and comma-thousands)
const AMOUNT_RE = /(-?[\d,]+\.\d{2})/g;

// Lines that are purely structural noise and should always be ignored
const SKIP_RE = /Date\s+Processed|SpendME|Page\s+\d+\s+of|Statement\s+continues|ABN\s+\d+|division\s+of\s+Bank|^\s*Transactions\s*$/i;

function parseDate(dayMon, year) {
  const [day, mon] = dayMon.split('-');
  const m = MONTHS[mon];
  if (!m) throw new Error(`Unknown month: ${mon} in "${dayMon}"`);
  return `${year}-${String(m).padStart(2, '0')}-${day.padStart(2, '0')}`;
}

function parseCents(str) {
  return Math.round(parseFloat(str.replace(/,/g, '')) * 100);
}

// Extract the first line of a transaction from a raw layout line.
// Uses index-based amount extraction so a single space before the amount (e.g.
// "SQ *COMMONPLACE -6.40") doesn't confuse the parser.
function parseTransactionLine(line) {
  const dateMatch = line.match(TXN_DATE_RE);
  if (!dateMatch) return null;

  const amounts = [...line.matchAll(AMOUNT_RE)];
  if (amounts.length < 2) return null; // need at least amount + running balance

  // Second-to-last number is the transaction amount; last is the running balance
  const amountEntry = amounts[amounts.length - 2];
  const descText = line.slice(dateMatch[0].length, amountEntry.index).trim();

  return {
    txnDate:   dateMatch[1],
    descStart: descText,
    amount:    amountEntry[1],
  };
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

    // "Closing Balance" marks the end of transaction data; everything after is
    // account disclosures. Guard with rawTxns.length so the opening-summary
    // "Closing balance" (before any transactions) doesn't abort early.
    if (/Closing Balance/i.test(trimmed) && (rawTxns.length > 0 || current)) {
      if (current) rawTxns.push(current);
      current = null;
      break;
    }

    // Standalone 4-digit year section marker — but card numbers like "2776"
    // are also 4 digits, so only accept plausible calendar years.
    if (/^\d{4}$/.test(trimmed)) {
      const y = parseInt(trimmed, 10);
      if (y >= 2000 && y <= 2100) { currentYear = y; continue; }
      // fall through: treat as a description continuation
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
    const payee    = fullDesc.replace(TYPE_RE, '').trim();
    const date     = parseDate(t.txnDate, t.year);
    const amount   = parseCents(t.amount);
    const imported_id = createHash('sha256')
      .update(`${date}|${amount}|${fullDesc}`)
      .digest('hex')
      .slice(0, 16);
    return {
      date,
      amount,
      payee_name:  payee || undefined,
      notes:       fullDesc || undefined,
      imported_id,
      cleared:     true,
    };
  });
}

async function main() {
  mkdirSync(DONE_DIR, { recursive: true });
  mkdirSync(DATA_DIR, { recursive: true });

  const pdfFiles = readdirSync(INBOX_DIR).filter(f => /\.pdf$/i.test(f));
  if (pdfFiles.length === 0) {
    console.log('No PDF files in inbox — nothing to do.');
    return;
  }

  await api.init({ serverURL: SERVER_URL, password: PASSWORD, dataDir: DATA_DIR });
  await api.downloadBudget(SYNC_ID);

  const accounts = await api.getAccounts();
  const account  = accounts.find(a => a.name === ACCOUNT_NAME);
  if (!account) throw new Error(`Account "${ACCOUNT_NAME}" not found. Available: ${accounts.map(a => a.name).join(', ')}`);

  for (const file of pdfFiles) {
    const filePath = join(INBOX_DIR, file);
    console.log(`Processing ${file}...`);

    const txns = parsePdf(filePath);
    console.log(`  ${txns.length} transactions parsed`);

    if (txns.length > 0) {
      const result = await api.importTransactions(account.id, txns, { defaultCleared: true });
      console.log(`  Added: ${result.added}, Updated: ${result.updated}`);
    }

    const stamp = new Date().toISOString().slice(0, 19).replace(/:/g, '-');
    const ext = file.lastIndexOf('.') !== -1 ? file.slice(file.lastIndexOf('.')) : '';
    const base = file.slice(0, file.length - ext.length);
    const dstName = `${base}_${stamp}${ext}`;
    renameSync(filePath, join(DONE_DIR, dstName));
    console.log(`  Moved to done/${dstName}`);
  }

  await api.shutdown();
}

main().catch(e => { console.error(e); process.exit(1); });
