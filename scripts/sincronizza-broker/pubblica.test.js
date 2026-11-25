const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const { pubblicaRilevazione, registraTentativoFallito } = require('./pubblica');
const { ErroreSorgente } = require('./sorgente');

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
admin.initializeApp({ projectId: 'demo-personal-finance' });
const db = admin.firestore();
const dest = { projectId: 'demo-personal-finance', uid: 'u1' };
const base = 'users/u1';
let n = 0;
const clock = () => new Date(Date.UTC(2026, 10, 25, 12, 0, n++));
const conto = (id, posizioni) => ({ id, nome: 'Conto', liquidita: [{ valuta: 'EUR', importo: '10' }], posizioni });
const pos = { id: 'p', simbolo: 'X', quantita: '1' };
const rilevazione = (conti) => ({ schemaVersion: 1, lettaIl: '2026-11-25T12:00:00.000Z', conti });

async function svuota() {
  for (const c of ['allowlist', `${base}/brokerStato`, `${base}/fotografie`, `${base}/voci`]) {
    for (const d of (await db.collection(c).get()).docs) await d.ref.delete();
  }
  for (const r of (await db.collection(`${base}/brokerRilevazioni`).get()).docs) {
    for (const s of ['conti', 'posizioni']) for (const d of (await r.ref.collection(s).get()).docs) await d.ref.delete();
    await r.ref.delete();
  }
}
beforeEach(async () => {
  await svuota();
  await db.doc('allowlist/u1').set({});
  await db.doc(`${base}/voci/v0`).set({ nome: 'Contanti', saldoCentesimi: 5 });
  await db.doc(`${base}/fotografie/2026-10`).set({ schemaVersion: 2, voci: [] });
});
const stato = async () => (await db.doc(`${base}/brokerStato/snaptrade`).get()).data();
const intatti = async () => {
  assert.equal((await db.doc(`${base}/voci/v0`).get()).data().saldoCentesimi, 5);
  assert.equal((await db.collection(`${base}/fotografie`).get()).size, 1);
};

test('BRO-021 pubblicazione completa attiva la generazione con conti e posizioni separati', async () => {
  const { id } = await pubblicaRilevazione(db, dest, rilevazione([conto('c1', [pos, pos])]), { clock });
  const s = await stato();
  assert.equal(s.attivaId, id);
  assert.equal(s.ultimoTentativo.esito, 'ok');
  const r = (await db.doc(`${base}/brokerRilevazioni/${id}`).get()).data();
  assert.deepEqual(r.manifest, { conti: 1, posizioni: 2 });
  assert.equal(r.completa, true);
  assert.equal((await db.collection(`${base}/brokerRilevazioni/${id}/posizioni`).get()).size, 2);
  await intatti();
});

test('BRO-012 elenco vuoto valido e posizioni chiuse sostituiscono la rilevazione senza toccare fotografie', async () => {
  await pubblicaRilevazione(db, dest, rilevazione([conto('c1', [pos])]), { clock });
  const { id } = await pubblicaRilevazione(db, dest, rilevazione([conto('c1', [])]), { clock });
  assert.equal((await stato()).attivaId, id);
  assert.equal((await db.collection(`${base}/brokerRilevazioni/${id}/posizioni`).get()).size, 0);
  const vuota = await pubblicaRilevazione(db, dest, rilevazione([]), { clock });
  assert.equal((await stato()).attivaId, vuota.id);
  await intatti();
});

test('BRO-011 errore intermedio conserva il puntatore e registra il tentativo a parte', async () => {
  const { id } = await pubblicaRilevazione(db, dest, rilevazione([conto('c1', [pos])]), { clock });
  const cattiva = rilevazione([conto('c1', [pos]), conto('', [])]);
  await assert.rejects(pubblicaRilevazione(db, dest, cattiva, { clock }), /dati-non-validi/);
  const s = await stato();
  assert.equal(s.attivaId, id);
  assert.equal(s.ultimoTentativo.esito, 'errore');
  assert.equal(s.ultimoTentativo.codice, 'dati-non-validi');
  await intatti();
});

test('BRO-006 il tentativo fallito salva solo il codice, mai il testo dell\'errore', async () => {
  await registraTentativoFallito(db, dest, new Error('chiave SEGRETO-SENTINELLA'), { clock });
  await registraTentativoFallito(db, dest, new ErroreSorgente('limite-fornitore'), { clock });
  const s = await stato();
  assert.equal(s.ultimoTentativo.codice, 'limite-fornitore');
  await registraTentativoFallito(db, dest, new Error('chiave SEGRETO-SENTINELLA'), { clock });
  assert.ok(!JSON.stringify(await stato()).includes('SEGRETO'));
});

test('BRO-021 attivazione concorrente: la generazione più lenta non sostituisce quella già attiva', async () => {
  const lenta = pubblicaRilevazione(db, dest, rilevazione([conto('lenta', [])]), {
    clock,
    dopoCaricamento: async () => { veloce = await pubblicaRilevazione(db, dest, rilevazione([conto('veloce', [])]), { clock }); },
  });
  let veloce;
  await assert.rejects(lenta, /concorrenza/);
  assert.equal((await stato()).attivaId, veloce.id);
  assert.equal((await stato()).ultimoTentativo.codice, 'concorrenza');
});

test('BRO-024 destinazione errata: nessuna scrittura', async () => {
  for (const d of [{ ...dest, uid: 'u2' }, { ...dest, projectId: 'altro-progetto' }]) {
    await assert.rejects(pubblicaRilevazione(db, d, rilevazione([]), { clock }), /destinazione/);
  }
  await db.doc('allowlist/u2').set({});
  await assert.rejects(pubblicaRilevazione(db, dest, rilevazione([]), { clock }), /destinazione/);
  assert.equal((await db.collection(`${base}/brokerRilevazioni`).get()).size, 0);
  assert.equal((await db.doc(`${base}/brokerStato/snaptrade`).get()).exists, false);
});

test('BRO-021 dopo l\'attivazione restano solo la generazione attiva e il suo contenuto', async () => {
  await pubblicaRilevazione(db, dest, rilevazione([conto('c1', [pos])]), { clock });
  const cattiva = rilevazione([conto('c1', [pos]), conto('', [])]);
  await assert.rejects(pubblicaRilevazione(db, dest, cattiva, { clock }), /dati-non-validi/);
  const { id } = await pubblicaRilevazione(db, dest, rilevazione([conto('c2', [pos])]), { clock });
  const ids = (await db.collection(`${base}/brokerRilevazioni`).listDocuments()).map((d) => d.id);
  assert.deepEqual(ids, [id]);
  assert.equal((await db.collection(`${base}/brokerRilevazioni/${id}/posizioni`).get()).size, 1);
});
