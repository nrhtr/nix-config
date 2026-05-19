#!/usr/bin/env node
import * as api from '@actual-app/api';
import { parse } from 'csv-parse/sync';
import { readFileSync, readdirSync, mkdirSync, renameSync } from 'node:fs';
import { join } from 'node:path';

const SERVER_URL       = process.env.ACTUAL_SERVER_URL;
const SYNC_ID          = process.env.ACTUAL_SYNC_ID;
const PASSWORD         = readFileSync(process.env.ACTUAL_PASSWORD_FILE, 'utf8').trim();
const AUD_ACCOUNT_NAME = process.env.PAYPAL_AUD_ACCOUNT ?? process.env.ACCOUNT_NAME ?? 'PayPal AUD';
const USD_ACCOUNT_NAME = process.env.PAYPAL_USD_ACCOUNT; // optional; USD rows skipped if unset
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

// Returns { audTxns, usdTxns } — each a list ready for importTransactions.
function toTransactions(csvContent) {
  const rows = parse(csvContent, {
    columns: header => header.map(h => h.trim()),
    skip_empty_lines: true,
    bom: true,
    relax_column_count: true,
  });
  if (rows.length > 0) console.log('  CSV columns:', Object.keys(rows[0]).join(', '));

  const audTxns = [];
  const usdTxns = [];
  const skipped = [];

  for (const r of rows) {
    const id = r['Transaction ID'];

    if (r['Status'] !== 'Completed') {
      skipped.push(`${id} (status: ${r['Status']})`);
      continue;
    }
    // Bank funding — tracked on the bank account side, not here.
    if (r['Type'] === 'Transfer to PayPal account') {
      skipped.push(`${id} (bank transfer)`);
      continue;
    }

    const currency = r['Currency'];
    const notes = [r['Type'], r['Item Title']].filter(Boolean).join(' – ') || undefined;

    const txn = {
      date:        parseDate(r['Date']),
      amount:      parseAmount(r['Amount']),
      payee_name:  r['Name'] || undefined,
      notes,
      imported_id: id,
      cleared:     true,
    };

    if (currency === 'AUD') {
      audTxns.push(txn);
    } else if (currency === 'USD') {
      usdTxns.push(txn);
    } else {
      skipped.push(`${id} (currency: ${currency})`);
    }
  }

  if (skipped.length) console.log(`  Skipped ${skipped.length}:`, skipped.join(', '));
  return { audTxns, usdTxns };
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
  const findAccount = name => {
    const a = accounts.find(a => a.name === name);
    if (!a) throw new Error(`Account "${name}" not found. Available: ${accounts.map(a => a.name).join(', ')}`);
    return a;
  };

  const audAccount = findAccount(AUD_ACCOUNT_NAME);
  const usdAccount = USD_ACCOUNT_NAME ? findAccount(USD_ACCOUNT_NAME) : null;

  for (const file of csvFiles) {
    const filePath = join(INBOX_DIR, file);
    console.log(`Processing ${file}...`);

    const { audTxns, usdTxns } = toTransactions(readFileSync(filePath, 'utf8'));

    if (audTxns.length > 0) {
      const r = await api.importTransactions(audAccount.id, audTxns, { defaultCleared: true });
      console.log(`  AUD (${AUD_ACCOUNT_NAME}): added ${r.added}, updated ${r.updated}`);
    }

    if (usdTxns.length > 0) {
      if (usdAccount) {
        const r = await api.importTransactions(usdAccount.id, usdTxns, { defaultCleared: true });
        console.log(`  USD (${USD_ACCOUNT_NAME}): added ${r.added}, updated ${r.updated}`);
      } else {
        console.log(`  USD: ${usdTxns.length} transactions not imported (set PAYPAL_USD_ACCOUNT to enable)`);
      }
    }

    renameSync(filePath, join(DONE_DIR, file));
    console.log(`  Moved to done/`);
  }

  await api.shutdown();
}

main().catch(e => { console.error(e); process.exit(1); });
