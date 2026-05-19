#!/usr/bin/env node
import * as api from '@actual-app/api';
import { parse } from 'csv-parse/sync';
import { readFileSync, readdirSync, mkdirSync, renameSync } from 'node:fs';
import { join } from 'node:path';

const SERVER_URL       = process.env.ACTUAL_SERVER_URL;
const SYNC_ID          = process.env.ACTUAL_SYNC_ID;
const PASSWORD         = readFileSync(process.env.ACTUAL_PASSWORD_FILE, 'utf8').trim();
const ACCOUNT_NAME     = process.env.ACCOUNT_NAME ?? 'Paypal';
const INBOX_DIR        = process.env.INBOX_DIR;
const DONE_DIR         = join(INBOX_DIR, '..', 'done');
const DATA_DIR         = join(INBOX_DIR, '..', 'actual-data');

// PayPal CSV amounts: "1,234.56" or "-1,234.56" → integer cents
function parseAmount(str) {
  return Math.round(parseFloat(str.replace(/,/g, '')) * 100);
}

// PayPal Australia exports DD/MM/YYYY; set DATE_FORMAT=MDY for US format
function parseDate(str) {
  const [a, b, y] = str.split('/');
  const [d, m] = (process.env.DATE_FORMAT ?? 'DMY') === 'MDY' ? [b, a] : [a, b];
  return `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`;
}

// Returns AUD transactions ready for importTransactions.
//
// Currency conversion events produce two rows at the same timestamp: an AUD
// debit and a USD payment that carries the real payee name. We index payees
// from USD payment rows by timestamp so they can be applied to the matching
// AUD conversion row — giving the AUD account correct amounts AND payees.
function toTransactions(csvContent) {
  const rows = parse(csvContent, {
    columns: header => header.map(h => h.trim()),
    skip_empty_lines: true,
    bom: true,
    relax_column_count: true,
  });
  if (rows.length > 0) console.log('  CSV columns:', Object.keys(rows[0]).join(', '));

  const skipped = [];

  const active = rows.filter(r => {
    const id = r['Transaction ID'];
    if (r['Status'] !== 'Completed') {
      skipped.push(`${id} (status: ${r['Status']})`);
      return false;
    }
    // Bank funding — tracked on the bank account side, not here.
    if (r['Type'] === 'Transfer to PayPal account') {
      skipped.push(`${id} (bank transfer)`);
      return false;
    }
    return true;
  });

  // Index payees from USD payment rows by timestamp.
  // "General Currency Conversion" rows have no payee; the real merchant name
  // lives on the accompanying USD payment row at the same timestamp.
  const payeeByTimestamp = new Map();
  for (const r of active) {
    if (r['Currency'] === 'USD' && r['Name'] && r['Type'] !== 'General Currency Conversion') {
      payeeByTimestamp.set(`${r['Date']}|${r['Time']}`, r['Name']);
    }
  }

  const audTxns = active
    .filter(r => r['Currency'] === 'AUD')
    .map(r => ({
      date:        parseDate(r['Date']),
      amount:      parseAmount(r['Amount']),
      payee_name:  r['Name'] || payeeByTimestamp.get(`${r['Date']}|${r['Time']}`) || undefined,
      notes:       [r['Type'], r['Item Title'], r['Transaction ID']].filter(Boolean).join(' – ') || undefined,
      imported_id: r['Transaction ID'],
      cleared:     true,
    }));

  if (skipped.length) console.log(`  Skipped ${skipped.length}:`, skipped.join(', '));
  return audTxns;
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
  const account = accounts.find(a => a.name === ACCOUNT_NAME);
  if (!account) throw new Error(`Account "${ACCOUNT_NAME}" not found. Available: ${accounts.map(a => a.name).join(', ')}`);

  for (const file of csvFiles) {
    const filePath = join(INBOX_DIR, file);
    console.log(`Processing ${file}...`);

    const txns = toTransactions(readFileSync(filePath, 'utf8'));
    console.log(`  ${txns.length} AUD transactions to import`);

    if (txns.length > 0) {
      const r = await api.importTransactions(account.id, txns, { defaultCleared: true });
      console.log(`  Added: ${r.added}, Updated: ${r.updated}`);
    }

    renameSync(filePath, join(DONE_DIR, file));
    console.log(`  Moved to done/`);
  }

  await api.shutdown();
}

main().catch(e => { console.error(e); process.exit(1); });
