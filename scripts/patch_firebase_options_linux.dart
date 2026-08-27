// File: scripts/patch_firebase_options_linux.dart
//
// FlutterFire CLI does not support the Linux platform directly.
// This script patches apps/parable-bloom/lib/firebase_options.dart to add
// Linux platform support using the web FirebaseOptions configuration.
import 'dart:io';

void main() {
  final file = File('apps/parable-bloom/lib/firebase_options.dart');
  if (!file.existsSync()) {
    stderr.writeln('Warning: apps/parable-bloom/lib/firebase_options.dart not found.');
    return;
  }

  var content = file.readAsStringSync();

  // Replace UnsupportedError for linux with return linux;
  final linuxUnsupportedPattern = RegExp(
    r'case TargetPlatform\.linux:\s*throw UnsupportedError\([\s\S]*?\);',
    multiLine: true,
  );

  if (linuxUnsupportedPattern.hasMatch(content)) {
    content = content.replaceFirst(
      linuxUnsupportedPattern,
      'case TargetPlatform.linux:\n        return linux;',
    );
  }

  // If static const FirebaseOptions linux is not already defined, add it
  if (!content.contains('static const FirebaseOptions linux')) {
    final webOptionsMatch = RegExp(
      r'static const FirebaseOptions web = FirebaseOptions\(([\s\S]*?)\);',
    ).firstMatch(content);

    if (webOptionsMatch != null) {
      final webOptionsBody = webOptionsMatch.group(1);
      final linuxOptions =
          '\n  static const FirebaseOptions linux = FirebaseOptions($webOptionsBody);\n';
      final lastBraceIndex = content.lastIndexOf('}');
      if (lastBraceIndex != -1) {
        content =
            '${content.substring(0, lastBraceIndex)}$linuxOptions}';
      }
    } else {
      final lastBraceIndex = content.lastIndexOf('}');
      if (lastBraceIndex != -1) {
        content =
            '${content.substring(0, lastBraceIndex)}\n  static const FirebaseOptions linux = web;\n}';
      }
    }
  }

  file.writeAsStringSync(content);
  print('Successfully patched apps/parable-bloom/lib/firebase_options.dart with Linux support.');
}
