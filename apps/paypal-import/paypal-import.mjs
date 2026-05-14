#!/usr/bin/env node
import * as api from '@actual-app/api';
import { parse } from 'csv-parse/sync';
import { readFileSync, readdirSync, mkdirSync, renameSync } from 'node:fs';
import { join } from 'node:path';

const SERVER_URL   = process.env.ACTUAL_SERVER_URL;
const SYNC_ID      = process.env.ACTUAL_SYNC_ID;
const PASSWORD     = readFileSync(process.env.ACTUAL_PASSWORD_FILE, 'utf8').trim();
const ACCOUNT_NAME = process.env.ACCOUNT_NAME ?? 'Paypal';
const CURRENCY     = process.env.CURRENCY ?? 'AUD';
const INBOX_DIR    = process.env.INBOX_DIR;
const DONE_DIR     = join(INBOX_DIR, '..', 'done');
const DATA_DIR     = join(INBOX_DIR, '..', 'actual-data');

// PayPal CSV amounts: "1,234.56" or "-1,234.56" → integer cents
function parseAmount(str) {
  return Math.round(parseFloat(str.replace(/,/g, '')) * 100);
}

// PayPal Australia exports DD/MM/YYYY; configurable via DATE_FORMAT=MDY for US format
function parseDate(str) {
  const [a, b, y] = str.split('/');
  const [d, m] = (process.env.DATE_FORMAT ?? 'DMY') === 'MDY' ? [b, a] : [a, b];
  return `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`;
}

function toTransactions(csvContent) {
  const rows = parse(csvContent, { columns: true, skip_empty_lines: true, bom: true });
  const skipped = [];

  const txns = rows
    .filter(r => {
      if (r['Status'] !== 'Completed') { skipped.push(`${r['Transaction ID']} status=${r['Status']}`); return false; }
      if (r['Currency'] !== CURRENCY)  { skipped.push(`${r['Transaction ID']} currency=${r['Currency']}`); return false; }
      return true;
    })
    .map(r => ({
      date:        parseDate(r['Date']),
      amount:      parseAmount(r['Net']),
      payee_name:  r['Name'] || undefined,
      notes:       [r['Item Title'], r['Note']].filter(Boolean).join(' — ') || undefined,
      imported_id: r['Transaction ID'],
      cleared:     true,
    }));

  if (skipped.length) console.log(`  Skipped ${skipped.length} rows (wrong currency or non-completed)`);
  return txns;
}

async function main() {
  mkdirSync(DONE_DIR, { recursive: true });
  mkdirSync(DATA_DIR, { recursive: true });

  const csvFiles = readdirSync(INBOX_DIR).filter(f => /\.csv$/i.test(f));
  if (csvFiles.length === 0) {
    console.log('No CSV files in inbox — nothing to do.');
    return;
  }

  await api.init({ serverURL: SERVER_URL, password: PASSWORD, dataDir: DATA_DIR });
  await api.downloadBudget(SYNC_ID);

  const accounts = await api.getAccounts();
  const account  = accounts.find(a => a.name === ACCOUNT_NAME);
  if (!account) throw new Error(`Account "${ACCOUNT_NAME}" not found. Available: ${accounts.map(a => a.name).join(', ')}`);

  for (const file of csvFiles) {
    const filePath = join(INBOX_DIR, file);
    console.log(`Processing ${file}...`);

    const txns = toTransactions(readFileSync(filePath, 'utf8'));
    console.log(`  ${txns.length} transactions to import`);

    if (txns.length > 0) {
      const result = await api.importTransactions(account.id, txns, { defaultCleared: true });
      console.log(`  Added: ${result.added}, Updated: ${result.updated}`);
    }

    renameSync(filePath, join(DONE_DIR, file));
    console.log(`  Moved to done/`);
  }

  await api.shutdown();
}

main().catch(e => { console.error(e); process.exit(1); });
