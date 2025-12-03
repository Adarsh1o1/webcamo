// import 'dart:async';
// import 'dart:math' as math;

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:webcamo/utils/colors.dart';
// import 'package:webcamo/utils/sizes.dart';
// import 'package:webcamo/utils/strings.dart';
// import 'package:webcamo/views/bottombar/bottom_bar.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen>
//     with TickerProviderStateMixin {
//   // Controllers for the two ripple waves
//   late final AnimationController _rippleCtrl1;
//   late final AnimationController _rippleCtrl2;

//   // Controller for the final expanding circle
//   late final AnimationController _expandCtrl;

//   // Animation values (0 → 1)
//   late final Animation<double> _rippleAnim1;
//   late final Animation<double> _rippleAnim2;
//   late final Animation<double> _expandAnim;

//   @override
//   void initState() {
//     super.initState();

//     // ---------- 1. Two fast ripples (0.5 s each) ----------
//     _rippleCtrl1 = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 500),
//     );
//     _rippleCtrl2 = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 500),
//     );

//     _rippleAnim1 = Tween<double>(
//       begin: 0,
//       end: 1,
//     ).animate(CurvedAnimation(parent: _rippleCtrl1, curve: Curves.easeOut));
//     _rippleAnim2 = Tween<double>(
//       begin: 0,
//       end: 1,
//     ).animate(CurvedAnimation(parent: _rippleCtrl2, curve: Curves.easeOut));

//     // ---------- 2. Full-screen expansion ----------
//     _expandCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 400),
//     );

//     _expandAnim = Tween<double>(
//       begin: 0,
//       end: 1,
//     ).animate(CurvedAnimation(parent: _expandCtrl, curve: Curves.easeInOut));

//     // ---------- 3. Start the sequence ----------
//     _startSequence();
//   }

//   void _startSequence() async {
//     _rippleCtrl1.forward().orCancel;
//     await Future.delayed(const Duration(seconds: 1));

//     _rippleCtrl2.forward().orCancel;
//     await Future.delayed(const Duration(seconds: 1));

//     _expandCtrl.forward();

//     await Future.delayed(const Duration(milliseconds: 400));

//     if (!mounted) return;
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (_) => BottomBar()),
//     );
//   }

//   @override
//   void dispose() {
//     _rippleCtrl1.dispose();
//     _rippleCtrl2.dispose();
//     _expandCtrl.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final double logoSize = AppSizes.logo_sm;

//     return AnnotatedRegion<SystemUiOverlayStyle>(
//       value: SystemUiOverlayStyle(
//         systemNavigationBarColor: MyColors.lightColorScheme.primary,
//         systemNavigationBarDividerColor: MyColors.lightColorScheme.primary,
//         statusBarColor: MyColors.lightColorScheme.primary,
//         statusBarIconBrightness: Brightness.dark,
//         systemNavigationBarIconBrightness: Brightness.dark,
//       ),
//       child: Scaffold(
//         backgroundColor: MyColors.lightColorScheme.primary,
//         body: Stack(
//           children: [
//             // ------------------- Logo -------------------
//             Center(
//               child: Image.asset(AppStrings.appLogoWithoutBg, height: logoSize),
//             ),

//             // ------------------- Ripple waves -------------------
//             Center(
//               child: AnimatedBuilder(
//                 animation: Listenable.merge([_rippleCtrl1, _rippleCtrl2]),
//                 builder: (_, __) {
//                   return CustomPaint(
//                     size: Size.infinite,
//                     painter: _RipplePainter(
//                       radius1: logoSize / 2 * (1 + _rippleAnim1.value * 2),
//                       opacity1: 1 - _rippleAnim1.value,
//                       radius2: logoSize / 2 * (1 + _rippleAnim2.value * 2),
//                       opacity2: 1 - _rippleAnim2.value,
//                       color: MyColors.green,
//                     ),
//                   );
//                 },
//               ),
//             ),

//             // ------------------- Expanding circle -------------------
//             AnimatedBuilder(
//               animation: _expandAnim,
//               builder: (_, __) {
//                 final size = MediaQuery.of(context).size;
//                 final double maxRadius =
//                     math.sqrt(
//                       size.width * size.width + size.height * size.height,
//                     ) /
//                     2;

//                 final double currentRadius = maxRadius * _expandAnim.value;

//                 return Center(
//                   child: CustomPaint(
//                     size: Size.infinite,
//                     painter: _CircleFillPainter(
//                       radius: currentRadius,
//                       color: MyColors.green,
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _CircleFillPainter extends CustomPainter {
//   final double radius;
//   final Color color;

//   _CircleFillPainter({required this.radius, required this.color});

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = color
//       ..style = PaintingStyle.fill;

//     canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
//   }

//   @override
//   bool shouldRepaint(covariant _CircleFillPainter old) =>
//       old.radius != radius || old.color != color;
// }

// class _RipplePainter extends CustomPainter {
//   final double radius1;
//   final double opacity1;
//   final double radius2;
//   final double opacity2;
//   final Color color;

//   _RipplePainter({
//     required this.radius1,
//     required this.opacity1,
//     required this.radius2,
//     required this.opacity2,
//     required this.color,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 4;

//     // First ripple
//     if (opacity1 > 0) {
//       paint.color = color.withOpacity(opacity1);
//       canvas.drawCircle(
//         Offset(size.width / 2, size.height / 2),
//         radius1,
//         paint,
//       );
//     }

//     // Second ripple
//     if (opacity2 > 0) {
//       paint.color = color.withOpacity(opacity2);
//       canvas.drawCircle(
//         Offset(size.width / 2, size.height / 2),
//         radius2,
//         paint,
//       );
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/sizes.dart';
import 'package:webcamo/utils/strings.dart';
import 'package:webcamo/views/bottombar/bottom_bar.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // The full text to display. You can replace "WebCamo" with AppStrings.appName
  final String _fullText = "Eazycam";

  String _displayedText = "";
  int _currentIndex = 0;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _startTypewriterAnimation();
  }

  void _startTypewriterAnimation() {
    _typingTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (_currentIndex < _fullText.length) {
        setState(() {
          _currentIndex++;
          _displayedText = _fullText.substring(0, _currentIndex);
        });
      } else {
        _typingTimer?.cancel();
        _navigateToNextScreen();
      }
    });
  }

  void _navigateToNextScreen() async {
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BottomBar()),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: MyColors.lightColorScheme.primary,
        systemNavigationBarDividerColor: MyColors.lightColorScheme.primary,
        statusBarColor: MyColors.lightColorScheme.primary,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: MyColors.lightColorScheme.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                AppStrings.appLogoWithoutBg,
                height: AppSizes.logo_sm,
              ),

              const SizedBox(height: 20),
              Text(
                _displayedText,
                style: TextStyle(
                  fontSize: AppSizes.font_3xl,
                  fontWeight: FontWeight.bold,
                  color: MyColors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
