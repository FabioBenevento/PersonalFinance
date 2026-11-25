const { leggiConfigurazione } = require('./configurazione');
const { creaSorgentePersonal } = require('./snaptrade');
const { leggiRilevazione, ErroreSorgente } = require('./sorgente');

async function leggiDaFile(file, options) {
  const config = await leggiConfigurazione(file, options);
  return leggiRilevazione(creaSorgentePersonal(config));
}

async function main(args) {
  if (args.length === 0 || (args.length === 1 && args[0] === '--help')) {
    console.log(`Sincronizzazione locale dei broker

Uso: npm start -- --config <file-privato-esterno>
  --help    Mostra questa guida senza richiedere credenziali.
  --config  Legge i conti selezionati; non pubblica ancora su Firebase.

Configurazione: vedi CONFIGURAZIONE.md. Nessuna credenziale viene stampata.
Verifiche locali: npm ci; npm test (senza accessi esterni).
`);
    return;
  }
  try {
    if (args.length !== 2 || args[0] !== '--config') throw new ErroreSorgente('argomenti-non-validi');
    const result = await leggiDaFile(args[1]);
    console.log(`Lettura completa: ${result.conti.length} conti.`);
  } catch (error) {
    console.error(error instanceof ErroreSorgente ? error.message : 'Lettura broker non completata: errore-interno');
    process.exitCode = 1;
  }
}
if (require.main === module) main(process.argv.slice(2));
module.exports = { leggiDaFile };
