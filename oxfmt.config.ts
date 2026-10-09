import { oxfmtConfig } from "@gv-tech/oxc-config/oxfmt";
import { defineConfig, type OxfmtConfig } from "oxfmt";

/**
 * Oxfmt configuration for the workspace root (docs, configs, workflows). The Next.js site owns its own config at
 * apps/parable-bloom-site/. See: https://github.com/Garcia-Ventures/oxc-config
 */
export default defineConfig({
  ...(oxfmtConfig as OxfmtConfig),
  ignorePatterns: [
    ...(oxfmtConfig.ignorePatterns ?? []),
    // Next.js site has its own oxfmt config + lint-staged.
    "apps/parable-bloom-site/**",
    // Dart/Flutter artifacts oxfmt must not rewrite.
    "**/.dart_tool/**",
    "**/.pub/**",
    "**/.pub-cache/**",
    "**/ios/Pods/**",
    "**/ios/.symlinks/**",
    "**/macos/Pods/**",
    "**/macos/.symlinks/**",
    "**/pubspec.lock",
    // Go/build artifacts.
    "**/.gocache/**",
    "**/.gotmp/**",
    "tools/level-builder/level-builder",
    "tools/level-builder/validation_stats*",
    "tools/level-builder/assets/**",
    // Go test fixtures are byte-sensitive inputs for the solver tests.
    "tools/level-builder/test/fixtures/**",
    // Xcode asset catalogs and Flutter web boilerplate are tool-owned.
    "**/*.appiconset/**",
    "**/*.imageset/**",
    "apps/parable-bloom/assets/**",
    "apps/parable-bloom/web/**",
    // Misc caches and outputs.
    "**/.task/**",
    "**/coverage.out",
    "**/dist/**",
  ],
});
