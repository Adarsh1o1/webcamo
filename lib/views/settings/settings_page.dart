// lib/views/settings/settings_page.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/sizes.dart';
import 'package:webcamo/utils/strings.dart';
import 'package:webcamo/utils/url_launcher.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Local State
  // bool _autoConnect = false;
  // bool _noiseReduction = false;
  // String _videoQuality = 'High (1080p)';
  // String _fps = '30 FPS';

  // Dark Mode Colors (Hardcoded for now since Dark Mode is forced)
  final Color _darkBackground = const Color(0xFF121212);
  final Color _darkSurface = const Color(0xFF1E1E1E);
  final Color _textPrimary = const Color(0xFFFFFFFF);
  // final Color _textSecondary = const Color(0xFFB3B3B3);

  // void _handleFeatureComingSoon(String featureName) {
  //   ScaffoldMessenger.of(context).clearSnackBars();
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(
  //         '$featureName feature coming in the next update!',
  //         style: TextStyle(color: _darkBackground, fontWeight: FontWeight.bold),
  //       ),
  //       backgroundColor: MyColors.grey,
  //       duration: const Duration(seconds: 1),
  //       behavior: SnackBarBehavior.floating,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //     ),
  //   );
  // }

  void _showHelpDialog(BuildContext context) {
    // We get the colors from the theme
    final ColorScheme colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'How to Use Eazycam',
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
                  'On your PC, open the Eazycam Desktop Application. Enter the WiFi IP displayed on your phone and click connect.\n',
                  style: TextStyle(color: MyColors.grey),
                ),
                const Text(
                  'Note: Phone and PC must be on the same Local Wi-Fi network only.\n',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                // const Text(
                //   'On your PC, open the Eazycam Desktop Application. Enter the WiFi IP displayed on your phone and click connect.\n',
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
                            'Open any app (Zoom, OBS, Discord, Google, Meet, etc.). Thank you for using Eazycam! If you find it useful, consider supporting me by ',
                        style: TextStyle(
                          color: colors
                              .onSurface, // This will be black in light mode and white in dark mode
                        ),
                      ),
                      TextSpan(
                        text: 'Support us!',
                        style: TextStyle(
                          color: colors.primary, // Make it look like a link
                          decoration: TextDecoration.underline,
                        ),
                        // This makes the text tappable
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            // Open the link when tapped
                            UrlLauncherUtil.launchInAppView(
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
      backgroundColor: _darkBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.p16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: CONNECTION ---
            SizedBox(height: 8.h),
            _SectionHeader(title: 'INFORMATION', color: MyColors.grey),
            SizedBox(height: 8.h),
            _SettingsGroup(
              backgroundColor: _darkSurface,
              children: [
                _ActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'How to use Eazycam',
                  value: '',
                  textColor: _textPrimary,
                  onTap: () => _showHelpDialog(context),
                ),
              ],
            ),

            // SizedBox(height: 8.h),
            // _SettingsGroup(
            //   backgroundColor: _darkSurface,
            //   children: [
            //     _SwitchTile(
            //       icon: Icons.wifi_tethering,
            //       title: 'Auto Connect',
            //       subtitle: 'Connect when PC is found',
            //       value: _autoConnect,
            //       textColor: _textPrimary,
            //       subTextColor: _textSecondary,
            //       onChanged: (val) {
            //         // setState(() => _autoConnect = val);
            //         _handleFeatureComingSoon("Auto Connect");
            //       },
            //     ),
            //     _CustomDivider(color: _darkBackground),
            //     _ActionTile(
            //       icon: Icons.computer,
            //       title: 'Target PC IP',
            //       value: '192.168.1.12',
            //       textColor: _textPrimary,
            //       onTap: () => _handleFeatureComingSoon("Manual IP Entry"),
            //     ),
            //   ],
            // ),

            // SizedBox(height: 24.h),

            // // --- SECTION 2: VIDEO & AUDIO ---
            // _SectionHeader(title: 'VIDEO & AUDIO', color: MyColors.grey),
            // SizedBox(height: 8.h),
            // _SettingsGroup(
            //   backgroundColor: _darkSurface,
            //   children: [
            //     _ActionTile(
            //       icon: Icons.high_quality_rounded,
            //       title: 'Video Quality',
            //       value: _videoQuality,
            //       textColor: _textPrimary,
            //       onTap: () => _handleFeatureComingSoon("Video Quality"),
            //       // onTap: () => _showSelectionSheet(
            //       //   title: 'Video Quality',
            //       //   options: [
            //       //     'Low (480p)',
            //       //     'Medium (720p)',
            //       //     'High (1080p)',
            //       //     'Ultra (4K)',
            //       //   ],
            //       //   currentValue: _videoQuality,
            //       //   onSelected: (val) => setState(() => _videoQuality = val),
            //       //   context: context,
            //       // ),
            //     ),
            //     _CustomDivider(color: _darkBackground),
            //     _ActionTile(
            //       icon: Icons.speed_rounded,
            //       title: 'Frame Rate',
            //       value: _fps,
            //       textColor: _textPrimary,
            //       onTap: () => _handleFeatureComingSoon("Frame Rate"),
            //       // onTap: () => _showSelectionSheet(
            //       //   context: context,
            //       //   title: 'Frame Rate',
            //       //   options: ['24 FPS', '30 FPS', '60 FPS'],
            //       //   currentValue: _fps,
            //       //   onSelected: (val) => setState(() => _fps = val),
            //       // ),
            //     ),
            //     _CustomDivider(color: _darkBackground),
            //     _SwitchTile(
            //       icon: Icons.graphic_eq_rounded,
            //       title: 'Noise Reduction',
            //       subtitle: 'Filter background noise',
            //       value: _noiseReduction,
            //       textColor: _textPrimary,
            //       subTextColor: _textSecondary,
            //       onChanged: (val) {
            //         // setState(() => _noiseReduction = val);
            //         _handleFeatureComingSoon("Audio processing");
            //       },
            //       // onChanged: (_) => _handleFeatureComingSoon("Audio processing"),
            //     ),
            //   ],
            // ),
            SizedBox(height: 24.h),

            // --- SECTION 3: SUPPORT & INFO ---
            _SectionHeader(title: 'SUPPORT', color: MyColors.grey),
            SizedBox(height: 8.h),
            _SettingsGroup(
              backgroundColor: _darkSurface,
              children: [
                _ActionTile(
                  icon: Icons.help_outline_rounded,
                  title: 'FAQs',
                  value: '',
                  textColor: _textPrimary,
                  onTap: () => UrlLauncherUtil.launchInAppView("FAQs Page"),
                ),
                _CustomDivider(color: _darkBackground),
                _ActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  value: '',
                  textColor: _textPrimary,
                  onTap: () => UrlLauncherUtil.launchInAppView("Privacy Policy"),
                ),
                _CustomDivider(color: _darkBackground),
                _ActionTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About Us',
                  value: '',
                  textColor: _textPrimary,
                  onTap: () => UrlLauncherUtil.launchInAppView("About Page"),
                ),
              ],
            ),

            SizedBox(height: 40.h),

            // --- FOOTER ---
            Center(
              child: Column(
                children: [
                  // App Logo or simple text
                  Image.asset(AppStrings.logo, height: AppSizes.icon_md),
                  SizedBox(height: 8.h),
                  Text(
                    "Eazycam",
                    style: TextStyle(
                      color: MyColors.grey.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                    ),
                  ),
                  Text(
                    "Version 1.8.12",
                    style: TextStyle(
                      color: MyColors.grey.withOpacity(0.3),
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  // Helper for Bottom Sheet
  // void _showSelectionSheet({
  //   required BuildContext context,
  //   required String title,
  //   required List<String> options,
  //   required String currentValue,
  //   required Function(String) onSelected,
  // }) {
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: _darkSurface,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //     ),
  //     builder: (ctx) {
  //       return SafeArea(
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Container(
  //               margin: EdgeInsets.only(top: 12.h, bottom: 16.h),
  //               width: 40.w,
  //               height: 4.h,
  //               decoration: BoxDecoration(
  //                 color: Colors.white24,
  //                 borderRadius: BorderRadius.circular(2),
  //               ),
  //             ),
  //             Text(
  //               title,
  //               style: TextStyle(
  //                 fontSize: 18.sp,
  //                 fontWeight: FontWeight.bold,
  //                 color: _textPrimary,
  //               ),
  //             ),
  //             SizedBox(height: 16.h),
  //             ...options.map(
  //               (option) => ListTile(
  //                 title: Text(
  //                   option,
  //                   style: TextStyle(color: _textPrimary, fontSize: 16.sp),
  //                 ),
  //                 trailing: option == currentValue
  //                     ? Icon(
  //                         Icons.check_circle,
  //                         color: MyColors.lightColorScheme.primary,
  //                       )
  //                     : null,
  //                 onTap: () {
  //                   onSelected(option);
  //                   Navigator.pop(ctx);
  //                 },
  //               ),
  //             ),
  //             SizedBox(height: 20.h),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

}

// --- CUSTOM WIDGETS ---

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 8.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color:
              color, // Using primary color for headers looks cool in dark mode
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final Color backgroundColor;
  const _SettingsGroup({required this.children, required this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(children: children),
    );
  }
}

// class _SwitchTile extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final String? subtitle;
//   final bool value;
//   final ValueChanged<bool> onChanged;
//   final Color textColor;
//   final Color subTextColor;

//   const _SwitchTile({
//     required this.icon,
//     required this.title,
//     this.subtitle,
//     required this.value,
//     required this.onChanged,
//     required this.textColor,
//     required this.subTextColor,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return ListTile(
//       contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
//       leading: Container(
//         padding: EdgeInsets.all(8.sp),
//         decoration: BoxDecoration(
//           color: MyColors.grey01.withOpacity(0.8),
//           borderRadius: BorderRadius.circular(10.r),
//         ),
//         child: Icon(icon, color: MyColors.grey, size: 22.sp),
//       ),
//       title: Text(
//         title,
//         style: TextStyle(
//           fontWeight: FontWeight.w600,
//           fontSize: 15.sp,
//           color: textColor,
//         ),
//       ),
//       subtitle: subtitle != null
//           ? Text(
//               subtitle!,
//               style: TextStyle(fontSize: 12.sp, color: subTextColor),
//             )
//           : null,
//       trailing: Transform.scale(
//         scale: 0.8,
//         child: Switch.adaptive(
//           value: value,
//           onChanged: onChanged,
//           activeColor: MyColors.green,
//           activeTrackColor: MyColors.green.withOpacity(0.2),
//           inactiveTrackColor: MyColors.grey01,
//         ),
//       ),
//     );
//   }
// }

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color textColor;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      splashColor: Colors.transparent,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      leading: Container(
        padding: EdgeInsets.all(8.sp),
        decoration: BoxDecoration(
          color: MyColors.grey01.withOpacity(0.8),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, color: MyColors.grey, size: 22.sp),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15.sp,
          color: textColor,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty)
            Text(
              value,
              style: TextStyle(color: Colors.white54, fontSize: 13.sp),
            ),
          SizedBox(width: 6.w),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white30,
            size: 14.sp,
          ),
        ],
      ),
    );
  }
}

class _CustomDivider extends StatelessWidget {
  final Color color;
  const _CustomDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56.w,
      thickness: 1,
      color:
          color, // Divider matches background color to create a "cutout" effect
    );
  }
}
