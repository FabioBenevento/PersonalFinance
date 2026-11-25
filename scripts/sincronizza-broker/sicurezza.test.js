const { test } = require('node:test');
const assert = require('node:assert/strict');
const { Snaptrade, SnaptradeAuth } = require('snaptrade-typescript-sdk');
const { creaSorgenteSnapTrade } = require('./snaptrade');
const fixture = require('./fixtures/snaptrade.json');

function trasporto(connection = { id: 'connessione-demo', type: 'read', disabled: false }, status = 200, accountIds) {
  const requests = [];
  const sdk = new Snaptrade({
    auth: SnaptradeAuth.personalApiKey({ clientId: 'client-test', consumerKey: 'SENTINELLA-CHIAVE' }),
    baseOptions: { adapter: async config => {
      const path = new URL(config.url).pathname;
      requests.push([config.method, path]);
      if (status !== 200) throw { response: { status, data: 'SENTINELLA-CHIAVE' }, message: 'SENTINELLA-CHIAVE' };
      const data = path.startsWith('/authorizations/') ? { ...connection, userSecret: 'SENTINELLA-CHIAVE' }
        : path.endsWith('/balances') ? fixture.balances
        : path.endsWith('/positions/all') ? fixture.positions : fixture.accounts;
      return { data, status: 200, statusText: 'OK', headers: {}, config };
    } },
  });
  return { source: creaSorgenteSnapTrade({ sdk, autenticazione: {}, accountIds }), requests };
}

test('BRO-004 permessi eccessivi o non verificabili impediscono richieste finanziarie', async () => {
  for (const type of ['trade', undefined, 'read,trade']) {
    const { source, requests } = trasporto({ id: 'connessione-demo', type, disabled: false });
    await assert.rejects(source.leggi(), { codice: 'permessi-non-ammessi' });
    assert.deepEqual(requests, [['get', '/accounts'], ['get', '/authorizations/connessione-demo']]);
  }
});

test('BRO-003 seleziona i conti e usa solo quattro GET senza refresh o operazioni finanziarie', async () => {
  const { source, requests } = trasporto(undefined, 200, ['conto-demo']);
  const result = await source.leggi();
  assert.equal(result[0].statoCollegamento, 'attivo');
  assert.equal(JSON.stringify(result).includes('SENTINELLA'), false);
  assert.deepEqual(requests, [
    ['get', '/accounts'], ['get', '/authorizations/connessione-demo'],
    ['get', '/accounts/conto-demo/balances'], ['get', '/accounts/conto-demo/positions/all'],
  ]);
  const excluded = trasporto(undefined, 200, []);
  assert.deepEqual(await excluded.source.leggi(), []);
  assert.deepEqual(excluded.requests, [['get', '/accounts']]);
  const missing = trasporto(undefined, 200, ['assente']);
  await assert.rejects(missing.source.leggi(), { codice: 'conto-non-disponibile' });
  assert.deepEqual(missing.requests, [['get', '/accounts']]);
});

test('BRO-023 connessione disabilitata o stato assente non restituiscono dati in cache', async () => {
  for (const disabled of [true, undefined]) {
    const { source, requests } = trasporto({ id: 'connessione-demo', type: 'read', disabled });
    await assert.rejects(source.leggi(), { codice: disabled ? 'collegamento-da-rinnovare' : 'stato-collegamento-sconosciuto' });
    assert.equal(requests.length, 2);
  }
});

test('BRO-025 BRO-006 limiti e errori producono soltanto diagnostica ammessa senza nuovi tentativi', async () => {
  for (const status of [402, 429, 500]) {
    const { source, requests } = trasporto(undefined, status);
    await assert.rejects(source.leggi(), error => {
      assert.equal(error.codice, status === 500 ? 'lettura-fallita' : 'limite-fornitore');
      assert.equal(JSON.stringify(error).includes('SENTINELLA'), false);
      assert.equal(String(error).includes('SENTINELLA'), false);
      return true;
    });
    assert.deepEqual(requests, [['get', '/accounts']]);
  }
});
