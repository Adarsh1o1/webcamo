// lib/views/main_navigation_screen.dart
// (This replaces your 'BottomBar' widget)

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webcamo/providers/settings_provider.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/sizes.dart';
import 'package:webcamo/views/bottombar/bottom_bar_controller.dart';
import 'package:webcamo/views/home/home_screen.dart';
import 'package:webcamo/views/home_page.dart';
import 'package:webcamo/views/settings/settings_page.dart'; // <-- NEW
import 'package:webcamo/views/usb/usb_page.dart'; // <-- NEW
import 'package:url_launcher/url_launcher.dart';

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
  static const List<String> _titles = ['Webcamo', 'USB Connection', 'Settings'];



  @override
  void initState() {
    super.initState();
    // Load settings on startup
    Future.microtask(() {
      ref.read(settingsProvider.notifier).loadSettings();
    });
  }

    Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    launchUrl(url);
    // if (!await ) {
    //   _showErrorDialog('Could not launch $urlString');
    // }
  }

  void _showHelpDialog(BuildContext context) {
    // We get the colors from the theme
    final ColorScheme colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'How to Use Webcamo',
          style: TextStyle(
            fontSize: AppSizes.font_lg,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 60.w,
          height: 300.h,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '1. Start the Server',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Tap on Start Server to start the server. Wait until the app shows the WiFi IP.\n',
                  style: TextStyle(color: MyColors.grey),
                ),
                const Text(
                  '2. Connect on PC',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'On your PC, open the Webcamo Desktop Application. Enter the WiFi IP displayed on your phone and click connect.\n',
                  style: TextStyle(color: MyColors.grey),
                ),
                const Text(
                  'Note: Phone and PC must be on the same Local Wi-Fi network only.\n',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                // const Text(
                //   'On your PC, open the Webcamo Desktop Application. Enter the WiFi IP displayed on your phone and click connect.\n',
                // ),
                const Text(
                  '3. Voila! ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                // --- THIS IS THE NEW PART ---
                RichText(
                  text: TextSpan(
                    // Use the default text style from the dialog
                    style: Theme.of(context).dialogTheme.contentTextStyle,
                    children: [
                      TextSpan(
                        text:
                            'Open any app (Zoom, OBS, Discord, Google, Meet, etc.). Thank you for using Webcamo! If you find it useful, consider supporting me by ',
                        style: TextStyle(
                          color: colors
                              .onSurface, // This will be black in light mode and white in dark mode
                        ),
                      ),
                      TextSpan(
                        text: 'Buying me a Coffee.',
                        style: TextStyle(
                          color: colors.primary, // Make it look like a link
                          decoration: TextDecoration.underline,
                        ),
                        // This makes the text tappable
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            // Open the link when tapped
                            _launchURL(
                              'https://www.buymeacoffee.com/adarsh1o1',
                            );
                          },
                      ),
                    ],
                  ),
                ),
                // --- END OF NEW PART ---
              ],
            ),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              'Got it!',
              style: TextStyle(
                fontSize: AppSizes.font_md,
                fontWeight: FontWeight.bold,
                color: MyColors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // titleSpacing: 0,
        // Use a subtle background color that's slightly
        // different from the scaffold's background
        // ignore: deprecated_member_use
        backgroundColor:  MyColors.backgund,
        elevation: 1, // Add a very subtle shadow
        title: Text(_titles[_currentIndex],
         style: TextStyle(
                fontSize: AppSizes.font_lg,
                fontWeight: FontWeight.bold,
              ),),
        // elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              _showHelpDialog(context);
            },
            icon: const Icon(Icons.help_outline_rounded),
          ),
         const SizedBox(width: 8), 
        ],
      ),
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
