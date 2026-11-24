#!/usr/bin/env node
// Carica dati/fotografie.json in users/{uid}/fotografie e dati/saldi_oggi.json nelle voci. Uso: node carica.js [--emulatore]
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

// Verifica ID e nomi attesi e aggiorna solo i saldi; tutto o niente.
async function caricaSaldiOggi(db, saldi) {
  const uid = await uidDaAllowlist(db);
  await db.runTransaction(async (tx) => {
    const refs = Object.keys(saldi).map((id) => db.doc(`users/${uid}/voci/${id}`));
    const docs = await tx.getAll(...refs);
    const scritture = [];
    docs.forEach((doc, i) => {
      const id = refs[i].id;
      const atteso = saldi[id];
      if (!doc.exists) throw new Error(`voce ${id} (${atteso.nome}) non trovata`);
      const voce = doc.data();
      if (voce.nome !== atteso.nome) throw new Error(`voce ${id}: nome "${voce.nome}" invece di "${atteso.nome}"`);
      if (!atteso.righe) {
        if (voce.tipo !== 'semplice') throw new Error(`voce ${id} (${atteso.nome}): attesa una voce semplice`);
        scritture.push([doc.ref, { saldoCentesimi: atteso.saldoCentesimi }]);
        return;
      }
      if (voce.tipo !== 'dettaglio') throw new Error(`voce ${id} (${atteso.nome}): attesa una voce con dettaglio`);
      const righe = voce.righe.map((r) => ({ ...r }));
      for (const [rid, riga] of Object.entries(atteso.righe)) {
        const r = righe.find((x) => x.id === rid);
        if (!r) throw new Error(`voce ${id} (${atteso.nome}): riga ${rid} (${riga.nome}) non trovata`);
        if (r.nome !== riga.nome) throw new Error(`voce ${id} (${atteso.nome}), riga ${rid}: nome "${r.nome}" invece di "${riga.nome}"`);
        r.saldoCentesimi = riga.saldoCentesimi;
      }
      scritture.push([doc.ref, { righe }]);
    });
    scritture.forEach(([ref, dati]) => tx.update(ref, dati));
  });
}

module.exports = { uidDaAllowlist, caricaFotografie, caricaSaldiOggi };

if (require.main === module) {
  if (process.argv.includes('--emulatore')) process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? 'demo-personal-finance' });
  const file = path.join(__dirname, '../../app/tool/import_storico/dati/fotografie.json');
  const saldi = path.join(__dirname, '../../app/tool/import_storico/dati/saldi_oggi.json');
  const db = admin.firestore();
  caricaFotografie(db, JSON.parse(fs.readFileSync(file, 'utf8')))
    .then(async (r) => {
      console.log(`creati: ${r.creati.length}, già presenti: ${r.giaPresenti.length}, errori: ${r.errori.length}`);
      r.errori.forEach((e) => console.error(e));
      if (r.errori.length) process.exit(1);
      await caricaSaldiOggi(db, JSON.parse(fs.readFileSync(saldi, 'utf8')));
      console.log('saldi di oggi aggiornati');
    })
    .catch((e) => { console.error(e.message); process.exit(1); });
}
