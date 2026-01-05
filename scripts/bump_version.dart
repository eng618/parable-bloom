#!/usr/bin/env dart

import 'dart:io';
import 'package:yaml/yaml.dart';

/// Automated version bumping script for Parable Bloom
///
/// Usage:
///   dart run scripts/bump_version.dart --major    # 1.0.0+1 → 2.0.0+2
///   dart run scripts/bump_version.dart --minor    # 1.0.0+1 → 1.1.0+2
///   dart run scripts/bump_version.dart --patch    # 1.0.0+1 → 1.0.1+2
///   dart run scripts/bump_version.dart --build    # 1.0.0+1 → 1.0.0+2
///   dart run scripts/bump_version.dart --set 2.0.0+5  # Set specific version
///
/// Options:
///   --dry-run    Preview changes without writing files
///   --no-commit  Skip git commit and tag
///   --no-changelog Skip changelog update

void main(List<String> arguments) async {
  // Parse arguments
  if (arguments.isEmpty || arguments.contains('--help')) {
    printUsage();
    exit(0);
  }

  final bumpType = arguments.firstWhere(
    (arg) =>
        ['--major', '--minor', '--patch', '--build', '--set'].contains(arg),
    orElse: () => '',
  );

  if (bumpType.isEmpty) {
    print(
        '❌ Error: Must specify bump type (--major, --minor, --patch, --build, or --set)');
    printUsage();
    exit(1);
  }

  final dryRun = arguments.contains('--dry-run');
  final noCommit = arguments.contains('--no-commit');
  final noChangelog = arguments.contains('--no-changelog');

  String? customVersion;
  if (bumpType == '--set') {
    final setIndex = arguments.indexOf('--set');
    if (setIndex + 1 >= arguments.length) {
      print('❌ Error: --set requires a version argument');
      exit(1);
    }
    customVersion = arguments[setIndex + 1];
  }

  print('🚀 Parable Bloom Version Bumper\n');

  // Read current version from pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('❌ Error: pubspec.yaml not found. Run from project root.');
    exit(1);
  }

  final pubspecContent = pubspecFile.readAsStringSync();
  final pubspec = loadYaml(pubspecContent) as Map;
  final currentVersion = pubspec['version'] as String;
  final currentSemanticOnly = currentVersion.split('+').first;

  print('📦 Current version: $currentVersion');

  // Parse version
  final versionParts = currentVersion.split('+');
  if (versionParts.length != 2) {
    print('❌ Error: Invalid version format. Expected: X.Y.Z+BUILD');
    exit(1);
  }

  final semanticVersion = versionParts[0].split('.');
  if (semanticVersion.length != 3) {
    print('❌ Error: Invalid semantic version. Expected: MAJOR.MINOR.PATCH');
    exit(1);
  }

  int major = int.parse(semanticVersion[0]);
  int minor = int.parse(semanticVersion[1]);
  int patch = int.parse(semanticVersion[2]);
  int build = int.parse(versionParts[1]);

  // Calculate new version
  String newVersion;
  if (customVersion != null) {
    newVersion = customVersion;
    print('🎯 Setting version to: $newVersion');
  } else {
    switch (bumpType) {
      case '--major':
        major++;
        minor = 0;
        patch = 0;
        build++;
        break;
      case '--minor':
        minor++;
        patch = 0;
        build++;
        break;
      case '--patch':
        patch++;
        build++;
        break;
      case '--build':
        build++;
        break;
    }

    newVersion = '$major.$minor.$patch+$build';
    final bumpName = bumpType.replaceAll('--', '').toUpperCase();
    print('⬆️  Bumping $bumpName version to: $newVersion');
  }

  final newSemanticOnly = newVersion.split('+').first;

  // Tag full version (including build number) so build-only bumps can be tagged uniquely.
  // Example: 1.0.0+2 => v1.0.0+2
  final tagName = 'v$newVersion';

  if (newVersion == currentVersion) {
    print('⚠️  Warning: New version is same as current version');
  }

  // Update pubspec.yaml
  final newPubspecContent = pubspecContent.replaceFirst(
    RegExp(r'version:\s*' + RegExp.escape(currentVersion)),
    'version: $newVersion',
  );

  if (dryRun) {
    print('\n📝 DRY RUN - Would make the following changes:\n');
    print('1. Update pubspec.yaml: $currentVersion → $newVersion');
    if (!noChangelog) {
      print('2. Update CHANGELOG.md with new version section');
    }
    if (!noCommit) {
      print('3. Create git commit: "chore: bump version to $newVersion"');
      print('4. Create git tag: $tagName');
    }
    exit(0);
  }

  // Write updated pubspec.yaml
  print('\n📝 Updating pubspec.yaml...');
  pubspecFile.writeAsStringSync(newPubspecContent);
  print('✅ Updated pubspec.yaml');

  // Update changelog
  if (!noChangelog) {
    print('\n📋 Updating CHANGELOG.md...');
    final changelogUpdated = await updateChangelog(newVersion);
    if (changelogUpdated) {
      print('✅ Updated CHANGELOG.md');
    } else {
      print('⚠️  CHANGELOG.md not found or update failed');
    }
  }

  // Git operations
  if (!noCommit) {
    print('\n🔄 Creating git commit and tag...');

    // Check if git is available
    final gitCheck = await Process.run('git', ['--version']);
    if (gitCheck.exitCode != 0) {
      print('⚠️  Git not available, skipping commit and tag');
    } else {
      // Check for uncommitted changes
      final statusResult = await Process.run('git', ['status', '--porcelain']);
      final hasChanges = (statusResult.stdout as String).trim().isNotEmpty;

      if (hasChanges) {
        // Add files
        await Process.run('git', ['add', 'pubspec.yaml']);
        if (!noChangelog && File('CHANGELOG.md').existsSync()) {
          await Process.run('git', ['add', 'CHANGELOG.md']);
        }

        // Commit
        final commitMsg = 'chore: bump version to $newVersion';
        final commitResult =
            await Process.run('git', ['commit', '-m', commitMsg]);
        if (commitResult.exitCode == 0) {
          print('✅ Created commit: "$commitMsg"');
        } else {
          print('❌ Failed to create commit: ${commitResult.stderr}');
        }

        // Create tag
        final tagResult = await Process.run('git', ['tag', tagName]);
        if (tagResult.exitCode == 0) {
          print('✅ Created tag: $tagName');
        } else {
          print('❌ Failed to create tag: ${tagResult.stderr}');
        }

        print('\n🎉 Version bump complete!');
        print('\nNext steps:');
        print('  1. Review changes: git log -1 --stat');
        print('  2. Push to remote: git push origin develop --tags');
        print('  3. Create PR: develop → main');
      } else {
        print('⚠️  No changes detected, skipping commit');
      }
    }
  } else {
    print('\n✅ Version updated in pubspec.yaml');
    print('\n📝 Manual steps required:');
    print('  1. Commit changes: git add pubspec.yaml CHANGELOG.md');
    print(
        '  2. Create commit: git commit -m "chore: bump version to $newVersion"');
    print('  3. Create tag: git tag $tagName');
    print('  4. Push: git push origin develop --tags');
  }
}

