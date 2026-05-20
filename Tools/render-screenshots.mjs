// Renders the design prototype's 12 screens to PNG via Chrome headless.
// Spawns Chrome via the macOS app, points it at a local file:// URL, injects
// JavaScript that flips the React app's `setActive` for each screen, then
// captures a screenshot.

import { mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const PROTO = path.join(ROOT, 'docs', 'proto');
const OUT = path.join(ROOT, 'docs', 'screenshots');

// macOS-localized first run dialog can interfere. Use a temp profile dir.
const PROFILE = path.join(ROOT, '.build', 'chrome-profile');

const SCREENS = [
  { id: 'dashboard',   label: '01-dashboard' },
  { id: 'scan',        label: '02-smart-scan' },
  { id: 'cleanup',     label: '03-cleanup' },
  { id: 'uninstaller', label: '04-uninstaller' },
  { id: 'files',       label: '05-files-duplicates' },
  { id: 'spacelens',   label: '06-space-lens' },
  { id: 'security',    label: '07-security' },
  { id: 'privacy',     label: '08-privacy' },
  { id: 'updates',     label: '09-updates' },
  { id: 'optimize',    label: '10-performance' },
  { id: 'maintenance', label: '11-maintenance' },
  { id: 'result',      label: '12-result' },
];

async function run() {
  await rm(OUT, { recursive: true, force: true });
  await mkdir(OUT, { recursive: true });
  await mkdir(PROFILE, { recursive: true });

  // Patch the HTML to accept a `?screen=` query and pre-set the active screen
  // after React mounts. We do this by appending a small script tag.
  const htmlSrc = path.join(PROTO, 'CleanMac Pro.html');
  const htmlPatched = path.join(PROTO, 'screenshot.html');
  const fs = await import('node:fs/promises');
  const raw = await fs.readFile(htmlSrc, 'utf8');
  const inject = `
<script>
  window.addEventListener('load', () => {
    const url = new URL(location.href);
    const target = url.searchParams.get('screen');
    if (!target) return;
    // Wait for React to mount, then walk DOM and find sidebar button matching id
    const tryClick = () => {
      const buttons = document.querySelectorAll('aside button');
      for (const b of buttons) {
        const t = b.innerText.toLowerCase();
        // crude mapping
        const map = {
          dashboard: "vue d'ensemble", scan: 'smart scan',
          cleanup: 'fichiers inutiles', uninstaller: 'désinstalleur',
          files: 'volumineux', spacelens: 'space lens',
          security: 'sécurité', privacy: 'confidentialité',
          updates: 'mises à jour', optimize: 'performance',
          maintenance: 'maintenance', result: ''
        };
        const needle = map[target];
        if (needle && t.includes(needle)) { b.click(); return true; }
      }
      return false;
    };
    if (target === 'result') {
      // Trigger ⌘⇧K binding by dispatching a key event
      const tryResult = () => {
        const evt = new KeyboardEvent('keydown', { key: 'K', metaKey: true, shiftKey: true, bubbles: true });
        window.dispatchEvent(evt);
      };
      setTimeout(tryResult, 800);
    } else {
      let tries = 0;
      const interval = setInterval(() => {
        if (tryClick() || ++tries > 20) clearInterval(interval);
      }, 200);
    }
  });
</script>
</body>`;
  await fs.writeFile(htmlPatched, raw.replace('</body>', inject));

  // Spawn one Chrome instance per screen (simpler than driving via remote-debugging)
  const chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  if (!existsSync(chrome)) {
    console.error('Chrome not found at', chrome);
    process.exit(1);
  }

  for (const screen of SCREENS) {
    const fileURL = `file://${htmlPatched}?screen=${screen.id}`;
    const outPng = path.join(OUT, `${screen.label}.png`);
    console.log(`→ ${screen.label}`);
    await new Promise((resolve, reject) => {
      const args = [
        '--headless=new',
        '--disable-gpu',
        '--hide-scrollbars',
        '--window-size=1440,900',
        `--screenshot=${outPng}`,
        '--virtual-time-budget=4000',  // give React + interval enough time
        `--user-data-dir=${PROFILE}`,
        fileURL,
      ];
      const c = spawn(chrome, args, { stdio: 'inherit' });
      const t = setTimeout(() => { c.kill(); reject(new Error('timeout')); }, 25_000);
      c.on('exit', (code) => { clearTimeout(t); code === 0 ? resolve() : reject(new Error('chrome exit ' + code)); });
    }).catch(e => console.error('  failed:', e.message));
  }
  console.log('Done →', OUT);
}

run();
