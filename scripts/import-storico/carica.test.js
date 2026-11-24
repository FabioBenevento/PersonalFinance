const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const { caricaFotografie, caricaSaldiOggi, uidDaAllowlist } = require('./carica');

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
admin.initializeApp({ projectId: 'demo-personal-finance' });
const db = admin.firestore();

const fotografia = (saldo) => ({
  schemaVersion: 2,
  voci: [{ id: 'v0', nome: 'Hype', gruppo: 'liquidita', saldoCentesimi: saldo }],
});
const file = { '2022-01': fotografia(100), '2026-10': fotografia(200), '2026-11': fotografia(300) };

async function svuota() {
  for (const c of ['allowlist', 'users/u1/fotografie', 'users/u1/voci']) {
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

const vociIniziali = () => ({
  v0: { nome: 'Contanti', gruppo: 'liquidita', tipo: 'semplice', ordine: 1, saldoCentesimi: 0 },
  v1: {
    nome: 'MatchBetting', gruppo: 'investimenti', categoria: 'altro', tipo: 'dettaglio', ordine: 2,
    righe: [
      { id: 'r1', nome: 'Bwin', saldoCentesimi: 0 },
      { id: 'r2', nome: 'Bet365', saldoCentesimi: 0 },
    ],
  },
});
const saldiOggi = {
  v0: { nome: 'Contanti', saldoCentesimi: 50000 },
  v1: {
    nome: 'MatchBetting',
    righe: { r1: { nome: 'Bwin', saldoCentesimi: 4000 }, r2: { nome: 'Bet365', saldoCentesimi: 3207 } },
  },
};
const leggiVoci = async () => Object.fromEntries((await db.collection('users/u1/voci').get()).docs.map((d) => [d.id, d.data()]));
async function scriviVoci(voci) {
  for (const [id, d] of Object.entries(voci)) await db.doc(`users/u1/voci/${id}`).set(d);
}

test('IMP-016 saldi di oggi aggiornati, il resto delle voci invariato', async () => {
  await scriviVoci(vociIniziali());
  await caricaSaldiOggi(db, saldiOggi);
  const attese = vociIniziali();
  attese.v0.saldoCentesimi = 50000;
  attese.v1.righe[0].saldoCentesimi = 4000;
  attese.v1.righe[1].saldoCentesimi = 3207;
  assert.deepEqual(await leggiVoci(), attese);
});

test('IMP-017 riga rinominata: si ferma indicando voce e riga, nessuna scrittura', async () => {
  const voci = vociIniziali();
  voci.v1.righe[0].nome = 'Bwin2';
  await scriviVoci(voci);
  await assert.rejects(caricaSaldiOggi(db, saldiOggi), /MatchBetting.*Bwin|v1.*r1/);
  assert.deepEqual(await leggiVoci(), voci);
});

test('IMP-017 voce mancante: nessuna scrittura', async () => {
  const voci = vociIniziali();
  delete voci.v1;
  await scriviVoci(voci);
  await assert.rejects(caricaSaldiOggi(db, saldiOggi), /v1/);
  assert.deepEqual(await leggiVoci(), voci);
});
