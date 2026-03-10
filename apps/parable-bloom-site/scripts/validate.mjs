#!/usr/bin/env node

import { spawn } from 'node:child_process';
import process from 'node:process';

const useFix = process.argv.includes('--fix');

const steps = [
  {
    name: 'Format',
    command: 'npm',
    args: ['run', useFix ? 'format' : 'format:ci'],
  },
  {
    name: 'Lint',
    command: 'npm',
    args: ['run', useFix ? 'lint:fix' : 'lint'],
  },
  {
    name: 'Type Check',
    command: 'npx',
    args: ['tsc', '--noEmit'],
  },
  {
    name: 'Build',
    command: 'npm',
    args: ['run', 'build'],
  },
];

const results = [];

const runStep = (step) =>
  new Promise((resolve) => {
    const startedAt = Date.now();
    const child = spawn(step.command, step.args, {
      stdio: 'inherit',
      shell: process.platform === 'win32',
    });

    child.on('close', (code) => {
      const durationMs = Date.now() - startedAt;
      resolve({
        ...step,
        code: code ?? 1,
        ok: code === 0,
        durationMs,
      });
    });

    child.on('error', () => {
      const durationMs = Date.now() - startedAt;
      resolve({
        ...step,
        code: 1,
        ok: false,
        durationMs,
      });
    });
  });

const formatDuration = (durationMs) => `${(durationMs / 1000).toFixed(1)}s`;

const printSummary = () => {
  console.log('\nValidation summary');
  console.log('------------------');

  for (const step of steps) {
    const result = results.find((r) => r.name === step.name);

    if (!result) {
      console.log(`SKIP ${step.name}`);
      continue;
    }

    const status = result.ok ? 'PASS' : 'FAIL';
    console.log(`${status} ${result.name} (${formatDuration(result.durationMs)})`);
  }

  const passedCount = results.filter((r) => r.ok).length;
  const failedCount = results.filter((r) => !r.ok).length;
  const skippedCount = steps.length - results.length;
  console.log(`\nPassed: ${passedCount}`);
  console.log(`Failed: ${failedCount}`);
  console.log(`Skipped: ${skippedCount}`);
};

const main = async () => {
  console.log(`Running validation${useFix ? ' (fix mode)' : ''}...\n`);

  for (const step of steps) {
    console.log(`==> ${step.name}`);
    const result = await runStep(step);
    results.push(result);

    if (!result.ok) {
      break;
    }
  }

  printSummary();

  const hasFailures = results.some((result) => !result.ok);
  process.exit(hasFailures ? 1 : 0);
};

void main();
