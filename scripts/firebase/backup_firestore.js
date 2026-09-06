/**
 * scripts/firebase/backup_firestore.js
 *
 * Logical backup of game collections to local JSON (no Cloud Storage billing
 * required — `gcloud firestore export` needs a bucket; this project has
 * billing disabled). Run before any prod write so rollback is possible.
 *
 * Backs up levels_{env} (all docs), configs_{env}/modules,
 * configs_{env}/biblical_themes, and scriptures_{env} (+translations
 * subcollections) into backups/<env>-<timestamp>/.
 *
 * Rollback: level/registry/theme content is git-versioned (re-checkout +
 * re-upload); this dump additionally preserves exact prod state, including
 * docs no longer present locally (e.g. pre-migration IDs).
 *
 * Usage:
 *   node scripts/firebase/backup_firestore.js <env>
 *   FIRESTORE_EMULATOR_HOST="localhost:8080" node scripts/firebase/backup_firestore.js dev
 *   CONFIRM_PROD_BACKUP=yes node scripts/firebase/backup_firestore.js prod
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const envArg = process.argv[2];
const env = (envArg || '').toLowerCase();
if (!['dev', 'preview', 'prod'].includes(env)) {
  console.error('Error: env is required. Usage: node scripts/firebase/backup_firestore.js <dev|preview|prod>');
  process.exit(1);
}

const usingEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
if (env === 'prod' && !usingEmulator && process.env.CONFIRM_PROD_BACKUP !== 'yes') {
  console.error('Refusing to read PROD collections without confirmation.');
  console.error('Re-run with CONFIRM_PROD_BACKUP=yes (reads only, no writes).');
  process.exit(1);
}

try {
  admin.initializeApp({ projectId: 'parable-bloom' });
} catch (e) {
  console.error('Error initializing Firebase Admin SDK:', e.message);
  process.exit(1);
}

// firebase-admin v14 removed admin.firestore(); v13 and earlier have it.
const db =
  typeof admin.firestore === 'function'
    ? admin.firestore()
    : require('firebase-admin/firestore').getFirestore();

const stamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
const outDir = path.resolve(__dirname, '..', '..', 'backups', `${env}-${stamp}`);
fs.mkdirSync(outDir, { recursive: true });

async function dumpCollection(collName, fileName) {
  const snap = await db.collection(collName).get();
  const docs = {};
  snap.forEach((doc) => {
    docs[doc.id] = doc.data();
  });
  fs.writeFileSync(path.join(outDir, fileName), JSON.stringify(docs, null, 2));
  return Object.keys(docs).length;
}

async function dumpScriptures() {
  const collName = `scriptures_${env}`;
  // Passage parent docs may not exist (translations live in subcollections),
  // so discover passage IDs through the translations collection group.
  const group = await db.collectionGroup('translations').get();
  const passageIds = new Set();
  group.forEach((t) => {
    const parent = t.ref.parent.parent;
    if (parent && parent.parent && parent.parent.id === collName) {
      passageIds.add(parent.id);
    }
  });
  const docs = {};
  for (const pid of passageIds) {
    const ref = db.collection(collName).doc(pid);
    const snap = await ref.get();
    docs[pid] = snap.exists ? { ...snap.data() } : {};
    const subs = await ref.collection('translations').get();
    docs[pid].translations = {};
    subs.forEach((t) => {
      docs[pid].translations[t.id] = t.data();
    });
  }
  fs.writeFileSync(path.join(outDir, 'scriptures.json'), JSON.stringify(docs, null, 2));
  return Object.keys(docs).length;
}

async function main() {
  console.log(`Backing up ${env} collections to ${outDir} ...`);
  const levels = await dumpCollection(`levels_${env}`, 'levels.json');
  console.log(`   levels_${env}: ${levels} docs`);
  const configs = await dumpCollection(`configs_${env}`, 'configs.json');
  console.log(`   configs_${env}: ${configs} docs`);
  let scriptures = 0;
  try {
    scriptures = await dumpScriptures();
    console.log(`   scriptures_${env}: ${scriptures} passages`);
  } catch (e) {
    console.warn(`   scriptures_${env}: skipped (${e.message})`);
  }
  const manifest = { env, stamp, levels, configs, scriptures };
  fs.writeFileSync(path.join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
  console.log('Backup complete. To roll back prod content, re-upload from git + this dump.');
}

main().catch((err) => {
  console.error('Fatal error during backup:', err);
  process.exit(1);
});
