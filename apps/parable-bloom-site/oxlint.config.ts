import { next } from '@gv-tech/oxc-config/next';
import { defineConfig } from 'oxlint';

/**
 * Oxlint configuration for Next.js projects. Uses @gv-tech/oxc-config for sensible defaults. For more information on
 * configuration options, see: https://github.com/Garcia-Ventures/oxc-config
 */
export default defineConfig({
  extends: [next],
  rules: {
    // Next.js + React 19 always use the automatic JSX runtime, so `React`
    // never needs to be in scope. This was the bulk of the warnings.
    'react/react-in-jsx-scope': 'off',
    // Intentional diagnostic logging stays allowed; stray console.log is
    // still flagged.
    'eslint/no-console': ['warn', { allow: ['debug', 'warn', 'error'] }],
  },
  overrides: [
    {
      // CLI scripts report progress via stdout; console is the point.
      files: ['scripts/**/*.mjs'],
      rules: { 'eslint/no-console': 'off' },
    },
    {
      // Global stylesheet import is intentionally side-effectful.
      files: ['app/layout.tsx'],
      rules: { 'import/no-unassigned-import': 'off' },
    },
  ],
});
