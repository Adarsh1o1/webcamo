import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/sizes.dart';
import 'package:webcamo/views/troubleshoot/troubleshoot_page.dart';
import 'package:webcamo/views/usb/usb_streaming_page.dart';

// Convert to Stateful Widget
class USBPage extends StatefulWidget {
  const USBPage({super.key});

  @override
  State<USBPage> createState() => _USBPageState();
}

class _USBPageState extends State<USBPage> {
  // 1. State variable to toggle view
  bool _showStreamingWidget = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.lightColorScheme.primary,
      body: Stack(
        children: [
          if (_showStreamingWidget == false)
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
                    radius: 0.8.r,
                  ),
                ),
              ),
            ),

          // 2. Conditional Rendering
          if (_showStreamingWidget)
            // Show streaming widget covering the page
            SafeArea(
              child: UsbStreamingPage(
                onStop: () {
                  // Callback to return to initial view
                  setState(() {
                    _showStreamingWidget = false;
                  });
                },
              ),
            )
          else
            // Show Initial UI
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 60.h),

                  const _RippleUSBIcon(),

                  SizedBox(height: 20.h),

                  Text(
                    "Wired Webcam",
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 30.h),

                  Center(
                    child: SizedBox(
                      width: 200.w,
                      height: 50.h,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // 3. Switch to Streaming View
                          setState(() {
                            _showStreamingWidget = true;
                          });
                        },
                        icon: const Icon(Icons.usb),
                        label: const Text('Start Streaming'),
                        style: ElevatedButton.styleFrom(
                          textStyle: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: MyColors.green,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: MyColors.green.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 30.h),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 60.w),
                    child: Align(
                      alignment: Alignment.center,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const _InstructionRow(
                            text: "Connect Mobile & PC via USB Cable",
                          ),
                          SizedBox(height: 12.h),
                          const _InstructionRow(
                            text: "Enable USB Debugging on Phone",
                          ),
                          SizedBox(height: 12.h),
                          const _InstructionRow(
                            text: "Start Streaming & Connect on PC",
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 15.h),

                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TroubleshootPage(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.help_outline, size: 16.sp),
                        SizedBox(width: 8.w),
                        const Text("Having trouble?"),
                      ],
                    ),
                  ),
                ],
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
          padding: EdgeInsets.all(AppSizes.p4 - 1.sp),
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
            style: TextStyle(color: Colors.white60, fontSize: 13.sp),
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
