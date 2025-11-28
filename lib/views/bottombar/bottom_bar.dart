// lib/views/main_navigation_screen.dart
// (This replaces your 'BottomBar' widget)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webcamo/providers/server_provider.dart';
import 'package:webcamo/providers/settings_provider.dart';
import 'package:webcamo/providers/usb_provider.dart';
import 'package:webcamo/utils/sizes.dart';
import 'package:webcamo/views/bottombar/bottom_bar_controller.dart';
import 'package:webcamo/views/home_page.dart';
import 'package:webcamo/views/settings/settings_page.dart'; // <-- NEW
import 'package:webcamo/views/usb/usb_page.dart'; // <-- NEW

class BottomBar extends ConsumerStatefulWidget {
  const BottomBar({super.key});

  @override
  ConsumerState<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends ConsumerState<BottomBar> {
  int _currentIndex = 0;

  // Define all pages/screens here
  static final List<Widget> _pages = [
    HomePage(), // <-- Renamed from HomeScreen
    USBPage(),
    SettingsPage(),
  ];

  // Titles for the AppBar
  static const List<String> _titles = [
    'Webcamo',
    'USB Connection',
    'More Info',
  ];

  @override
  void initState() {
    super.initState();
    // Load settings on startup
    Future.microtask(() {
      ref.read(settingsProvider.notifier).loadSettings();
    });
  }

  Future<bool> _showServerWarningDialog({required bool isUsb}) async {
    final title = isUsb ? 'Streaming Active' : 'Server Running';
    final content =
        isUsb
            ? 'USB streaming is currently active. Navigating away will stop the stream.\n\nAre you sure?'
            : 'The server is currently active. Navigating away will stop the server and disconnect any connected devices.\n\nAre you sure?';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (isUsb) {
                    // Stop USB streaming
                    // The actual stopping happens when the widget is disposed,
                    // but we can also explicitly update the provider if needed,
                    // though navigation will trigger dispose of UsbStreamingPage.
                    // However, to be safe and consistent with Home page logic:
                    ref.read(usbProvider.notifier).setStreaming(false);
                  } else {
                    ref.read(serverProvider.notifier).stopServer();
                  }
                  Navigator.of(context).pop(true);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Stop & Leave'),
              ),
            ],
          ),
    );

    return result ?? false;
  }

  Future<void> _handleNavigation(int newIndex) async {
    // If trying to leave home page and server is running
    if (_currentIndex == 0 && newIndex != 0) {
      final isServerRunning = ref.read(isServerRunningProvider);

      if (isServerRunning) {
        // Show confirmation dialog
        final shouldProceed = await _showServerWarningDialog(isUsb: false);

        if (shouldProceed) {
          // User confirmed - stop server and cleanup
          if (mounted) {
            setState(() {
              _currentIndex = newIndex;
            });
          }
        }
        // If user cancels, stay on home page (do nothing)
        return;
      }
    }

    // If trying to leave USB page and streaming is active
    if (_currentIndex == 1 && newIndex != 1) {
      final isUsbStreaming = ref.read(isUsbStreamingProvider);

      if (isUsbStreaming) {
        // Show confirmation dialog
        final shouldProceed = await _showServerWarningDialog(isUsb: true);

        if (shouldProceed) {
          // User confirmed - stop streaming and cleanup
          if (mounted) {
            setState(() {
              _currentIndex = newIndex;
            });
          }
        }
        // If user cancels, stay on USB page (do nothing)
        return;
      }
    }

    if (mounted) {
      setState(() {
        _currentIndex = newIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // titleSpacing: 0,
        // Use a subtle background color that's slightly
        // different from the scaffold's background
        // ignore: deprecated_member_use
        backgroundColor: Color(0xff121212),
        elevation: 1, // Add a very subtle shadow
        title: Text(
          _titles[_currentIndex],
          style: TextStyle(
            fontSize: AppSizes.font_lg,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _pages[_currentIndex], // Show current page
      bottomNavigationBar: BottomBarController(
        currentIndex: _currentIndex,
        onTap: _handleNavigation,
      ),
    );
  }
}
