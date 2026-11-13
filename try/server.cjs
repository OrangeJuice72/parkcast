'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = __dirname;
const ipa = path.join(root, '..', 'dist', 'ParkCast-unsigned.ipa');
const files = new Map([
  ['/', ['index.html', 'text/html; charset=utf-8']],
  ['/app.js', ['app.js', 'text/javascript; charset=utf-8']],
  ['/style.css', ['style.css', 'text/css; charset=utf-8']],
  ['/manifest.webmanifest', ['manifest.webmanifest', 'application/manifest+json']],
  ['/icon.svg', ['icon.svg', 'image/svg+xml']],
]);
function createServer() {
  return http.createServer((req, res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; media-src https: blob:; connect-src 'self'; object-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'");
    if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405, { Allow: 'GET, HEAD' }); res.end('Method not allowed'); return; }
    let pathname;
    try { pathname = new URL(req.url, 'http://localhost').pathname; }
    catch { res.writeHead(400); res.end('Invalid URL'); return; }
    if (pathname === '/api/build') {
      const available = fs.existsSync(ipa);
      const payload = JSON.stringify({ available, bytes: available ? fs.statSync(ipa).size : 0 });
      res.writeHead(200, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) });
      res.end(req.method === 'HEAD' ? undefined : payload); return;
    }
    if (pathname === '/download/ParkCast-unsigned.ipa') {
      if (!fs.existsSync(ipa)) { res.writeHead(404); res.end('The native build is not ready yet.'); return; }
      res.writeHead(200, { 'Content-Type': 'application/octet-stream', 'Content-Length': fs.statSync(ipa).size, 'Content-Disposition': 'attachment; filename="ParkCast-unsigned.ipa"' });
      if (req.method === 'HEAD') res.end(); else fs.createReadStream(ipa).pipe(res);
      return;
    }
    const file = files.get(pathname);
    if (!file) { res.writeHead(404); res.end('Not found'); return; }
    fs.readFile(path.join(root, file[0]), (error, data) => {
      if (error) { res.writeHead(500); res.end('Unable to read application asset'); return; }
      res.writeHead(200, { 'Content-Type': file[1], 'Content-Length': data.length });
      res.end(req.method === 'HEAD' ? undefined : data);
    });
  });
}
if (require.main === module) {
  const port = Number(process.env.PARKCAST_PORT || 4191);
  const server = createServer();
  server.on('error', error => { console.error(error.message); process.exitCode = 1; });
  server.listen(port, '127.0.0.1', () => console.log(`ParkCast Safari test: http://127.0.0.1:${port}`));
}
module.exports = { createServer };
