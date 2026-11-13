const { test } = require('node:test');
const assert = require('node:assert/strict');
const { createServer } = require('./server.cjs');
test('test server exposes only its player assets and build status', async t => {
  const server = createServer();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;
  const home = await fetch(base);
  assert.equal(home.status, 200);
  assert.match(await home.text(), /Test player/);
  assert.match(home.headers.get('content-security-policy'), /frame-ancestors 'none'/);
  const status = await fetch(`${base}/api/build`);
  const body = await status.json();
  assert.equal(typeof body.available, 'boolean');
  for (const route of ['/README.md', '/.git/config', '/..%2fREADME.md', '/ParkCast/ParkCastApp.swift']) {
    assert.equal((await fetch(base + route)).status, 404);
  }
  assert.equal((await fetch(base, { method: 'POST', body: 'video-content' })).status, 405);
  const head = await fetch(base, { method: 'HEAD' });
  assert.equal(head.status, 200);
  assert.equal(await head.text(), '');
});
