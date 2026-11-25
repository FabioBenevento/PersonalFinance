const crypto = require('node:crypto');
const admin = require('firebase-admin');
const { ErroreSorgente } = require('./sorgente');

const MAX_BATCH = 400;

async function verificaDestinazione(db, { projectId, uid }) {
  const allowlist = (await db.collection('allowlist').get()).docs;
  if (db.projectId !== projectId || allowlist.length !== 1 || allowlist[0].id !== uid) {
    throw new ErroreSorgente('destinazione-non-valida');
  }
}

// Only the error code is stored: messages may carry provider data or credentials.
async function registraTentativoFallito(db, { uid }, error, { clock = () => new Date() } = {}) {
  const codice = error instanceof ErroreSorgente ? error.codice : 'errore-interno';
  await db.doc(`users/${uid}/brokerStato/snaptrade`).set(
    { ultimoTentativo: { esito: 'errore', codice, il: clock().toISOString() } }, { merge: true });
}

// Loads an immutable generation, checks its manifest, then activates it only if the
// pointer read at the start is unchanged. Any failure leaves the active pointer alone.
async function pubblicaRilevazione(db, destinazione, rilevazione, { clock = () => new Date(), dopoCaricamento } = {}) {
  await verificaDestinazione(db, destinazione);
  const base = `users/${destinazione.uid}`;
  const statoRef = db.doc(`${base}/brokerStato/snaptrade`);
  try {
    const attivaIniziale = (await statoRef.get()).data()?.attivaId ?? null;
    const id = `${clock().toISOString().replace(/\D/g, '')}-${crypto.randomUUID()}`;
    const rilRef = db.doc(`${base}/brokerRilevazioni/${id}`);
    const { conti, ...testata } = rilevazione;
    const manifest = { conti: 0, posizioni: 0 };
    await rilRef.create({ ...testata, completa: false });

    let batch = db.batch();
    let operazioni = 0;
    const scrivi = async (ref, dati) => {
      batch.create(ref, dati);
      if (++operazioni === MAX_BATCH) { await batch.commit(); batch = db.batch(); operazioni = 0; }
    };
    for (const { posizioni = [], ...conto } of conti) {
      if (typeof conto.id !== 'string' || !conto.id || conto.id.includes('/')) throw new ErroreSorgente('dati-non-validi');
      await scrivi(rilRef.collection('conti').doc(conto.id), conto);
      for (const [i, p] of posizioni.entries()) {
        await scrivi(rilRef.collection('posizioni').doc(`${conto.id}_${i}`), { ...p, contoId: conto.id });
      }
      manifest.conti++;
      manifest.posizioni += posizioni.length;
    }
    if (operazioni) await batch.commit();

    const [nConti, nPosizioni] = await Promise.all(['conti', 'posizioni']
      .map(async (c) => (await rilRef.collection(c).count().get()).data().count));
    if (nConti !== manifest.conti || nPosizioni !== manifest.posizioni) throw new ErroreSorgente('dati-non-validi');
    await rilRef.update({ manifest, completa: true });
    if (dopoCaricamento) await dopoCaricamento();

    await db.runTransaction(async (tx) => {
      const attuale = (await tx.get(statoRef)).data()?.attivaId ?? null;
      if (attuale !== attivaIniziale) throw new ErroreSorgente('concorrenza');
      tx.set(statoRef, {
        attivaId: id, attivatoIl: admin.firestore.FieldValue.serverTimestamp(),
        ultimoTentativo: { esito: 'ok', codice: null, il: clock().toISOString() },
      }, { merge: true });
    });
    return { id };
  } catch (error) {
    await registraTentativoFallito(db, destinazione, error, { clock });
    throw error;
  }
}
module.exports = { pubblicaRilevazione, registraTentativoFallito };
