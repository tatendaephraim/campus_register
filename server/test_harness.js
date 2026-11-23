// Runs Code.gs under Node with stubs for the Google services.
// Usage: node server/test_harness.js <log.jsonl holding three chained events>
const assert = require('assert');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const rows = [];
const sheet = {
  getLastRow: () => rows.length,
  getRange: (row, col, n) => ({
    setNumberFormat() {},
    setValues: (v) => v.forEach((r, i) => { rows[row - 1 + i] = r; }),
    getValues: () => rows.slice(row - 1, row - 1 + n),
  }),
};
let created = false;
const context = {
  console,
  LockService: { getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) },
  PropertiesService: {
    getScriptProperties: () => ({ getProperty: () => 'secret' }),
  },
  SpreadsheetApp: {
    getActiveSpreadsheet: () => ({
      getSheetByName: () => (created ? sheet : null),
      insertSheet: () => { created = true; return sheet; },
    }),
  },
  Utilities: {
    DigestAlgorithm: { SHA_256: 0 },
    Charset: { UTF_8: 0 },
    // Apps Script returns signed bytes.
    computeDigest: (_, text) => [
      ...new Int8Array(
        crypto.createHash('sha256').update(text, 'utf8').digest()),
    ],
  },
  ContentService: {
    MimeType: { JSON: 0 },
    createTextOutput: (t) => ({ setMimeType: () => JSON.parse(t) }),
  },
};
vm.createContext(context);
vm.runInContext(
  fs.readFileSync(path.join(__dirname, 'Code.gs'), 'utf8'), context);

const post = (event, token = 'secret') => context.doPost({
  postData: { contents: JSON.stringify({ token, event }) },
});
const [a, b, c] = fs.readFileSync(process.argv[2], 'utf8')
  .trim().split('\n').map((line) => JSON.parse(line));

assert.strictEqual(post(a, 'wrong').error, 'unauthorised');
assert.strictEqual(post(b).error, 'chain gap', 'first entry withheld');
assert.strictEqual(post(a).ok, true);
assert.strictEqual(post(a).duplicate, true, 'retry is idempotent');
assert.strictEqual(
  post({ ...b, decision: 'mockedPosition' }).error, 'hash mismatch');
assert.strictEqual(post(c).error, 'chain gap', 'middle entry withheld');
assert.strictEqual(post(b).ok, true);
assert.strictEqual(post(c).ok, true);

// An entry rewritten with a freshly computed, self-consistent hash.
const forged = { ...b, name: 'Someone Else' };
const fields = vm.runInContext('FIELDS', context);
forged.hash = crypto.createHash('sha256')
  .update(JSON.stringify(fields.map((f) => forged[f]))).digest('hex');
assert.strictEqual(post(forged).error, 'history rewritten');

assert.strictEqual(post({ ...a, name: 5 }).error, 'bad field name');
assert.strictEqual(rows.length, 4, 'header plus three entries');
