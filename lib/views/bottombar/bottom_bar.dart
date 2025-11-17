// lib/views/main_navigation_screen.dart
// (This replaces your 'BottomBar' widget)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webcamo/providers/settings_provider.dart';
import 'package:webcamo/views/bottombar/bottom_bar_controller.dart';
import 'package:webcamo/views/home/home_screen.dart';
import 'package:webcamo/views/settings/settings_page.dart'; // <-- NEW
import 'package:webcamo/views/usb/usb_page.dart'; // <-- NEW

class BottomBar extends ConsumerStatefulWidget {
  const BottomBar({super.key});

  @override
  ConsumerState<BottomBar> createState() =>
      _BottomBarState();
}

class _BottomBarState extends ConsumerState<BottomBar> {
  int _currentIndex = 0;

  // Define all pages/screens here
  static final List<Widget> _pages = [
    HomeScreen(), // <-- Renamed from HomeScreen
    USBPage(),
    SettingsPage(),
  ];

  // Titles for the AppBar
  static const List<String> _titles = [
    'Webcamo',
    'USB Connection',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    // Load settings on startup
    Future.microtask(() {
      ref.read(settingsProvider.notifier).loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex]), elevation: 0),
      body: _pages[_currentIndex], // Show current page
      bottomNavigationBar: BottomBarController(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Update current index
          });
        },
      ),
    );
  }
}
