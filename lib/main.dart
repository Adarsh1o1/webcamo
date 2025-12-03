import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/views/splash_screen.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // SystemChrome.setSystemUIOverlayStyle(
  //   const SystemUiOverlayStyle(
  //     systemNavigationBarColor: MyColors.backgund,
  //     systemNavigationBarDividerColor: MyColors.backgund,
  //     statusBarColor: MyColors.backgund,
  //     statusBarIconBrightness: Brightness.dark,
  //     systemNavigationBarIconBrightness: Brightness.dark,
  //   ),
  // );
  runApp(const ProviderScope(child: MyApp()));
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
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            systemNavigationBarColor: Color(0xff1E1E1E),
            systemNavigationBarDividerColor: Color(0xff1E1E1E),
            statusBarColor: Color(0xff1E1E1E),
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: MaterialApp(
            title: 'Eazycam',
            debugShowCheckedModeBanner: false,

            themeMode: ThemeMode.dark,
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
          ),
        );
      },
    );
  }
}
