// lib/views/settings/settings_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webcamo/providers/settings_provider.dart';
import 'package:webcamo/utils/colors.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context,WidgetRef ref) {
    return Scaffold(
      backgroundColor: MyColors.lightColorScheme.primary,
      body: const Center(
        child: Text('Coming soon...'),
      ),
    );
  }


  // @override
  // Widget build(BuildContext context, WidgetRef ref) {
  //   final isDarkMode = ref.watch(isDarkModeProvider);
  //   final autoConnect = ref.watch(autoConnectProvider);
  //   final videoQuality = ref.watch(videoQualityProvider);

  //   return Padding(
  //     padding: const EdgeInsets.all(16),
  //     child: Column(
  //       children: [
  //         SwitchListTile(
  //           title: const Text('Dark Mode'),
  //           value: isDarkMode,
  //           onChanged: (value) {
  //             ref.read(settingsProvider.notifier).setDarkMode(value);
  //           },
  //         ),
  //         SwitchListTile(
  //           title: const Text('Auto Connect'),
  //           value: autoConnect,
  //           onChanged: (value) {
  //             ref.read(settingsProvider.notifier).setAutoConnect(value);
  //           },
  //         ),
  //         ListTile(
  //           title: const Text('Video Quality'),
  //           subtitle: Text(videoQuality),
  //           onTap: () => _showQualityDialog(context, ref),
  //         ),
  //       ],
  //     ),
  //   );
  // }




  void _showQualityDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Quality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['low', 'medium', 'high']
              .map(
                (q) => ListTile(
                  title: Text(q),
                  onTap: () {
                    ref.read(settingsProvider.notifier).setVideoQuality(q);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