Future<bool> updateChangelog(String newVersion) async {
  final changelogFile = File('CHANGELOG.md');
  if (!changelogFile.existsSync()) {
    return false;
  }

  final content = changelogFile.readAsStringSync();
  final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD

  // Extract semantic version (without build number)
  final semanticVersion = newVersion.split('+')[0];

  // Check if version already exists
  if (content.contains('## [$semanticVersion]')) {
    print('⚠️  Version $semanticVersion already exists in CHANGELOG.md');
    return true;
  }

  // Find insertion point (after # Changelog header and before first ## version)
  final lines = content.split('\n');
  int insertIndex = -1;

  for (int i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('## [') || lines[i].startsWith('## Unreleased')) {
      insertIndex = i;
      break;
    }
  }

  if (insertIndex == -1) {
    // If no versions found, insert after header
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim().isNotEmpty && !lines[i].startsWith('#')) {
        insertIndex = i;
        break;
      }
    }
  }

  final newSection = '''

## [$semanticVersion] - $today

### Added
- TODO: Document new features

### Changed
- TODO: Document changes

### Fixed
- TODO: Document bug fixes
''';

  if (insertIndex >= 0) {
    lines.insert(insertIndex, newSection);
  } else {
    lines.add(newSection);
  }

  changelogFile.writeAsStringSync(lines.join('\n'));
  return true;
}

void printUsage() {
  print('''
Parable Bloom Version Bumper

Usage:
  dart run scripts/bump_version.dart <type> [options]

Version Types:
  --major     Bump major version (1.0.0+1 → 2.0.0+2)
  --minor     Bump minor version (1.0.0+1 → 1.1.0+2)
  --patch     Bump patch version (1.0.0+1 → 1.0.1+2)
  --build     Bump build number only (1.0.0+1 → 1.0.0+2)
  --set X.Y.Z+N   Set specific version

Options:
  --dry-run       Preview changes without writing
  --no-commit     Skip git commit and tag
  --no-changelog  Skip CHANGELOG.md update
  --help          Show this help message

Examples:
  dart run scripts/bump_version.dart --patch
  dart run scripts/bump_version.dart --minor --dry-run
  dart run scripts/bump_version.dart --set 2.0.0+5
''');
}
