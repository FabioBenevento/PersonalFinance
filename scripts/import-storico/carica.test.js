const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const { caricaFotografie, uidDaAllowlist } = require('./carica');

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
admin.initializeApp({ projectId: 'demo-personal-finance' });
const db = admin.firestore();

const fotografia = (saldo) => ({
  schemaVersion: 2,
  voci: [{ id: 'v0', nome: 'Hype', gruppo: 'liquidita', saldoCentesimi: saldo }],
});
const file = { '2022-01': fotografia(100), '2026-10': fotografia(200), '2026-11': fotografia(300) };

async function svuota() {
  for (const c of ['allowlist', 'users/u1/fotografie']) {
    for (const d of (await db.collection(c).get()).docs) await d.ref.delete();
  }
}
beforeEach(async () => {
  await svuota();
  await db.doc('allowlist/u1').set({});
});

test('IMP-012 documento scritto uguale al file più salvataIl', async () => {
  const r = await caricaFotografie(db, { '2022-01': file['2022-01'] });
  assert.deepEqual(r, { creati: ['2022-01'], giaPresenti: [], errori: [] });
  const { salvataIl, ...resto } = (await db.doc('users/u1/fotografie/2022-01').get()).data();
  assert.deepEqual(resto, file['2022-01']);
  assert.ok(salvataIl.toDate() instanceof Date);
});

test('IMP-014 mese già presente resta identico', async () => {
  const esistente = { ...fotografia(999), revisione: 3 };
  await db.doc('users/u1/fotografie/2026-11').set(esistente);
  const r = await caricaFotografie(db, { '2026-10': file['2026-10'], '2026-11': file['2026-11'] });
  assert.deepEqual(r, { creati: ['2026-10'], giaPresenti: ['2026-11'], errori: [] });
  assert.deepEqual((await db.doc('users/u1/fotografie/2026-11').get()).data(), esistente);
});

test('IMP-015 secondo caricamento senza modifiche', async () => {
  await caricaFotografie(db, file);
  const prima = (await db.collection('users/u1/fotografie').get()).docs.map((d) => [d.id, d.data()]);
  const r = await caricaFotografie(db, file);
  assert.deepEqual(r, { creati: [], giaPresenti: Object.keys(file), errori: [] });
  const dopo = (await db.collection('users/u1/fotografie').get()).docs.map((d) => [d.id, d.data()]);
  assert.deepEqual(dopo, prima);
});

test('UID: si ferma se allowlist non ha esattamente un documento', async () => {
  await db.doc('allowlist/u2').set({});
  await assert.rejects(uidDaAllowlist(db), /allowlist/);
  await db.doc('allowlist/u1').delete();
  await db.doc('allowlist/u2').delete();
  await assert.rejects(uidDaAllowlist(db), /allowlist/);
});

test('allowlist con 0 o 2 documenti: il caricamento si ferma senza scrivere', async () => {
  await db.doc('allowlist/u2').set({});
  await assert.rejects(caricaFotografie(db, file), /allowlist/);
  await db.doc('allowlist/u1').delete();
  await db.doc('allowlist/u2').delete();
  await assert.rejects(caricaFotografie(db, file), /allowlist/);
  assert.equal((await db.collection('users/u1/fotografie').get()).size, 0);
});
