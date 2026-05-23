import sharp from 'sharp';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '..');
const svgPath = resolve(root, 'public/icons/skintel.svg');
const outDir = resolve(root, 'public/icons');
mkdirSync(outDir, { recursive: true });

const svg = readFileSync(svgPath);

const maskableSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <rect width="512" height="512" fill="#A35848"/>
  <g transform="translate(256 256) scale(0.78)">
    <circle r="160" fill="#FAF8F5"/>
    <g fill="#A35848" transform="translate(-72 -72)">
      <path d="M72 0 L88 56 L144 72 L88 88 L72 144 L56 88 L0 72 L56 56 Z"/>
    </g>
    <g fill="#A35848" opacity="0.9" transform="translate(36 36) scale(0.55)">
      <path d="M36 0 L44 28 L72 36 L44 44 L36 72 L28 44 L0 36 L28 28 Z"/>
    </g>
    <g fill="#A35848" opacity="0.75" transform="translate(40 -88) scale(0.4)">
      <path d="M36 0 L44 28 L72 36 L44 44 L36 72 L28 44 L0 36 L28 28 Z"/>
    </g>
  </g>
</svg>`;

const faviconSvg = readFileSync(resolve(root, 'public/favicon.svg'));

const tasks = [
  { name: 'apple-touch-icon.png', size: 180, src: svg },
  { name: 'icon-192.png', size: 192, src: svg },
  { name: 'icon-512.png', size: 512, src: svg },
  { name: 'icon-512-maskable.png', size: 512, src: Buffer.from(maskableSvg) },
  { name: 'favicon-32.png', size: 32, src: faviconSvg },
  { name: 'favicon-16.png', size: 16, src: faviconSvg },
];

for (const t of tasks) {
  const out = resolve(outDir, t.name);
  await sharp(t.src, { density: 384 }).resize(t.size, t.size).png().toFile(out);
  console.log('wrote', t.name);
}
