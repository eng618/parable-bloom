#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

/// Automated changelog generator for Parable Bloom
///
/// Generates changelog entries from git commits using Conventional Commits format.
///
/// Usage:
///   dart run scripts/update_changelog.dart              # Update for unreleased commits
///   dart run scripts/update_changelog.dart --dry-run    # Preview without writing
///   dart run scripts/update_changelog.dart --since v1.0.0  # Generate from specific tag
///
/// Conventional Commits Format:
///   feat: New feature
///   fix: Bug fix
///   docs: Documentation
///   style: Code style
///   refactor: Code refactoring
///   perf: Performance improvement
///   test: Tests
///   chore: Build/tooling

void main(List<String> arguments) async {
  print('📋 Parable Bloom Changelog Generator\n');

  final dryRun = arguments.contains('--dry-run');
  final sinceIndex = arguments.indexOf('--since');
  String? sinceTag;

  if (sinceIndex >= 0 && sinceIndex + 1 < arguments.length) {
    sinceTag = arguments[sinceIndex + 1];
  }

  // Check if git is available
  final gitCheck = await Process.run('git', ['--version']);
  if (gitCheck.exitCode != 0) {
    print('❌ Error: Git not available');
    exit(1);
  }

  // Find the last tag if not specified
  if (sinceTag == null) {
    final tagResult =
        await Process.run('git', ['describe', '--tags', '--abbrev=0']);
    if (tagResult.exitCode == 0) {
      sinceTag = (tagResult.stdout as String).trim();
      print('📌 Using last tag: $sinceTag\n');
    } else {
      print('⚠️  No previous tags found, using all commits\n');
      sinceTag = '';
    }
  } else {
    print('📌 Generating changelog since: $sinceTag\n');
  }

  // Get commits since tag
  // Get commits since tag using a unique delimiter for multiline handling
  const commitDelimiter = '---COMMIT_END---';
  final gitArgs = ['log', '--pretty=format:%H|%s|%b$commitDelimiter'];
  if (sinceTag.isNotEmpty) {
    gitArgs.add('$sinceTag..HEAD');
  }

  final logResult = await Process.run('git', gitArgs);
  if (logResult.exitCode != 0) {
    print('❌ Error: Failed to get git log');
    exit(1);
  }

  final rawLog = logResult.stdout as String;
  final commits = rawLog
      .split(commitDelimiter)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .map((entry) {
    final parts = entry.split('|');
    return {
      'hash': parts[0],
      'subject': parts.length > 1 ? parts[1] : '',
      'body': parts.length > 2 ? parts.sublist(2).join('|') : '',
    };
  }).toList();

  if (commits.isEmpty) {
    print('✅ No new commits since $sinceTag');
    exit(0);
  }

  print('📝 Found ${commits.length} commits\n');

  // Categorize commits
  final features = <Map<String, dynamic>>[];
  final fixes = <Map<String, dynamic>>[];
  final performance = <Map<String, dynamic>>[];
  final refactors = <Map<String, dynamic>>[];
  final docs = <Map<String, dynamic>>[];
  final tests = <Map<String, dynamic>>[];
  final chores = <Map<String, dynamic>>[];
  final other = <Map<String, dynamic>>[];
  final breaking = <Map<String, dynamic>>[];

  for (final commit in commits) {
    final subject = commit['subject'] as String;
    final body = commit['body'] as String;
    final hash = (commit['hash'] as String).substring(0, 7);

    // Skip version bump commits
    if (subject.startsWith('chore: bump version')) {
      continue;
    }

    // Check for breaking changes
    if (body.contains('BREAKING CHANGE') || subject.contains('!:')) {
      breaking.add({'text': subject, 'hash': hash});
    }

    // Categorize by type
    if (subject.startsWith('feat')) {
      features.add({'text': _cleanCommitMessage(subject), 'hash': hash});
    } else if (subject.startsWith('fix')) {
      fixes.add({'text': _cleanCommitMessage(subject), 'hash': hash});
    } else if (subject.startsWith('perf')) {
      performance.add({'text': _cleanCommitMessage(subject), 'hash': hash});
    } else if (subject.startsWith('refactor')) {
      refactors.add({'text': _cleanCommitMessage(subject), 'hash': hash});
    } else if (subject.startsWith('docs')) {
      docs.add({'text': _cleanCommitMessage(subject), 'hash': hash});
    } else if (subject.startsWith('test')) {
      tests.add({'text': _cleanCommitMessage(subject), 'hash': hash});
    } else if (subject.startsWith('chore') ||
        subject.startsWith('build') ||
        subject.startsWith('ci')) {
      chores.add({'text': _cleanCommitMessage(subject), 'hash': hash});
    } else {
      other.add({'text': subject, 'hash': hash});
    }
  }

  // Generate changelog content
  final buffer = StringBuffer();

  if (breaking.isNotEmpty) {
    buffer.writeln('### ⚠️ BREAKING CHANGES\n');
    for (final item in breaking) {
      buffer.writeln('- ${item['text']} (${item['hash']})');
    }
    buffer.writeln();
  }

  if (features.isNotEmpty) {
    buffer.writeln('### Added\n');
    for (final item in features) {
      buffer.writeln('- ${item['text']} (${item['hash']})');
    }
    buffer.writeln();
  }

  if (fixes.isNotEmpty) {
    buffer.writeln('### Fixed\n');
    for (final item in fixes) {
      buffer.writeln('- ${item['text']} (${item['hash']})');
    }
    buffer.writeln();
  }

  if (performance.isNotEmpty) {
    buffer.writeln('### Performance\n');
    for (final item in performance) {
      buffer.writeln('- ${item['text']} (${item['hash']})');
    }
    buffer.writeln();
  }

  if (refactors.isNotEmpty) {
    buffer.writeln('### Changed\n');
    for (final item in refactors) {
      buffer.writeln('- ${item['text']} (${item['hash']})');
    }
    buffer.writeln();
  }

  if (docs.isNotEmpty || tests.isNotEmpty || chores.isNotEmpty) {
    buffer.writeln('### Other\n');
    for (final item in [...docs, ...tests, ...chores]) {
      buffer.writeln('- ${item['text']} (${item['hash']})');
    }
    buffer.writeln();
  }

  if (other.isNotEmpty) {
    buffer.writeln('### Uncategorized\n');
    for (final item in other) {
      buffer.writeln('- ${item['text']} (${item['hash']})');
    }
    buffer.writeln();
  }

  final String changelogContent = buffer.toString().trim();

  if (changelogContent.isEmpty) {
    print('✅ No new categorized changes found');
    if (!dryRun) exit(0);
  }

  if (dryRun) {
    print('📄 Preview of changelog entries:\n');
    print(changelogContent);
    print('\n💡 Run without --dry-run to update CHANGELOG.md');
    exit(0);
  }

  // Update CHANGELOG.md
  final changelogFile = File('CHANGELOG.md');
  if (!changelogFile.existsSync()) {
    print('📝 Creating new CHANGELOG.md...');
    final initialContent = '''# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

$changelogContent
''';
    changelogFile.writeAsStringSync(initialContent);
    print('✅ Created CHANGELOG.md');
  } else {
    print('📝 Updating CHANGELOG.md...');
    final content = changelogFile.readAsStringSync();

    // Find or create Unreleased section
    if (content.contains('## [Unreleased]')) {
      // Update existing Unreleased section
      final lines = content.split('\n');
      final unreleasedIndex =
          lines.indexWhere((line) => line.startsWith('## [Unreleased]'));

      if (unreleasedIndex >= 0) {
        // Find next version section
        int nextVersionIndex = -1;
        for (int i = unreleasedIndex + 1; i < lines.length; i++) {
          if (lines[i].startsWith('## [')) {
            nextVersionIndex = i;
            break;
          }
        }

        // Replace content between Unreleased and next version
        final before = lines.sublist(0, unreleasedIndex + 1);
        final after = nextVersionIndex >= 0
            ? lines.sublist(nextVersionIndex)
            : <String>[];

        final newLines = [
          ...before,
          '',
          ...changelogContent.split('\n'),
          ...after,
        ];

        changelogFile.writeAsStringSync(newLines.join('\n'));
        print('✅ Updated CHANGELOG.md (Unreleased section)');
      }
    } else {
      // Add Unreleased section at the top
      final headerEnd = content.indexOf('\n## [');
      if (headerEnd >= 0) {
        final header = content.substring(0, headerEnd);
        final rest = content.substring(headerEnd);
        final newContent =
            '$header\n\n## [Unreleased]\n\n$changelogContent$rest';
        changelogFile.writeAsStringSync(newContent);
        print('✅ Updated CHANGELOG.md (added Unreleased section)');
      } else {
        print('❌ Error: Could not find insertion point in CHANGELOG.md');
        exit(1);
      }
    }
  }

  print('\n🎉 Changelog updated successfully!');
  print('\n💡 Review changes and commit:');
  print('   git add CHANGELOG.md');
  print('   git commit -m "docs: update changelog"');
}

String _cleanCommitMessage(String message) {
  // Remove type prefix (feat:, fix:, etc.)
  final cleaned = message.replaceFirst(RegExp(r'^[a-z]+(\([^)]+\))?:\s*'), '');

  // Capitalize first letter
  if (cleaned.isNotEmpty) {
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  return cleaned;
}
