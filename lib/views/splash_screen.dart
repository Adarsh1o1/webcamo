import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/sizes.dart';
import 'package:webcamo/utils/strings.dart';
import 'package:webcamo/views/onboarding_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    whereToGo();
  }

  void whereToGo() {
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OnboardingScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.lightColorScheme.primary,
      body: Center(
        child: Image.asset(
          AppStrings.appLogoWithoutBg,
          height: AppSizes.logo_sm,
        ),
      ),
    );
  }
}
