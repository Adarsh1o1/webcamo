// lib/views/usb/usb_page.dart


import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/sizes.dart';

class USBPage extends StatelessWidget {
  const USBPage({super.key});

  // Future<void> _commingSoon(BuildContext context) async {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(
  //         'This feature is comming soon',
  //         style: TextStyle(fontSize: AppSizes.font_sm),
  //       ),
  //     ),
  //   );
  //   // return null;
  // }

  @override
  Widget build(BuildContext context) {
    // Dark theme background to match Settings Page
    // const Color darkBackground = Color(0xFF121212);

    return Scaffold(
      backgroundColor: MyColors.lightColorScheme.primary,
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
                  colors: [MyColors.grey.withOpacity(0.2), Colors.transparent],
                  radius: 0.8.r,
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

                  SizedBox(height: 25.h),

                  // Headline
                  Text(
                    'Wired Connection',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      // letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 30.h),
                  Container(
                    // padding: EdgeInsets.symmetric(
                    //   horizontal: 12.w,
                    //   vertical: 6.h,
                    // ),
                    decoration: BoxDecoration(
                      color: MyColors.green,
                      borderRadius: BorderRadius.circular(AppSizes.radius_full),
                      border: Border.all(
                        color: MyColors.green.withOpacity(
                          0.5,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding:  EdgeInsets.symmetric(horizontal: AppSizes.p48, vertical: AppSizes.p8),
                      child: Text(
                        "COMING SOON",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: AppSizes.font_md,
                          // letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30.h),

                  // Description Text with Icons
                  Padding(
                     padding: EdgeInsets.symmetric(horizontal: 50.w),
                    child: Column(
                      children: [
                        _InstructionRow(
                          text: "Ultra-low latency performance",
                        ),
                        SizedBox(height: 12.h),
                        _InstructionRow(
                          text: "Lossless upto 4K video transfer",
                        ),
                        SizedBox(height: 12.h),
                        _InstructionRow(
                          text: "Stable connection & charging",
                        ),
                      ],
                    ),
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

class _InstructionRow extends StatelessWidget {
  final String text;
  const _InstructionRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white10,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 12, color: MyColors.green),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white60, fontSize: 13.sp,),
          ),
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
