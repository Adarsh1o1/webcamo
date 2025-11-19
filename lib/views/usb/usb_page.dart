// lib/views/usb/usb_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/sizes.dart';

class USBPage extends StatelessWidget {
  const USBPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Dark theme background to match Settings Page
    const Color darkBackground = Color(0xFF121212);

    return Scaffold(
      backgroundColor: darkBackground,
      body: Stack(
        children: [
          // 1. Background Ambient Glow
          Positioned(
            top: -100,
            left: -100,
            right: -100,
            child: Container(
              height: 500.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    MyColors.grey.withOpacity(0.2),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.p24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Animated Icon with Ripples
                  const _RippleUSBIcon(),

                  SizedBox(height: 50.h),

                  // Headline
                  Text(
                    'Wired Connection',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: MyColors.green,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: MyColors.green.withOpacity(
                          0.5,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "COMING SOON",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.sp,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  SizedBox(height: 30.h),

                  // Description Text with Icons
                  _FeaturePoint(
                    icon: Icons.speed_rounded,
                    text: "Ultra-low latency performance",
                  ),
                  SizedBox(height: 12.h),
                  _FeaturePoint(
                    icon: Icons.cable_rounded,
                    text: "Lossless 4K video transfer",
                  ),
                  SizedBox(height: 12.h),
                  _FeaturePoint(
                    icon: Icons.battery_charging_full_rounded,
                    text: "Stable connection & charging",
                  ),

                  const Spacer(flex: 3),

                  // // "Notify Me" Button
                  // SizedBox(
                  //   width: double.infinity,
                  //   height: 56.h,
                  //   child: ElevatedButton(
                  //     onPressed: () {
                  //       ScaffoldMessenger.of(context).showSnackBar(
                  //         SnackBar(
                  //           content: const Text(
                  //             "We'll notify you when USB mode connects!",
                  //           ),
                  //           backgroundColor: MyColors.grey,
                  //           behavior: SnackBarBehavior.floating,
                  //         ),
                  //       );
                  //     },
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: MyColors.green,
                  //       foregroundColor: Colors.white,
                  //       elevation: 0,
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(16.r),
                  //       ),
                  //     ),
                  //     child: Row(
                  //       mainAxisAlignment: MainAxisAlignment.center,
                  //       children: [
                  //         Icon(Icons.notifications_active_rounded, size: 20.sp),
                  //         SizedBox(width: 10.w),
                  //         Text(
                  //           "Notify Me When Ready",
                  //           style: TextStyle(
                  //             fontSize: 16.sp,
                  //             fontWeight: FontWeight.bold,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  // SizedBox(height: 70.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS ---

class _FeaturePoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeaturePoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white54, size: 18.sp),
        SizedBox(width: 10.w),
        Text(
          text,
          style: TextStyle(fontSize: 14.sp, color: Colors.white70, height: 1.5),
        ),
      ],
    );
  }
}

// Complex Ripple Animation Widget
class _RippleUSBIcon extends StatefulWidget {
  const _RippleUSBIcon();

  @override
  State<_RippleUSBIcon> createState() => _RippleUSBIconState();
}

class _RippleUSBIconState extends State<_RippleUSBIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200.w,
      height: 200.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripples
          _buildRipple(0),
          _buildRipple(1),
          _buildRipple(2),

          // Center Icon
          Container(
            width: 100.w,
            height: 100.w,
            decoration: BoxDecoration(
              color: MyColors.lightColorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: MyColors.lightColorScheme.primary.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(Icons.usb_rounded, size: 50.sp, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildRipple(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double progress = (_controller.value + (index * 0.33)) % 1.0;
        final double size = 100.w + (progress * 100.w);
        final double opacity = (1.0 - progress).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: MyColors.lightColorScheme.primary.withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}
