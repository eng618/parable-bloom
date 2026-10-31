import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/settings_providers.dart';
import '../../../../core/widgets/constrained_page.dart';
import '../widgets/settings_about_section.dart';
import '../widgets/settings_account_section.dart';
import '../widgets/settings_appearance_section.dart';
import '../widgets/settings_audio_section.dart';
import '../widgets/settings_danger_section.dart';
import '../widgets/settings_data_sync_section.dart';
import '../widgets/settings_debug_section.dart';
import '../widgets/settings_scripture_section.dart';
import '../widgets/settings_section_header.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logScreenView('Settings');
    });
  }

  @override
  Widget build(BuildContext context) {
    final showDebugTools =
        kDebugMode || ref.watch(debugUiEnabledForTestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: ConstrainedPage(
        child: ListView(
          children: [
            const SizedBox(height: 16),
            const SettingsSectionHeader('Account'),
            const SettingsAccountSection(),
            const Divider(),
            const SettingsSectionHeader('Appearance'),
            const SettingsAppearanceSection(),
            const Divider(),
            const SettingsSectionHeader('Scripture'),
            const SettingsScriptureSection(),
            const Divider(),
            const SettingsSectionHeader('Audio & Haptics'),
            const SettingsAudioSection(),
            const Divider(),
            const SettingsSectionHeader('Data & Sync'),
            const SettingsDataSyncSection(),
            const Divider(),
            const SettingsSectionHeader('About'),
            const SettingsAboutSection(),
            const Divider(),
            if (showDebugTools) ...[
              const SettingsSectionHeader('Debug'),
              const SettingsDebugSection(),
              const Divider(),
            ],
            const SettingsSectionHeader('Danger Zone'),
            const SettingsDangerSection(),
          ],
        ),
      ),
    );
  }
}
