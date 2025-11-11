import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/views/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'Webcamo',
          debugShowCheckedModeBanner: false,

          themeMode: ThemeMode.system,
          theme: ThemeData(
            colorScheme: MyColors.lightColorScheme,
            useMaterial3: true,
            appBarTheme: AppBarTheme(
              backgroundColor: MyColors.lightColorScheme.surfaceVariant,
              foregroundColor: MyColors.lightColorScheme.onSurface,
              elevation: 0,
            ),
          ),

          // 2. Dark Theme
          darkTheme: ThemeData(
            colorScheme: MyColors.darkColorScheme,
            useMaterial3: true,
            appBarTheme: AppBarTheme(
              backgroundColor: MyColors.darkColorScheme.surfaceVariant,
              foregroundColor: MyColors.darkColorScheme.onSurface,
              elevation: 0,
            ),
          ),

          home: SplashScreen(),
        );
      },
    );
  }
}
