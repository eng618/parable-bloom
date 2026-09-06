/**
 * scripts/firebase/upload_levels.js
 *
 * Batch-upload generated level JSON files from local assets to Cloud
 * Firestore levels collections (levels_dev, levels_preview, levels_prod),
 * plus the modules registry (configs_{env}/modules).
 *
 * Writes go through Firestore BulkWriter (automatic retry with backoff,
 * throttling) instead of sequential single writes.
 *
 * Usage:
 *   node scripts/firebase/upload_levels.js <env> [flags]
 *
 * Envs: dev | preview | prod (prod requires CONFIRM_PROD_UPLOAD=yes,
 *   unless talking to the local emulator).
 *
 * Flags:
 *   --dry-run          Plan only: validate inputs, print what would be
 *                      uploaded, write nothing.
 *   --only-missing     List existing level docs first and skip them
 *                      (resume / idempotent re-runs).
 *   --range A-B        Only physical levels A..B inclusive (e.g. 106-504).
 *                      Registry (configs/modules) is still uploaded.
 *   --skip-registry    Skip the configs_{env}/modules write.
 *
 * Examples:
 *   node scripts/firebase/upload_levels.js dev
 *   FIRESTORE_EMULATOR_HOST="localhost:8080" node scripts/firebase/upload_levels.js dev --dry-run
 *   node scripts/firebase/upload_levels.js dev --only-missing
 *   node scripts/firebase/upload_levels.js dev --range 106-504
 *   CONFIRM_PROD_UPLOAD=yes node scripts/firebase/upload_levels.js prod
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// Firestore single-document limit; warn well before it for the registry doc.
const DOC_LIMIT_BYTES = 1_048_576;
const REGISTRY_WARN_BYTES = 900_000;

// ---------------------------------------------------------------------------
// Args
// ---------------------------------------------------------------------------
const envArg = process.argv[2] || 'dev';
const env = envArg.toLowerCase();
if (!['dev', 'preview', 'prod'].includes(env)) {
  console.error(`Error: Invalid environment "${envArg}". Must be dev, preview, or prod.`);
  process.exit(1);
}

const flags = new Set(process.argv.slice(3).filter((a) => a.startsWith('--')));
const DRY_RUN = flags.has('--dry-run');
const ONLY_MISSING = flags.has('--only-missing');
const SKIP_REGISTRY = flags.has('--skip-registry');

let rangeStart = 0;
let rangeEnd = Number.MAX_SAFE_INTEGER;
const rangeFlag = process.argv.slice(3).find((a) => a.startsWith('--range'));
if (rangeFlag) {
  const m = /^--range=(\d+)-(\d+)$/.exec(rangeFlag) || /^--range$/.test(rangeFlag) && null;
  if (!m) {
    console.error('Error: --range must look like --range=106-504');
    process.exit(1);
  }
  rangeStart = parseInt(m[1], 10);
  rangeEnd = parseInt(m[2], 10);
  if (rangeStart > rangeEnd) {
    console.error('Error: --range start must be <= end');
    process.exit(1);
  }
}
for (const f of flags) {
  if (!['--dry-run', '--only-missing', '--skip-registry'].includes(f) && !f.startsWith('--range')) {
    console.error(`Error: Unknown flag "${f}".`);
    process.exit(1);
  }
}

const collectionName = `levels_${env}`;
const configsCollection = `configs_${env}`;

// Prod guard: writing levels_prod / configs_prod overwrites live game content.
// Require explicit confirmation unless talking to the local emulator.
const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
if (env === 'prod' && !usingEmulator && process.env.CONFIRM_PROD_UPLOAD !== 'yes') {
  console.error('Refusing to upload to PROD collections without confirmation.');
  console.error('Re-run with CONFIRM_PROD_UPLOAD=yes, or set FIRESTORE_EMULATOR_HOST for a dry run.');
  process.exit(1);
}
console.log(`Upload plan (levels):`);
console.log(`   Environment:   ${env}`);
console.log(`   Collection:    ${collectionName}`);
console.log(`   Registry:      ${SKIP_REGISTRY ? 'skipped' : configsCollection + '/modules'}`);
console.log(`   Mode:          ${DRY_RUN ? 'DRY RUN (no writes)' : 'live' + (usingEmulator ? ' (emulator)' : ' (cloud)')}`);
if (ONLY_MISSING) console.log(`   Resume:        skipping docs that already exist`);
if (rangeFlag) console.log(`   Range:         physical levels ${rangeStart}-${rangeEnd}`);
if (process.env.FIRESTORE_EMULATOR_HOST) {
  console.log(`   Emulator:      ${process.env.FIRESTORE_EMULATOR_HOST}`);
}

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Load + validate inputs
// ---------------------------------------------------------------------------
const repoRoot = path.resolve(__dirname, '../..');
const assetsDir = path.join(repoRoot, 'apps/parable-bloom/assets');
const modulesFile = path.join(assetsDir, 'data/modules.json');

if (!fs.existsSync(modulesFile)) {
  console.error(`Error: modules.json not found at ${modulesFile}`);
  process.exit(1);
}

let modulesData;
try {
  modulesData = JSON.parse(fs.readFileSync(modulesFile, 'utf8'));
} catch (e) {
  console.error(`Error parsing modules.json:`, e.message);
  process.exit(1);
}

if (!modulesData.level_mappings || typeof modulesData.level_mappings !== 'object') {
  console.error('Error: level_mappings missing or invalid in modules.json');
  process.exit(1);
}
if (!Array.isArray(modulesData.modules) || modulesData.modules.length === 0) {
  console.error('Error: modules[] missing or empty in modules.json');
  process.exit(1);
}

// Registry doc-size gate (single Firestore document limit).
const registryBytes = Buffer.byteLength(JSON.stringify(modulesData), 'utf8');
if (registryBytes >= DOC_LIMIT_BYTES) {
  console.error(`Error: modules registry is ${registryBytes} bytes (>= 1 MiB Firestore limit). Split before uploading.`);
  process.exit(1);
}
if (registryBytes >= REGISTRY_WARN_BYTES) {
  console.warn(`Warning: modules registry is ${registryBytes} bytes, approaching the 1 MiB limit.`);
}

// Build the upload plan: resolve every mapping to a file, enforce range,
// fail fast on unreadable JSON or oversize docs (no partial surprises later).
function levelIdFromFile(relativePath) {
  const m = /^levels\/level_(\d+)\.json$/.exec(relativePath);
  return m ? parseInt(m[1], 10) : null;
}

const plan = [];
const problems = [];
for (const [logicalKey, relativePath] of Object.entries(modulesData.level_mappings)) {
  if (logicalKey.startsWith('lesson_')) continue;
  const physicalId = levelIdFromFile(relativePath);
  if (physicalId === null) {
    problems.push(`${logicalKey}: unexpected mapping target ${relativePath}`);
    continue;
  }
  if (physicalId < rangeStart || physicalId > rangeEnd) continue;
  const absolutePath = path.join(assetsDir, relativePath);
  if (!fs.existsSync(absolutePath)) {
    problems.push(`${logicalKey}: file missing at ${absolutePath}`);
    continue;
  }
  let levelData;
  try {
    levelData = JSON.parse(fs.readFileSync(absolutePath, 'utf8'));
  } catch (e) {
    problems.push(`${logicalKey}: invalid JSON (${e.message})`);
    continue;
  }
  levelData.id = logicalKey;
  const bytes = Buffer.byteLength(JSON.stringify(levelData), 'utf8');
  if (bytes >= DOC_LIMIT_BYTES) {
    problems.push(`${logicalKey}: ${bytes} bytes >= 1 MiB limit`);
    continue;
  }
  plan.push({ logicalKey, data: levelData, bytes });
}

if (problems.length > 0) {
  console.error(`Error: ${problems.length} mapping problem(s), refusing to upload:`);
  for (const p of problems.slice(0, 20)) console.error(`   • ${p}`);
  if (problems.length > 20) console.error(`   … and ${problems.length - 20} more`);
  process.exit(1);
}
if (plan.length === 0) {
  console.error('Error: upload plan is empty (check --range).');
  process.exit(1);
}
console.log(`Plan: ${plan.length} level docs validated locally.`);

// ---------------------------------------------------------------------------
// Upload
// ---------------------------------------------------------------------------
async function existingIds() {
  // Resume support: list current doc IDs so re-runs skip completed work.
  const snap = await db.collection(collectionName).select().get();
  const ids = new Set();
  snap.forEach((doc) => ids.add(doc.id));
  return ids;
}

async function uploadAll() {
  if (!SKIP_REGISTRY) {
    console.log(`Uploading modules registry to ${configsCollection}/modules (${registryBytes} bytes)...`);
    if (DRY_RUN) {
      console.log('   (dry run: skipped)');
    } else {
      await db.collection(configsCollection).doc('modules').set(modulesData);
      console.log(`   Done.`);
    }
  }

  let queue = plan;
  if (ONLY_MISSING && !DRY_RUN) {
    const ids = await existingIds();
    const before = queue.length;
    queue = queue.filter((item) => !ids.has(item.logicalKey));
    console.log(`Resume: ${before - queue.length} docs already present, ${queue.length} to write.`);
  } else if (ONLY_MISSING && DRY_RUN) {
    console.log('Resume: --only-missing has no effect with --dry-run (no reads performed).');
  }

  if (DRY_RUN) {
    const totalBytes = queue.reduce((n, item) => n + item.bytes, 0);
    console.log(`Dry run: would write ${queue.length} docs (~${totalBytes} bytes) to ${collectionName}.`);
    console.log(`   First: ${queue[0].logicalKey}, last: ${queue[queue.length - 1].logicalKey}`);
    return;
  }

  const writer = db.bulkWriter();
  let writeErrors = 0;
  writer.onWriteError((err) => {
    // Retry transient failures up to 5 times, then record and move on.
    if (err.failedAttempts < 5 && ['unavailable', 'resource-exhausted', 'aborted'].includes(err.code)) {
      return true;
    }
    console.error(`   Failed ${err.documentRef.id} after ${err.failedAttempts} attempts: ${err.message}`);
    writeErrors++;
    return false;
  });

  let queued = 0;
  for (const item of queue) {
    writer.set(db.collection(collectionName).doc(item.logicalKey), item.data);
    queued++;
    if (queued % 100 === 0) console.log(`   Queued ${queued}/${queue.length}...`);
  }
  await writer.close();

  console.log(`\nUpload complete: ${queued - writeErrors}/${queued} docs written to ${collectionName}.`);
  if (writeErrors > 0) {
    console.error(`   ${writeErrors} doc(s) failed (see above). Re-run with --only-missing to resume.`);
    process.exit(1);
  }
}

uploadAll().catch((err) => {
  console.error('Fatal error during upload:', err);
  process.exit(1);
});
