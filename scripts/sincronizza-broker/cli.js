const admin = require('firebase-admin');
const { leggiConfigurazione } = require('./configurazione');
const { creaSorgentePersonal } = require('./snaptrade');
const { leggiRilevazione, ErroreSorgente } = require('./sorgente');
const { pubblicaRilevazione, registraTentativoFallito } = require('./pubblica');

// Credentials come from Application Default Credentials, or the emulator via FIRESTORE_EMULATOR_HOST.
// GCLOUD_PROJECT may override the project: a mismatch with the private file is then rejected.
function creaFirestore(projectId) {
  return admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? projectId }).firestore();
}

async function leggiDaFile(file, options) {
  const config = await leggiConfigurazione(file, options);
  return leggiRilevazione(creaSorgentePersonal(config));
}

// A read or publish error never activates a new generation (pubblicaRilevazione only moves the pointer last).
async function sincronizza(file, { creaSorgente = creaSorgentePersonal, creaDb = creaFirestore, ...options } = {}) {
  const config = await leggiConfigurazione(file, options);
  const destinazione = { projectId: config.firebase.projectId, uid: config.firebase.uid };
  const db = creaDb(destinazione.projectId);
  let rilevazione;
  try {
    rilevazione = await leggiRilevazione(creaSorgente(config));
  } catch (error) {
    await registraTentativoFallito(db, destinazione, error).catch(() => {});
    throw error;
  }
  const { id } = await pubblicaRilevazione(db, destinazione, rilevazione);
  return { id, conti: rilevazione.conti.length };
}

async function main(args, options) {
  if (args.length === 0 || (args.length === 1 && args[0] === '--help')) {
    console.log(`Sincronizzazione locale dei broker

Uso: npm start -- --config <file-privato-esterno>
  --help    Mostra questa guida senza richiedere credenziali.
  --config  Legge i conti selezionati e pubblica la rilevazione su Firestore.

Configurazione: vedi CONFIGURAZIONE.md. Nessuna credenziale viene stampata.
Verifiche locali: npm ci; npm test (senza accessi esterni).
`);
    return;
  }
  try {
    if (args.length !== 2 || args[0] !== '--config') throw new ErroreSorgente('argomenti-non-validi');
    const result = await sincronizza(args[1], options);
    console.log(`Rilevazione pubblicata e attivata: ${result.conti} conti.`);
  } catch (error) {
    console.error(error instanceof ErroreSorgente ? error.message : 'Lettura broker non completata: errore-interno');
    process.exitCode = 1;
  }
}
// The Firestore client keeps the process alive, so exit explicitly once done.
if (require.main === module) main(process.argv.slice(2)).then(() => process.exit());
module.exports = { leggiDaFile, sincronizza, main };
