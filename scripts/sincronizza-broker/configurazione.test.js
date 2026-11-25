const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { leggiConfigurazione } = require('./configurazione');
const configuration = {
  adapter: 'snaptrade', enabled: true, accountIds: ['conto-demo'],
  snaptrade: { clientId: 'client-test', consumerKey: 'SENTINELLA-CHIAVE' },
  firebase: { projectId: 'progetto-test', uid: 'utente-test' },
};
async function setup(t) {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'broker-test-'));
  t.after(() => fs.rm(dir, { recursive: true, force: true }));
  const repositoryRoot = path.join(dir, 'repo');
  await fs.mkdir(repositoryRoot);
  const file = path.join(dir, 'private.json');
  await fs.writeFile(file, JSON.stringify(configuration), { mode: 0o600 });
  return { dir, repositoryRoot, file };
}

test('BRO-024 rifiuta file con accesso di gruppo o altri', async t => {
  const { file, repositoryRoot } = await setup(t);
  await fs.chmod(file, 0o640);
  await assert.rejects(leggiConfigurazione(file, { repositoryRoot }), { codice: 'file-non-sicuro' });
});

test('BRO-024 percorso reale interno, anche attraverso link simbolico, viene rifiutato', async t => {
  const { dir, repositoryRoot, file } = await setup(t);
  const inside = path.join(repositoryRoot, 'private.json');
  await fs.copyFile(file, inside);
  const link = path.join(dir, 'link.json');
  await fs.symlink(inside, link);
  for (const target of [inside, link, repositoryRoot]) {
    await assert.rejects(leggiConfigurazione(target, { repositoryRoot }), { codice: 'file-non-sicuro' });
  }
});

test('BRO-024 file esterno privato e link verso lo stesso file sono accettati', async t => {
  const { dir, repositoryRoot, file } = await setup(t);
  assert.deepEqual(await leggiConfigurazione(file, { repositoryRoot }), configuration);
  const link = path.join(repositoryRoot, 'link.json');
  await fs.symlink(file, link);
  assert.deepEqual(await leggiConfigurazione(link, { repositoryRoot }), configuration);
  const directory = path.join(dir, 'directory');
  await fs.mkdir(directory, { mode: 0o700 });
  await assert.rejects(leggiConfigurazione(directory, { repositoryRoot }), { codice: 'file-non-sicuro' });
});

test('BRO-005 BRO-024 configurazione incompleta e destinazione ambigua falliscono senza segreti', async t => {
  const { file, repositoryRoot } = await setup(t);
  for (const config of [
    { ...configuration, snaptrade: {} },
    { ...configuration, firebase: {} },
    { ...configuration, firebase: { projectId: 'progetto-test', uid: 'users/altro' } },
    { ...configuration, accountIds: ['conto-demo', 'conto-demo'] },
    { ...configuration, enabled: 'true' },
  ]) {
    await fs.writeFile(file, JSON.stringify(config));
    await assert.rejects(leggiConfigurazione(file, { repositoryRoot }), error => {
      assert.equal(error.codice, 'configurazione-non-valida');
      assert.equal(String(error).includes('SENTINELLA'), false);
      return true;
    });
  }
  await assert.rejects(leggiConfigurazione(), { codice: 'configurazione-mancante' });
  await fs.writeFile(file, 'SENTINELLA-CHIAVE');
  await assert.rejects(leggiConfigurazione(file, { repositoryRoot }), { codice: 'configurazione-non-leggibile' });
});

test('BRO-023 integrazione disattivata viene segnalata prima di costruire il client', async t => {
  const { file, repositoryRoot } = await setup(t);
  await fs.writeFile(file, JSON.stringify({ ...configuration, enabled: false }));
  await assert.rejects(leggiConfigurazione(file, { repositoryRoot }), { codice: 'integrazione-disattivata' });
});

test('BRO-005 BRO-006 comando senza configurazione valida non emette traffico o segreti', async t => {
  const { leggiDaFile } = require('./cli');
  const { file, repositoryRoot } = await setup(t);
  // Invalid configuration fails before the SDK can be constructed or issue requests.
  await fs.writeFile(file, JSON.stringify({ ...configuration, snaptrade: {} }));
  await assert.rejects(leggiDaFile(file, { repositoryRoot }), { codice: 'configurazione-non-valida' });
  const { spawnSync } = require('node:child_process');
  const result = spawnSync(process.execPath, [path.join(__dirname, 'cli.js'), '--config', file], { encoding: 'utf8' });
  assert.equal(result.status, 1);
  assert.equal(result.stdout, '');
  assert.equal(result.stderr, 'Lettura broker non completata: configurazione-non-valida\n');
});

test('BRO-024 file di altro proprietario viene rifiutato prima della lettura', async t => {
  // Linux exposes a root-owned 0600 file, so only ownership makes it unsafe.
  const file = '/proc/1/mem';
  const stat = await fs.stat(file).catch(() => null);
  if (!stat || stat.uid === process.getuid()) { t.skip('Richiede un file Linux di altro proprietario'); return; }
  assert.notEqual(stat.uid, process.getuid());
  assert.equal(stat.mode & 0o077, 0);
  const { repositoryRoot } = await setup(t);
  await assert.rejects(leggiConfigurazione(file, { repositoryRoot }), { codice: 'file-non-sicuro' });
});
