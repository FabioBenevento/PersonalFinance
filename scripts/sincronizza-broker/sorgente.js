class ErroreSorgente extends Error {
  constructor(codice) {
    super(`Lettura broker non completata: ${codice}`);
    this.name = 'ErroreSorgente';
    this.codice = codice;
  }
}

// Sources expose only leggi(): all accounts, cash and positions, or an error.
async function leggiRilevazione(sorgente, { clock = () => new Date() } = {}) {
  const lettaIl = clock().toISOString();
  const conti = await sorgente.leggi();
  if (!Array.isArray(conti)) throw new ErroreSorgente('dati-non-validi');
  return { schemaVersion: 1, lettaIl, conti };
}
module.exports = { leggiRilevazione, ErroreSorgente };
