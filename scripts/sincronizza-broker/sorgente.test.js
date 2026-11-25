const { test } = require('node:test');
const assert = require('node:assert/strict');
const { leggiRilevazione } = require('./sorgente');
const clock = () => new Date('2026-11-25T12:00:00Z');

test('BRO-001 sorgenti sostituibili con la stessa rilevazione', async () => {
  const conto = { id: 'conto-test', posizioni: [] };
  const onePage = { async leggi() { return [conto]; } };
  const twoPages = { async leggi() { return structuredClone([conto]); } };
  const expected = { schemaVersion: 1, lettaIl: '2026-11-25T12:00:00.000Z', conti: [conto] };
  assert.deepEqual(await leggiRilevazione(onePage, { clock }), expected);
  assert.deepEqual(await leggiRilevazione(twoPages, { clock }), expected);
});

const { creaSorgenteSnapTrade } = require('./snaptrade');
const fixture = require('./fixtures/snaptrade.json');
function sorgente(data = fixture) {
  const calls = [];
  const sdk = { connections: {
    async detailBrokerageAuthorization() { return { data: { id: 'connessione-demo', type: 'read', disabled: false } }; },
  }, accountInformation: {
    async listUserAccounts(params) { calls.push(['conti', params]); return { data: data.accounts }; },
    async getUserAccountBalance(params) { calls.push(['cash', params]); return { data: data.balances }; },
    async getAllAccountPositions(params) { calls.push(['posizioni', params]); return { data: data.positions }; },
  } };
  return { adapter: creaSorgenteSnapTrade({ sdk, autenticazione: { userId: 'utente-demo', userSecret: 'segreto-fittizio' } }), calls };
}

test('BRO-008 conserva conti, cash effettivo, frazioni e zero distinto da assenza', async () => {
  const { adapter, calls } = sorgente();
  const result = await leggiRilevazione(adapter, { clock });
  assert.equal(result.conti.length, 1);
  const conto = result.conti[0];
  assert.deepEqual(conto.liquidita, [{ valuta: 'EUR', importo: '100' }]);
  assert.equal(conto.posizioni[0].quantita, '1.123456789012345678');
  assert.equal(conto.posizioni[1].tipo, 'etf');
  assert.equal(conto.posizioni[1].prezzo, '0');
  assert.equal(conto.posizioni[0].valore, null);
  assert.equal(conto.datiIl, '2026-11-24T18:00:00Z');
  assert.equal(conto.posizioniDatiIl, '2026-11-24T18:01:00Z');
  assert.deepEqual(calls.map(([name]) => name), ['conti', 'cash', 'posizioni']);
  assert.deepEqual(calls[2][1], { userId: 'utente-demo', userSecret: 'segreto-fittizio', accountId: 'conto-demo' });
});

test('BRO-009 conserva call long, put short e prezzi per azione senza inventare valori', async () => {
  const result = await leggiRilevazione(sorgente().adapter, { clock });
  const [, , call, put] = result.conti[0].posizioni;
  assert.equal(call.quantita, '2');
  assert.equal(put.quantita, '-3');
  assert.equal(put.prezzo, '1.50');
  assert.equal(put.valore, null);
  assert.deepEqual(call.opzione, {
    sottostante: { id: 'azione-demo', simbolo: 'DEMO' },
    tipo: 'call', strike: '125.50', scadenza: '2027-01-15', moltiplicatore: '100',
  });
  assert.deepEqual(put.opzione, {
    sottostante: { id: 'azione-demo', simbolo: 'DEMO' },
    tipo: 'put', strike: '100', scadenza: '2027-02-19', moltiplicatore: '10',
  });
});

test('BRO-010 campi assenti e strumenti sconosciuti rimangono consultabili', async () => {
  const result = await leggiRilevazione(sorgente().adapter, { clock });
  assert.deepEqual(result.conti[0].posizioni[4], {
    id: 'ignoto-demo', simbolo: 'FUT', descrizione: null, tipo: 'sconosciuto',
    valuta: null, quantita: null, prezzo: null, valore: null,
    equivalenteLiquidita: null, opzione: null,
  });
});

test('BRO-012 lettura completa vuota e nuova lettura non conservano posizioni chiuse', async () => {
  const data = structuredClone(fixture);
  const { adapter } = sorgente(data);
  assert.equal((await leggiRilevazione(adapter, { clock })).conti[0].posizioni.length, 5);
  data.positions.results = [];
  assert.deepEqual((await leggiRilevazione(adapter, { clock })).conti[0].posizioni, []);
  data.accounts = [];
  assert.deepEqual((await leggiRilevazione(adapter, { clock })).conti, []);
});

test('BRO-012 errore o risposta incompleta non diventano elenco vuoto', async () => {
  for (const positions of [null, {}, { results: null }]) {
    await assert.rejects(leggiRilevazione(sorgente({ ...fixture, positions }).adapter), { codice: 'dati-non-validi' });
  }
  const data = structuredClone(fixture);
  data.accounts[0].sync_status.holdings.holdings_unavailable = true;
  await assert.rejects(leggiRilevazione(sorgente(data).adapter), { codice: 'dati-incompleti' });
});

test('BRO-008 tutti i conti sono letti; un errore intermedio rifiuta la rilevazione', async () => {
  const data = structuredClone(fixture);
  data.accounts.push({ ...data.accounts[0], id: 'secondo-conto' });
  const { adapter, calls } = sorgente(data);
  assert.equal((await leggiRilevazione(adapter)).conti.length, 2);
  assert.equal(calls.length, 5);
  data.positions.results = undefined;
  await assert.rejects(leggiRilevazione(adapter), { codice: 'dati-non-validi' });
});

test('BRO-010 rifiuta decimali corrotti senza trasformarli in zero', async () => {
  const data = structuredClone(fixture);
  data.positions.results[0].units = 'non-un-numero';
  await assert.rejects(leggiRilevazione(sorgente(data).adapter), { codice: 'dati-non-validi' });
});

test('BRO-001 BRO-008 BRO-009 contratto condiviso tramite SDK Personal e trasporto intercettato', async () => {
  const { Snaptrade, SnaptradeAuth } = require('snaptrade-typescript-sdk');
  const expected = require('./fixtures/rilevazione.json');
  const requests = [];
  const sdk = new Snaptrade({
    auth: SnaptradeAuth.personalApiKey({ clientId: 'client-demo', consumerKey: 'chiave-demo' }),
    baseOptions: {
      adapter: async config => {
        const pathname = new URL(config.url).pathname;
        requests.push([config.method, pathname]);
        const data = pathname.startsWith('/authorizations/') ? { id: 'connessione-demo', type: 'read', disabled: false }
          : pathname.endsWith('/positions/all') ? fixture.positions
          : pathname.endsWith('/balances') ? fixture.balances : fixture.accounts;
        return { data, status: 200, statusText: 'OK', headers: {}, config };
      },
    },
  });
  const adapter = creaSorgenteSnapTrade({ sdk, autenticazione: {} });
  assert.deepEqual(await leggiRilevazione(adapter, { clock }), expected);
  assert.deepEqual(requests, [
    ['get', '/accounts'], ['get', '/authorizations/connessione-demo'], ['get', '/accounts/conto-demo/balances'], ['get', '/accounts/conto-demo/positions/all'],
  ]);
  const alternate = { async leggi() { return structuredClone(expected.conti); } };
  assert.deepEqual(await leggiRilevazione(alternate, { clock }), expected);
});
