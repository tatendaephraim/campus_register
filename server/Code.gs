/**
 * Campus Register collection endpoint (Google Apps Script, bound to a Sheet).
 *
 * It recomputes every hash and only accepts the next entry of a device's chain,
 * so removing or editing an entry on the phone after upload is detectable.
 *
 * Setup: Project settings > Script properties > SYNC_TOKEN = <random string>,
 * then Deploy > New deployment > Web app, execute as you, access "Anyone".
 */
var FIELDS = [
  'deviceId', 'seq', 'studentId', 'name', 'type', 'decision', 'timestamp',
  'distanceM', 'accuracyM', 'locationMs', 'biometricMs', 'prevHash',
];
var HEADER = FIELDS.concat(['hash', 'receivedAt']);
var GENESIS = new Array(65).join('0');

function doPost(e) {
  var lock = LockService.getScriptLock();
  try {
    lock.waitLock(10000);
  } catch (err) {
    return reply({ ok: false, error: 'busy' });
  }
  try {
    return reply(handle(e));
  } catch (err) {
    console.error(err);
    return reply({ ok: false, error: 'server error' });
  } finally {
    lock.releaseLock();
  }
}

function handle(e) {
  var token = PropertiesService.getScriptProperties().getProperty('SYNC_TOKEN');
  var body;
  try {
    body = JSON.parse(e.postData.contents);
  } catch (err) {
    return { ok: false, error: 'bad request' };
  }
  if (!token || !body || body.token !== token) {
    return { ok: false, error: 'unauthorised' };
  }

  var event = body.event || {};
  var keys = FIELDS.concat(['hash']);
  for (var i = 0; i < keys.length; i++) {
    var v = event[keys[i]];
    if (typeof v !== 'string' || v.length > 200) {
      return { ok: false, error: 'bad field ' + keys[i] };
    }
  }
  if (!/^\d{1,9}$/.test(event.seq)) return { ok: false, error: 'bad seq' };

  var values = FIELDS.map(function (f) { return event[f]; });
  if (sha256(JSON.stringify(values)) !== event.hash) {
    return { ok: false, error: 'hash mismatch' };
  }

  var sheet = getSheet();
  var chain = findChain(sheet, event.deviceId);
  var seq = Number(event.seq);
  if (seq < chain.length) {
    // A retry after a lost reply is normal; a different entry is a rewrite.
    return chain[seq] === event.hash
      ? { ok: true, duplicate: true }
      : { ok: false, error: 'history rewritten' };
  }
  var expectedPrev = chain.length ? chain[chain.length - 1] : GENESIS;
  if (seq !== chain.length || event.prevHash !== expectedPrev) {
    return { ok: false, error: 'chain gap' };
  }

  var row = values.concat([event.hash, new Date().toISOString()]);
  var range = sheet.getRange(sheet.getLastRow() + 1, 1, 1, row.length);
  range.setNumberFormat('@'); // Plain text: no formulas, no lost zeros.
  range.setValues([row]);
  return { ok: true };
}

/** Accepted hashes for one device, in order. */
function findChain(sheet, deviceId) {
  var last = sheet.getLastRow();
  if (last < 2) return [];
  var rows = sheet.getRange(2, 1, last - 1, HEADER.length).getValues();
  var hashColumn = HEADER.indexOf('hash');
  return rows
    .filter(function (r) { return r[0] === deviceId; })
    .map(function (r) { return r[hashColumn]; });
}

function getSheet() {
  var book = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = book.getSheetByName('Attendance');
  if (!sheet) {
    sheet = book.insertSheet('Attendance');
    sheet.getRange(1, 1, 1, HEADER.length).setValues([HEADER]);
  }
  return sheet;
}

function sha256(text) {
  return Utilities
    .computeDigest(
      Utilities.DigestAlgorithm.SHA_256, text, Utilities.Charset.UTF_8)
    .map(function (b) { return ('0' + (b & 0xff).toString(16)).slice(-2); })
    .join('');
}

function reply(body) {
  return ContentService.createTextOutput(JSON.stringify(body))
    .setMimeType(ContentService.MimeType.JSON);
}
