const fs = require('node:fs/promises');
const { constants } = require('node:fs');
const path = require('node:path');
const { ErroreSorgente } = require('./sorgente');

async function leggiConfigurazione(file, { repositoryRoot = path.resolve(__dirname, '../..') } = {}) {
  let handle;
  try {
    if (typeof file !== 'string' || !file) throw new ErroreSorgente('configurazione-mancante');
    const realFile = await fs.realpath(file);
    const repository = await fs.realpath(repositoryRoot);
    const relative = path.relative(repository, realFile);
    if (relative === '' || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative))) {
      throw new ErroreSorgente('file-non-sicuro');
    }
    if (!privateFile(await fs.stat(realFile))) throw new ErroreSorgente('file-non-sicuro');
    handle = await fs.open(realFile, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    const stat = await handle.stat();
    if (!privateFile(stat)) {
      throw new ErroreSorgente('file-non-sicuro');
    }
    if (await fs.realpath(file) !== realFile) throw new ErroreSorgente('file-non-sicuro');
    const current = await fs.stat(realFile);
    if (current.dev !== stat.dev || current.ino !== stat.ino) throw new ErroreSorgente('file-non-sicuro');
    const config = JSON.parse(await handle.readFile('utf8'));
    if (!config || config.adapter !== 'snaptrade' || typeof config.enabled !== 'boolean'
      || !Array.isArray(config.accountIds) || !config.accountIds.every(nonempty)
      || new Set(config.accountIds).size !== config.accountIds.length
      || !nonempty(config.snaptrade?.clientId) || !nonempty(config.snaptrade?.consumerKey)
      || !nonempty(config.firebase?.projectId) || !nonempty(config.firebase?.uid)
      || !/^[a-z][a-z0-9-]*[a-z0-9]$/.test(config.firebase.projectId)
      || config.firebase.uid.includes('/')) {
      throw new ErroreSorgente('configurazione-non-valida');
    }
    if (!config.enabled) throw new ErroreSorgente('integrazione-disattivata');
    // Return only the fields used by the command, never arbitrary file contents.
    return {
      adapter: config.adapter, enabled: config.enabled, accountIds: config.accountIds,
      snaptrade: { clientId: config.snaptrade.clientId, consumerKey: config.snaptrade.consumerKey },
      firebase: { projectId: config.firebase.projectId, uid: config.firebase.uid },
    };
  } catch (error) {
    if (error instanceof ErroreSorgente) throw error;
    throw new ErroreSorgente('configurazione-non-leggibile');
  } finally {
    if (handle) await handle.close();
  }
}
function privateFile(stat) {
  return stat.isFile() && stat.uid === process.getuid() && (stat.mode & 0o077) === 0;
}
function nonempty(value) { return typeof value === 'string' && value.trim().length > 0; }
module.exports = { leggiConfigurazione };
