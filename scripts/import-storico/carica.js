#!/usr/bin/env node
// Carica dati/fotografie.json in users/{uid}/fotografie. Uso: node carica.js [--emulatore]
const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');

async function uidDaAllowlist(db) {
  const docs = (await db.collection('allowlist').get()).docs;
  if (docs.length !== 1) throw new Error(`allowlist deve avere esattamente un documento, trovati ${docs.length}`);
  return docs[0].id;
}

async function caricaFotografie(db, fotografie) {
  const uid = await uidDaAllowlist(db);
  const esito = { creati: [], giaPresenti: [], errori: [] };
  for (const [mese, documento] of Object.entries(fotografie)) {
    try {
      await db.doc(`users/${uid}/fotografie/${mese}`).create({
        ...documento,
        salvataIl: admin.firestore.FieldValue.serverTimestamp(),
      });
      esito.creati.push(mese);
    } catch (e) {
      if (e.code === 6) esito.giaPresenti.push(mese); // ALREADY_EXISTS
      else esito.errori.push(`${mese}: ${e.message}`);
    }
  }
  return esito;
}

module.exports = { uidDaAllowlist, caricaFotografie };

if (require.main === module) {
  if (process.argv.includes('--emulatore')) process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? 'demo-personal-finance' });
  const file = path.join(__dirname, '../../app/tool/import_storico/dati/fotografie.json');
  caricaFotografie(admin.firestore(), JSON.parse(fs.readFileSync(file, 'utf8')))
    .then((r) => {
      console.log(`creati: ${r.creati.length}, già presenti: ${r.giaPresenti.length}, errori: ${r.errori.length}`);
      r.errori.forEach((e) => console.error(e));
      process.exit(r.errori.length ? 1 : 0);
    })
    .catch((e) => { console.error(e.message); process.exit(1); });
}
