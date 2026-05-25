import sharp from 'sharp';
import { resolve } from 'node:path';
import { homedir } from 'node:os';

const downloads = resolve(homedir(), 'Downloads');

const iconSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" rx="224" fill="#A35848"/>
  <g transform="translate(512 512)">
    <circle r="280" fill="#FAF8F5"/>
    <g fill="#A35848" transform="translate(-128 -128)">
      <path d="M128 0 L156 100 L256 128 L156 156 L128 256 L100 156 L0 128 L100 100 Z"/>
    </g>
    <g fill="#A35848" opacity="0.85" transform="translate(72 72) scale(0.5)">
      <path d="M64 0 L78 50 L128 64 L78 78 L64 128 L50 78 L0 64 L50 50 Z"/>
    </g>
    <g fill="#A35848" opacity="0.7" transform="translate(80 -160) scale(0.35)">
      <path d="M64 0 L78 50 L128 64 L78 78 L64 128 L50 78 L0 64 L50 50 Z"/>
    </g>
  </g>
</svg>`;

const wordmarkSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="300" viewBox="0 0 1200 300">
  <rect width="1200" height="300" fill="#FAF8F5"/>
  <g transform="translate(120 150)">
    <g transform="translate(0 0)">
      <circle r="70" fill="#A35848"/>
      <g fill="#FAF8F5" transform="translate(-32 -32)">
        <path d="M32 0 L39 25 L64 32 L39 39 L32 64 L25 39 L0 32 L25 25 Z"/>
      </g>
    </g>
  </g>
  <text x="240" y="190" font-family="Georgia, 'Times New Roman', serif" font-size="120" font-style="italic" fill="#1F1A17">Skintel<tspan fill="#A35848">.</tspan></text>
</svg>`;

await sharp(Buffer.from(iconSvg), { density: 400 })
  .resize(1024, 1024)
  .png({ compressionLevel: 9 })
  .toFile(resolve(downloads, 'skintel-stripe-icon.png'));
console.log('wrote', resolve(downloads, 'skintel-stripe-icon.png'));

await sharp(Buffer.from(iconSvg), { density: 400 })
  .resize(512, 512)
  .png({ compressionLevel: 9 })
  .toFile(resolve(downloads, 'skintel-stripe-icon-512.png'));
console.log('wrote', resolve(downloads, 'skintel-stripe-icon-512.png'));

await sharp(Buffer.from(wordmarkSvg), { density: 400 })
  .resize(1200, 300)
  .png({ compressionLevel: 9 })
  .toFile(resolve(downloads, 'skintel-stripe-logo.png'));
console.log('wrote', resolve(downloads, 'skintel-stripe-logo.png'));
