// Renders the design prototype's 12 screens to PNG via Puppeteer.
// Waits for React to mount (sidebar present), then dispatches clicks on the
// matching sidebar entry per screen.

import puppeteer from 'puppeteer';
import { mkdir, rm, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer } from 'node:http';
import { readFileSync, statSync } from 'node:fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const PROTO = path.join(ROOT, 'docs', 'proto');
const OUT = path.join(ROOT, 'docs', 'screenshots');

const SCREENS = [
  { id: 'dashboard',   label: '01-dashboard',         needle: "vue d'ensemble" },
  { id: 'scan',        label: '02-smart-scan',        needle: 'smart scan' },
  { id: 'cleanup',     label: '03-cleanup',           needle: 'fichiers inutiles' },
  { id: 'uninstaller', label: '04-uninstaller',       needle: 'désinstalleur' },
  { id: 'files',       label: '05-files-duplicates',  needle: 'volumineux' },
  { id: 'spacelens',   label: '06-space-lens',        needle: 'space lens' },
  { id: 'security',    label: '07-security',          needle: 'sécurité' },
  { id: 'privacy',     label: '08-privacy',           needle: 'confidentialité' },
  { id: 'updates',     label: '09-updates',           needle: 'mises à jour' },
  { id: 'optimize',    label: '10-performance',       needle: 'performance' },
  { id: 'maintenance', label: '11-maintenance',       needle: 'maintenance' },
  { id: 'result',      label: '12-result',            needle: null /* via keyboard */ },
];

// Tiny static server so React/Babel can load relative scripts properly.
const mime = { '.html':'text/html', '.jsx':'application/javascript', '.svg':'image/svg+xml', '.js':'application/javascript' };
const server = createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p === '/') p = '/CleanMac Pro.html';
  const file = path.join(PROTO, p);
  try {
    const st = statSync(file);
    if (st.isFile()) {
      res.setHeader('Content-Type', mime[path.extname(file)] || 'text/plain');
      res.end(readFileSync(file));
      return;
    }
  } catch {}
  res.statusCode = 404;
  res.end();
});

await new Promise(r => server.listen(0, r));
const port = server.address().port;
const baseURL = `http://127.0.0.1:${port}/CleanMac%20Pro.html`;
console.log('Serving', baseURL);

await rm(OUT, { recursive: true, force: true });
await mkdir(OUT, { recursive: true });

const browser = await puppeteer.launch({
  headless: 'new',
  args: ['--no-sandbox'],
  defaultViewport: { width: 1440, height: 900, deviceScaleFactor: 2 },
});
const page = await browser.newPage();

for (const screen of SCREENS) {
  console.log(`→ ${screen.label}`);
  await page.goto(baseURL, { waitUntil: 'networkidle0', timeout: 20_000 });
  // Wait until React mounts the sidebar (presence of any aside)
  await page.waitForFunction(
    () => document.querySelectorAll('aside button').length > 0,
    { timeout: 15_000 }
  );

  if (screen.needle) {
    await page.evaluate((needle) => {
      const buttons = [...document.querySelectorAll('aside button')];
      const btn = buttons.find(b => b.innerText.toLowerCase().includes(needle));
      if (btn) btn.click();
    }, screen.needle);
  } else if (screen.id === 'result') {
    // Trigger ⌘⇧K binding → Result screen
    await page.evaluate(() => {
      window.dispatchEvent(new KeyboardEvent('keydown', { key: 'K', metaKey: true, shiftKey: true, bubbles: true }));
    });
  }

  // Let animations finish (sunburst rise, AnimatedNumber tween…)
  await new Promise(r => setTimeout(r, 1200));
  await page.screenshot({
    path: path.join(OUT, `${screen.label}.png`),
    fullPage: false,
  });
}

await browser.close();
server.close();
console.log('Done →', OUT);
