const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const {
  initializeTestEnvironment, assertFails, assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, deleteDoc } = require('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'personalfinance-rules-test',
    firestore: { rules: fs.readFileSync(`${__dirname}/../firestore.rules`, 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'allowlist/ok'), {});
    await setDoc(doc(c.firestore(), 'allowlist/altro'), {});
    await setDoc(doc(c.firestore(), 'users/ok/voci/v1'), { nome: 'x' });
    await setDoc(doc(c.firestore(), 'users/altro/voci/v1'), { nome: 'y' });
    for (const uid of ['ok', 'altro', 'intruso']) {
      await setDoc(doc(c.firestore(), `users/${uid}/fotografie/2026-10`), { revisione: 1, voci: [] });
    }
  });
});

const db = (uid) => env.authenticatedContext(uid).firestore();

test('ACC-005 account non autorizzato respinto, ma può leggere la propria allowlist', async () => {
  const d = db('intruso');
  await assertFails(getDoc(doc(d, 'users/intruso')));
  await assertFails(setDoc(doc(d, 'users/intruso'), { inizializzato: true }));
  await assertFails(getDoc(doc(d, 'users/intruso/voci/v1')));
  await assertFails(setDoc(doc(d, 'users/intruso/voci/v1'), { nome: 'x' }));
  await assertSucceeds(getDoc(doc(d, 'allowlist/intruso')));
  await assertFails(getDoc(doc(d, 'allowlist/ok')));
});

test('ACC-006 richieste non autenticate respinte', async () => {
  const d = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(d, 'allowlist/ok')));
  await assertFails(getDoc(doc(d, 'users/ok/voci/v1')));
  await assertFails(setDoc(doc(d, 'users/ok/voci/v1'), { nome: 'x' }));
  await assertFails(setDoc(doc(d, 'allowlist/ok'), {}));
});

test('ACC-007 allowlist non modificabile dall\'app', async () => {
  for (const uid of ['ok', 'intruso']) {
    const d = db(uid);
    await assertFails(setDoc(doc(d, `allowlist/${uid}`), {}));
    await assertFails(deleteDoc(doc(d, `allowlist/${uid}`)));
  }
  await assertFails(setDoc(doc(db('ok'), 'allowlist/ok'), { a: 1 }));
});

test('ACC-008 utente autorizzato solo sui propri dati', async () => {
  const d = db('ok');
  await assertFails(getDoc(doc(d, 'users/altro/voci/v1')));
  await assertFails(setDoc(doc(d, 'users/altro/voci/v1'), { nome: 'z' }));
  await assertSucceeds(getDoc(doc(d, 'users/ok/voci/v1')));
  await assertSucceeds(setDoc(doc(d, 'users/ok/voci/v2'), { nome: 'n' }));
  await assertSucceeds(setDoc(doc(d, 'users/ok'), { inizializzato: true }));
});

const fotografia = { revisione: 1, voci: [] };
const sostituzione = { revisione: 2, voci: [{ id: 'contanti', saldoCentesimi: 1200 }] };

test('FOT-019 proprietario autorizzato legge, crea e sostituisce fotografie', async () => {
  const d = db('ok');
  await assertSucceeds(getDoc(doc(d, 'users/ok/fotografie/2026-10')));
  const nuova = doc(d, 'users/ok/fotografie/2026-11');
  await assertSucceeds(setDoc(nuova, fotografia));
  await assertSucceeds(setDoc(nuova, sostituzione));
  const salvata = await assertSucceeds(getDoc(nuova));
  assert.deepEqual(salvata.data(), sostituzione);
});

for (const [caso, context, uid] of [
  ['altro proprietario', () => db('ok'), 'altro'],
  ['non autenticato', () => env.unauthenticatedContext().firestore(), 'ok'],
  ['fuori allowlist', () => db('intruso'), 'intruso'],
]) {
  test(`FOT-019 ${caso}: lettura, creazione e sostituzione negate`, async () => {
    const d = context();
    const esistente = doc(d, `users/${uid}/fotografie/2026-10`);
    await assertFails(getDoc(esistente));
    await assertFails(setDoc(doc(d, `users/${uid}/fotografie/2026-11`), fotografia));
    await assertFails(setDoc(esistente, sostituzione));
  });
}

const broker = ['brokerStato/snaptrade', 'brokerRilevazioni/r1', 'brokerRilevazioni/r1/conti/c1', 'brokerRilevazioni/r1/posizioni/p1'];

test('BRO-007 accesso ai dati broker solo al proprietario autorizzato', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    for (const uid of ['ok', 'intruso']) {
      for (const p of [...broker, 'brokerAssociazioni/c1', 'brokerApplicazioni/o1']) {
        await setDoc(doc(c.firestore(), `users/${uid}/${p}`), { x: 1 });
      }
    }
  });
  for (const p of [...broker, 'brokerAssociazioni/c1', 'brokerApplicazioni/o1']) {
    await assertSucceeds(getDoc(doc(db('ok'), `users/ok/${p}`)));
    await assertFails(getDoc(doc(db('ok'), `users/intruso/${p}`)));
    await assertFails(getDoc(doc(db('intruso'), `users/intruso/${p}`)));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), `users/ok/${p}`)));
  }
});

test('BRO-022 rilevazioni e puntatore non scrivibili dal client, voci e fotografie sì', async () => {
  await env.withSecurityRulesDisabled(async (c) => {
    for (const p of broker) await setDoc(doc(c.firestore(), `users/ok/${p}`), { x: 1 });
  });
  const d = db('ok');
  for (const p of broker) {
    await assertFails(setDoc(doc(d, `users/ok/${p}`), { x: 2 }));
    await assertFails(setDoc(doc(d, `users/ok/${p}-nuovo`), { x: 2 }));
    await assertFails(deleteDoc(doc(d, `users/ok/${p}`)));
  }
  await assertSucceeds(setDoc(doc(d, 'users/ok/voci/v1'), { nome: 'n', saldoCentesimi: 5 }));
  await assertSucceeds(setDoc(doc(d, 'users/ok/fotografie/2026-11'), fotografia));
});

test('BRO-022 associazioni e ricevute: struttura valida, ricevute immutabili', async () => {
  const d = db('ok');
  const a = doc(d, 'users/ok/brokerAssociazioni/c1');
  await assertSucceeds(setDoc(a, { revisione: 1, liquidita: 'v1', investimenti: 'v2' }));
  await assertSucceeds(setDoc(a, { revisione: 2 }));
  await assertFails(setDoc(a, { revisione: 0 }));
  await assertFails(setDoc(a, { revisione: 'x' }));
  await assertFails(setDoc(a, { revisione: 3, liquidita: 5 }));
  await assertFails(setDoc(a, { revisione: 3, extra: 1 }));
  await assertFails(setDoc(doc(db('ok'), 'users/altro/brokerAssociazioni/c1'), { revisione: 1 }));
  const r = doc(d, 'users/ok/brokerApplicazioni/o1');
  const ricevuta = { rilevazione: 'r1', applicataAt: 'ts', conti: { c1: 100 } };
  await assertFails(setDoc(doc(d, 'users/ok/brokerApplicazioni/o2'), { rilevazione: 'r1' }));
  await assertFails(setDoc(doc(d, 'users/ok/brokerApplicazioni/o2'), { ...ricevuta, token: 's' }));
  await assertSucceeds(setDoc(r, ricevuta));
  await assertFails(setDoc(r, ricevuta));
  await assertFails(deleteDoc(r));
});
