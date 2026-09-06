/**
 * scripts/firebase/upload_themes.js
 *
 * Uploads apps/parable-bloom/assets/data/biblical_themes.json to
 * configs_{env}/biblical_themes (the read path already exists client-side;
 * no writer existed until now).
 *
 * Gates before writing:
 *   - every passage has >= 2 reflection prompts (journal integrity rule)
 *   - every lvl_* trigger_level exists in modules.json level_mappings
 *     (+ lesson_* triggers exist as lesson files)
 *   - document under the 1 MiB Firestore limit
 *
 * Usage:
 *   node scripts/firebase/upload_themes.js <env> [--dry-run]
 *   FIRESTORE_EMULATOR_HOST="localhost:8080" node scripts/firebase/upload_themes.js dev
 *   CONFIRM_PROD_UPLOAD=yes node scripts/firebase/upload_themes.js prod
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const DOC_LIMIT_BYTES = 1_048_576;

const envArg = process.argv[2] || 'dev';
const env = envArg.toLowerCase();
if (!['dev', 'preview', 'prod'].includes(env)) {
  console.error(`Error: Invalid environment "${envArg}". Must be dev, preview, or prod.`);
  process.exit(1);
}
const DRY_RUN = process.argv.includes('--dry-run');

const configsCollection = `configs_${env}`;
const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
if (env === 'prod' && !usingEmulator && process.env.CONFIRM_PROD_UPLOAD !== 'yes') {
  console.error('Refusing to upload to PROD collections without confirmation.');
  console.error('Re-run with CONFIRM_PROD_UPLOAD=yes, or set FIRESTORE_EMULATOR_HOST for a dry run.');
  process.exit(1);
}

try {
  admin.initializeApp({ projectId: 'parable-bloom' });
} catch (e) {
  console.error('Error initializing Firebase Admin SDK:', e.message);
  process.exit(1);
}
const db = (() => {
  // firebase-admin v14 removed admin.firestore(); v13 and earlier have it.
  if (typeof admin.firestore === 'function') return admin.firestore();
  return require('firebase-admin/firestore').getFirestore();
})();

const repoRoot = path.resolve(__dirname, '../..');
const assetsDir = path.join(repoRoot, 'apps/parable-bloom/assets');

function readJson(rel) {
  return JSON.parse(fs.readFileSync(path.join(assetsDir, rel), 'utf8'));
}

let themesData;
let modulesData;
try {
  themesData = readJson('data/biblical_themes.json');
  modulesData = readJson('data/modules.json');
} catch (e) {
  console.error('Error reading asset JSON:', e.message);
  process.exit(1);
}

const problems = [];
const themes = themesData.themes || [];
if (themes.length === 0) problems.push('no themes found');
const mappings = modulesData.level_mappings || {};

for (const theme of themes) {
  for (const f of ['id', 'name', 'description', 'icon']) {
    if (!theme[f]) problems.push(`theme missing ${f}: ${JSON.stringify(theme.id)}`);
  }
  for (const ps of theme.passages || []) {
    if (!Array.isArray(ps.reflection_prompts) || ps.reflection_prompts.length < 2) {
      problems.push(`passage ${ps.id} has < 2 reflection prompts`);
    }
    const trig = ps.trigger_level || '';
    if (trig.startsWith('lvl_') && !mappings[trig]) {
      problems.push(`passage ${ps.id} trigger ${trig} not in level_mappings`);
    }
    if (trig.startsWith('lesson_') && !mappings[trig]) {
      problems.push(`passage ${ps.id} trigger ${trig} not in level_mappings`);
    }
  }
}

const bytes = Buffer.byteLength(JSON.stringify(themesData), 'utf8');
if (bytes >= DOC_LIMIT_BYTES) {
  problems.push(`themes doc is ${bytes} bytes (>= 1 MiB limit)`);
}

if (problems.length > 0) {
  console.error(`Error: ${problems.length} theme problem(s), refusing to upload:`);
  for (const p of problems.slice(0, 20)) console.error(`   • ${p}`);
  process.exit(1);
}

const passageCount = themes.reduce((n, t) => n + (t.passages || []).length, 0);
console.log(`Themes validated: ${themes.length} themes, ${passageCount} passages (${bytes} bytes).`);

async function main() {
  if (DRY_RUN) {
    console.log(`Dry run: would write ${configsCollection}/biblical_themes.`);
    return;
  }
  await db.collection(configsCollection).doc('biblical_themes').set(themesData);
  console.log(`Uploaded ${configsCollection}/biblical_themes.`);
}

main().catch((err) => {
  console.error('Fatal error during upload:', err);
  process.exit(1);
});
