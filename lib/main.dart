import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:webcamo/services/notification_service.dart' hide localStorageProvider;
import 'package:webcamo/utils/colors.dart';
import 'package:webcamo/utils/local_storage.dart';
import 'package:webcamo/utils/logger.dart';
import 'package:webcamo/views/splash_screen.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  Logger.log('Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    Logger.log('Firebase initialized successfully');
  } catch (e) {
    Logger.log('Firebase initialization failed: $e', error: true);
  }

  final localStorage = await LocalStorage.init();

  final container = ProviderContainer(
    overrides: [
      localStorageProvider.overrideWithValue(localStorage),
    ],
  );

  await container.read(notificationServiceProvider).init();
  MobileAds.instance.initialize();
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
            navigatorKey: navigatorKey,

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
