const { test, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const admin = require('firebase-admin');
const { main } = require('./cli');
const { ErroreSorgente } = require('./sorgente');

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
delete process.env.GCLOUD_PROJECT;
const base = 'users/u1';
const conti = [{ id: 'c1', nome: 'Conto', liquidita: [], posizioni: [] }];
let dir;

function config(firebase = { projectId: 'demo-personal-finance', uid: 'u1' }) {
  const file = path.join(dir, 'broker.json');
  fs.writeFileSync(file, JSON.stringify({
    adapter: 'snaptrade', enabled: true, accountIds: ['a'],
    snaptrade: { clientId: 'x', consumerKey: 'y' }, firebase,
  }), { mode: 0o600 });
  return file;
}
const creaDb = (projectId) => admin.initializeApp({ projectId }, `t${Math.random()}`).firestore();
async function esegui(file, creaSorgente, creaDbUsato = creaDb) {
  process.exitCode = 0;
  await main(['--config', file], { creaSorgente, creaDb: creaDbUsato });
  const code = process.exitCode;
  process.exitCode = 0;
  return code;
}
const verifica = () => admin.initializeApp({ projectId: 'demo-personal-finance' }, `v${Math.random()}`).firestore();
const attiva = async () => (await verifica().doc(`${base}/brokerStato/snaptrade`).get()).data()?.attivaId;

beforeEach(async () => {
  dir = fs.mkdtempSync(path.join(os.tmpdir(), 'broker-cli-'));
  const v = verifica();
  for (const d of (await v.collection('allowlist').get()).docs) await d.ref.delete();
  await v.doc(`${base}/brokerStato/snaptrade`).delete();
  await v.doc('allowlist/u1').set({});
});

test('BRO-006 BRO-011 il comando pubblica e attiva la rilevazione letta dall adattatore di test', async () => {
  assert.equal(await esegui(config(), () => ({ leggi: async () => conti })), 0);
  const id = await attiva();
  assert.ok(id);
  const r = await verifica().doc(`${base}/brokerRilevazioni/${id}`).get();
  assert.deepEqual(r.data().manifest, { conti: 1, posizioni: 0 });
});

test('BRO-012 un errore di lettura conserva la rilevazione attiva precedente', async () => {
  await esegui(config(), () => ({ leggi: async () => conti }));
  const prima = await attiva();
  const code = await esegui(config(), () => ({ leggi: async () => { throw new ErroreSorgente('rete'); } }));
  assert.equal(code, 1);
  assert.equal(await attiva(), prima);
});

test('BRO-024 progetto o uid diversi dalla configurazione sono rifiutati senza attivare nulla', async () => {
  const altroProgetto = () => admin.initializeApp({ projectId: 'altro-progetto' }, `a${Math.random()}`).firestore();
  assert.equal(await esegui(config(), () => ({ leggi: async () => conti }), altroProgetto), 1);
  assert.equal(await esegui(config({ projectId: 'demo-personal-finance', uid: 'u2' }), () => ({ leggi: async () => conti })), 1);
  assert.equal(await attiva(), undefined);
});
