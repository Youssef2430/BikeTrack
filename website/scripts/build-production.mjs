import { mkdirSync, readFileSync, writeFileSync, copyFileSync, readdirSync, rmSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const source = path.join(repo, 'website/src');
const docs = path.join(repo, 'docs');
const assets = path.join(docs, 'biketrack');
rmSync(assets, { recursive: true, force: true });
mkdirSync(assets, { recursive: true });
for (const file of readdirSync(path.join(source, 'assets'))) copyFileSync(path.join(source, 'assets', file), path.join(assets, file));
for (const file of ['site.css', 'site.js', 'legal.css']) copyFileSync(path.join(source, file), path.join(assets, file));
for (const file of ['index.html', 'privacy.html', 'support.html']) copyFileSync(path.join(source, file), path.join(docs, file));
writeFileSync(path.join(docs, '.nojekyll'), '');
writeFileSync(path.join(docs, 'sitemap.xml'), '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>https://youssef2430.github.io/BikeTrack/</loc></url><url><loc>https://youssef2430.github.io/BikeTrack/privacy.html</loc></url><url><loc>https://youssef2430.github.io/BikeTrack/support.html</loc></url></urlset>\n');
const html = readFileSync(path.join(docs, 'index.html'), 'utf8');
if (!html.includes('class="headline"') || !html.includes('class="ribbon"')) throw new Error('Production page is incomplete.');
console.log('Built BikeTrack production website → docs/ (GitHub Pages).');
