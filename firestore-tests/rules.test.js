const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
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
    await setDoc(doc(c.firestore(), 'users/ok/voci/v1'), { nome: 'x' });
    await setDoc(doc(c.firestore(), 'users/altro/voci/v1'), { nome: 'y' });
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
