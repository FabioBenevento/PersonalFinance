const { ErroreSorgente } = require('./sorgente');

function decimal(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  if (typeof value === 'string' && /^[+-]?\d+(?:\.\d+)?$/.test(value)) return value;
  throw new ErroreSorgente('dati-non-validi');
}

function posizione(raw) {
  const instrument = raw.instrument ?? {};
  // Senza id la posizione non e identificabile: la rilevazione non e valida.
  if (typeof instrument.id !== 'string' || instrument.id.length === 0) {
    throw new ErroreSorgente('dati-non-validi');
  }
  const tipo = ['stock', 'etf', 'option'].includes(instrument.kind)
    ? { stock: 'azione', etf: 'etf', option: 'opzione' }[instrument.kind]
    : 'sconosciuto';
  return {
    id: instrument.id,
    simbolo: instrument.symbol ?? null,
    descrizione: instrument.description ?? null,
    tipo,
    valuta: raw.currency ?? null,
    quantita: decimal(raw.units),
    prezzo: decimal(raw.price),
    // The all-positions endpoint supplies per-share prices, not position values.
    valore: null,
    equivalenteLiquidita: raw.cash_equivalent ?? null,
    opzione: tipo === 'opzione' ? {
      sottostante: instrument.underlying ? {
        id: instrument.underlying.id ?? null,
        simbolo: instrument.underlying.symbol ?? null,
      } : null,
      tipo: ['CALL', 'PUT'].includes(instrument.option_type) ? instrument.option_type.toLowerCase() : null,
      strike: decimal(instrument.strike_price),
      scadenza: instrument.expiration_date ?? null,
      moltiplicatore: decimal(instrument.multiplier),
    } : null,
  };
}

function lista(data) {
  // These SDK endpoints return complete arrays, without paging parameters.
  if (!Array.isArray(data)) throw new ErroreSorgente('dati-non-validi');
  return data;
}

function creaSorgenteSnapTrade({ sdk, autenticazione, accountIds }) {
  return {
    async leggi() {
      try {
        const accounts = lista((await sdk.accountInformation.listUserAccounts(autenticazione)).data);
        if (accountIds && accountIds.some(id => !accounts.some(account => account.id === id))) {
          throw new ErroreSorgente('conto-non-disponibile');
        }
        const conti = [];
        const connections = new Map();
        for (const account of accounts) {
          if (accountIds && !accountIds.includes(account.id)) continue;
          if (typeof account.id !== 'string' || account.id.length === 0) {
            throw new ErroreSorgente('dati-non-validi');
          }
          const authorizationId = account.brokerage_authorization;
          if (typeof authorizationId !== 'string' || !authorizationId) {
            throw new ErroreSorgente('permessi-non-ammessi');
          }
          if (!connections.has(authorizationId)) {
            const connection = (await sdk.connections.detailBrokerageAuthorization({
              ...autenticazione, authorizationId,
            })).data;
            if (connection?.id !== authorizationId || connection?.type !== 'read') {
              throw new ErroreSorgente('permessi-non-ammessi');
            }
            if (connection.disabled === true) throw new ErroreSorgente('collegamento-da-rinnovare');
            if (connection.disabled !== false) throw new ErroreSorgente('stato-collegamento-sconosciuto');
            connections.set(authorizationId, connection);
          }
          const holdings = account.sync_status?.holdings;
          if (holdings?.initial_sync_completed === false || holdings?.holdings_unavailable === true) {
            throw new ErroreSorgente('dati-incompleti');
          }
          const params = { ...autenticazione, accountId: account.id };
          const balances = lista((await sdk.accountInformation.getUserAccountBalance(params)).data);
          const positions = (await sdk.accountInformation.getAllAccountPositions(params)).data;
          conti.push({
            id: account.id,
            broker: account.institution_name ?? null,
            nome: account.name ?? null,
            collegamentoId: account.brokerage_authorization ?? null,
            statoCollegamento: 'attivo',
            datiIl: holdings?.last_successful_sync ?? null,
            posizioniDatiIl: positions?.data_freshness?.as_of ?? null,
            liquidita: balances.map(balance => ({
              valuta: balance.currency?.code ?? null,
              importo: decimal(balance.cash),
            })),
            posizioni: lista(positions?.results).map(posizione),
          });
        }
        return conti;
      } catch (error) {
        if (error instanceof ErroreSorgente) throw error;
        const status = error?.response?.status;
        throw new ErroreSorgente([402, 429].includes(status) ? 'limite-fornitore' : 'lettura-fallita');
      }
    },
  };
}
// L'adattatore riceve solo i metodi di lettura usati: il trading dell'SDK non e raggiungibile.
function soloLettura(sdk) {
  const { accountInformation: a, connections: c } = sdk;
  return {
    accountInformation: {
      listUserAccounts: params => a.listUserAccounts(params),
      getUserAccountBalance: params => a.getUserAccountBalance(params),
      getAllAccountPositions: params => a.getAllAccountPositions(params),
    },
    connections: { detailBrokerageAuthorization: params => c.detailBrokerageAuthorization(params) },
  };
}
function creaSorgentePersonal(config) {
  const { Snaptrade, SnaptradeAuth } = require('snaptrade-typescript-sdk');
  const sdk = new Snaptrade({ auth: SnaptradeAuth.personalApiKey(config.snaptrade) });
  return creaSorgenteSnapTrade({ sdk: soloLettura(sdk), autenticazione: {}, accountIds: config.accountIds });
}
module.exports = { creaSorgenteSnapTrade, creaSorgentePersonal, soloLettura };
