/**
 * scripts/firebase/upload_levels.js
 * 
 * Utility script to batch-upload generated level JSON files from local assets
 * to Cloud Firestore levels collections (levels_dev, levels_preview, levels_prod).
 * 
 * Usage:
 *   node scripts/firebase/upload_levels.js <env>
 * 
 * Examples:
 *   # Upload to levels_dev
 *   node scripts/firebase/upload_levels.js dev
 * 
 *   # Upload to levels_dev using local emulator
 *   FIRESTORE_EMULATOR_HOST="localhost:8080" node scripts/firebase/upload_levels.js dev
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// 1. Resolve environment & collection names
const envArg = process.argv[2] || 'dev';
const env = envArg.toLowerCase();
if (!['dev', 'preview', 'prod'].includes(env)) {
  console.error(`Error: Invalid environment "${envArg}". Must be dev, preview, or prod.`);
  process.exit(1);
}

const collectionName = `levels_${env}`;
console.log(`🚀 Starting level upload process...`);
console.log(`   Environment:   ${env}`);
console.log(`   Collection:    ${collectionName}`);
if (process.env.FIRESTORE_EMULATOR_HOST) {
  console.log(`   Emulator:      Using local Firestore emulator at ${process.env.FIRESTORE_EMULATOR_HOST}`);
} else {
  console.log(`   Cloud:         Using active Firebase credentials (ADC or GOOGLE_APPLICATION_CREDENTIALS)`);
}

// 2. Initialize Firebase Admin SDK
// admin.initializeApp() will pick up either FIRESTORE_EMULATOR_HOST or GOOGLE_APPLICATION_CREDENTIALS automatically
try {
  admin.initializeApp({
    projectId: 'parable-bloom'
  });
} catch (e) {
  console.error('Error initializing Firebase Admin SDK:', e.message);
  process.exit(1);
}

const db = admin.firestore();

// 3. Resolve paths
const repoRoot = path.resolve(__dirname, '../..');
const assetsDir = path.join(repoRoot, 'apps/parable-bloom/assets');
const modulesFile = path.join(assetsDir, 'data/modules.json');

if (!fs.existsSync(modulesFile)) {
  console.error(`Error: modules.json not found at ${modulesFile}`);
  process.exit(1);
}

// 4. Read modules.json and extract level mappings
let modulesData;
try {
  const content = fs.readFileSync(modulesFile, 'utf8');
  modulesData = JSON.parse(content);
} catch (e) {
  console.error(`Error parsing modules.json:`, e.message);
  process.exit(1);
}

const mappings = modulesData.level_mappings;
if (!mappings) {
  console.error('Error: level_mappings not found in modules.json');
  process.exit(1);
}

// 5. Upload levels in batch
async function uploadAll() {
  const configsCollection = `configs_${env}`;
  console.log(`📤 Uploading modules registry to ${configsCollection}/modules...`);
  try {
    await db.collection(configsCollection).doc('modules').set(modulesData);
    console.log(`   ✅ Modules registry uploaded successfully.`);
  } catch (e) {
    console.error(`   ❌ Failed to upload modules registry:`, e.message);
    process.exit(1);
  }

  const levelKeys = Object.keys(mappings).filter(key => !key.startsWith('lesson_'));
  console.log(`📦 Found ${levelKeys.length} gameplay levels to upload.`);

  let successCount = 0;
  let errorCount = 0;

  for (const logicalKey of levelKeys) {
    const relativePath = mappings[logicalKey];
    const absolutePath = path.join(assetsDir, relativePath);

    if (!fs.existsSync(absolutePath)) {
      console.warn(`⚠️ Warning: Level file not found for ${logicalKey} at ${absolutePath}. Skipping.`);
      errorCount++;
      continue;
    }

    try {
      const fileContent = fs.readFileSync(absolutePath, 'utf8');
      const levelData = JSON.parse(fileContent);

      // Add logical ID directly into the stored document data for ease of querying
      levelData.id = logicalKey;

      // Write to Firestore using the logical key as the document ID
      const docRef = db.collection(collectionName).doc(logicalKey);
      await docRef.set(levelData);

      console.log(`   ✅ Uploaded: ${logicalKey} (${relativePath})`);
      successCount++;
    } catch (e) {
      console.error(`   ❌ Failed to upload ${logicalKey}:`, e.message);
      errorCount++;
    }
  }

  console.log(`\n🎉 Upload process completed!`);
  console.log(`   Successfully uploaded:  ${successCount}`);
  console.log(`   Failed/Skipped:         ${errorCount}`);
  
  if (errorCount > 0) {
    process.exit(1);
  } else {
    process.exit(0);
  }
}

uploadAll().catch(err => {
  console.error('Fatal error during upload:', err);
  process.exit(1);
});
