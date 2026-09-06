/**
 * scripts/firebase/upload_scriptures.mjs
 *
 * Uploads on-demand scripture texts (WEB, BSB, NET) from
 * apps/parable-bloom/assets/data/scripture_seed.json to Firestore:
 *   scriptures_{env}/{Uri.encodeComponent(reference)}/translations/{id}
 *   -> { text, updatedAt, source }
 *
 * `TODO` entries are skipped so partial seeds are safe.
 * KJV ships in the app bundle; kjv seed entries are optional mirrors.
 *
 * Standalone ES module (no build step, no package.json "type" dependency).
 *
 * Usage:
 *   node scripts/firebase/upload_scriptures.mjs dev
 *   FIRESTORE_EMULATOR_HOST="localhost:8080" node scripts/firebase/upload_scriptures.mjs dev
 *   CONFIRM_PROD_UPLOAD=yes node scripts/firebase/upload_scriptures.mjs prod
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import admin from 'firebase-admin';
import { getFirestore } from 'firebase-admin/firestore';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const envArg = process.argv[2] || 'dev';
const env = envArg.toLowerCase();
if (!['dev', 'preview', 'prod'].includes(env)) {
  console.error(`Error: Invalid environment "${envArg}". Must be dev, preview, or prod.`);
  process.exit(1);
}

const collectionName = `scriptures_${env}`;
const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
if (env === 'prod' && !usingEmulator && process.env.CONFIRM_PROD_UPLOAD !== 'yes') {
  console.error('Refusing to upload to PROD collections without confirmation.');
  console.error('Re-run with CONFIRM_PROD_UPLOAD=yes, or set FIRESTORE_EMULATOR_HOST for a dry run.');
  process.exit(1);
}

const seedPath = path.join(__dirname, '..', '..', 'apps', 'parable-bloom', 'assets', 'data', 'scripture_seed.json');
if (!fs.existsSync(seedPath)) {
  console.error(`Seed file not found: ${seedPath}`);
  process.exit(1);
}
const seed = JSON.parse(fs.readFileSync(seedPath, 'utf8'));
const passages = seed.passages || {};

try {
  admin.initializeApp({ projectId: 'parable-bloom' });
} catch (e) {
  console.error('Error initializing Firebase Admin SDK:', e.message);
  process.exit(1);
}

const sources = {
  web: 'https://worldenglish.bible',
  bsb: 'https://berean.bible/terms.htm',
  net: 'https://netbible.com/copyright',
  kjv: 'bundled',
};

async function main() {
  // firebase-admin v14 removed admin.firestore(); v13 and earlier have it.
  const db =
    typeof admin.firestore === 'function'
      ? admin.firestore()
      : getFirestore();
  let uploaded = 0;
  let skipped = 0;
  for (const [reference, versions] of Object.entries(passages)) {
    const docId = encodeURIComponent(reference).replace(/\//g, '_');
    for (const [id, text] of Object.entries(versions)) {
      if (typeof text !== 'string' || text.trim() === '' || text.trim() === 'TODO') {
        skipped++;
        continue;
      }
      await db
        .collection(collectionName)
        .doc(docId)
        .collection('translations')
        .doc(id.toLowerCase())
        .set({
          text,
          updatedAt: new Date().toISOString(),
          source: sources[id.toLowerCase()] || 'seed',
        });
      uploaded++;
    }
  }
  console.log(`Done. Uploaded ${uploaded} translation docs, skipped ${skipped} TODOs.`);
  console.log(`Collection: ${collectionName}`);
}

main().catch((e) => {
  console.error('Upload failed:', e);
  process.exit(1);
});
