import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webcamo/main.dart';
import 'package:webcamo/utils/local_storage.dart';
import 'package:webcamo/utils/logger.dart';

// --- Providers ---

// The main Notification Service Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(localStorageProvider));
});

// --- Service Implementation ---

class NotificationService {
  final LocalStorage _storage; // Check dependency injection

  NotificationService(this._storage);

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String broadcastTopic = 'broadcast';

  // --- Initialization ---

  Future<void> init() async {
    Logger.log('NotificationService.init() started');
    try {
      await _initLocalNotifications();

      // Listeners
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

      // Background/Terminated state handling
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleInteraction(initialMessage);
      }

      // Check current permission status and refresh token if already authorized
      NotificationSettings settings = await _messaging
          .getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('App start: Permission authorized, checking token...');
        await _checkAndRefreshFCMToken();
      }

      // Token Refresh (still useful if valid)
      _messaging.onTokenRefresh.listen((String token) async {
        Logger.log('FCM Token refreshed: $token');
        await _subscribeToTopic(token);
      });

      debugPrint('NotificationService initialized');
    } catch (e) {
      Logger.log('NotificationService init error: $e', error: true);
    }
  }

  // --- Storage Helpers ---
  // Storage is now injected directly

  // We rely on SDK for permission status, but we keep track of subscription locally if needed.
  // We can remove manual 'notification_permission_requested' flag as it might block re-requests if user changes mind in settings.

  // --- Permissions & Setup ---

  Future<bool> requestNotificationPermissions() async {
    try {
      NotificationSettings settings = await _messaging
          .getNotificationSettings();

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint(
          'Permission already granted (skipping token fetch on Home Page)',
        );
        // User requested NOT to fetch token each time on homepage.
        // We assume init() handled the app-start check.
        return true;
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.notDetermined) {
        debugPrint('Requesting permission...');
        NotificationSettings newSettings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        if (newSettings.authorizationStatus == AuthorizationStatus.authorized) {
          debugPrint('Permission granted');
          return await _checkAndRefreshFCMToken();
        } else if (newSettings.authorizationStatus ==
            AuthorizationStatus.provisional) {
          debugPrint('Provisional permission granted');
          return await _checkAndRefreshFCMToken();
        } else {
          Logger.log('Notification permission denied by user', error: true);
          return false;
        }
      } else {
        // Denied or Provisional (already set)

        // If it was denied, we might want to ask again or open settings?
        // For now, let's try to request again, sometimes it works if not permanently denied on Android
        // On iOS, if denied, it won't show prompt again.

        NotificationSettings newSettings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        if (newSettings.authorizationStatus == AuthorizationStatus.authorized ||
            newSettings.authorizationStatus ==
                AuthorizationStatus.provisional) {
          return await _checkAndRefreshFCMToken();
        }

        return false;
      }
    } catch (e) {
      debugPrint('✗ Error requesting notification permission: $e');
      return false;
    }
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _navigateToRoute(response.payload!);
        }
      },
    );

    // Android Channel Setup
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'Used for important notifications',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // --- Token Management ---

  /// This function fetches the current FCM token, checks it against the stored one.
  /// If they match, it does nothing.
  /// If they don't match, it stores the new one and subscribes to the topic (again).
  Future<bool> _checkAndRefreshFCMToken() async {
    int retries = 3;
    int delaySeconds = 2;

    for (int i = 0; i < retries; i++) {
      try {
        debugPrint('Checking FCM token (attempt ${i + 1}/$retries)...');
        String? newToken = await _messaging.getToken();

        if (newToken != null) {
          String? storedToken = _storage.read<String>('FcmToken');

          if (storedToken == newToken) {
            Logger.log('Token matched. No need to update.');
            // Ensure we are subscribed? We could force subscribe just in case, or assume 'token matched' == 'subscribed logic done'
            // If the user clears data but token remains same (unlikely), we might miss subscription.
            // But let's assume if token is same, we are good.
            // Actually, to be safe, let's check one more flag or just re-subscribe if we really want to be sure.
            // Requirement: "if not then replace the new fetched token and move to the next step"
            // Implies if match -> done.
            return true;
          } else {
            Logger.log('Token changed or not found. Updating...');
            _storage.write('FcmToken', newToken);
            await _subscribeToTopic(newToken);
            return true;
          }
        } else {
          debugPrint('FCM Token is null');
        }
      } catch (e) {
        Logger.log('Error getting FCM token (attempt ${i + 1}): $e');
      }

      if (i < retries - 1) {
        await Future.delayed(Duration(seconds: delaySeconds));
        delaySeconds *= 2;
      }
    }
    Logger.log('Failed to get FCM token after $retries attempts', error: true);
    return false;
  }

  Future<void> _subscribeToTopic(String token) async {
    try {
      debugPrint(
        'Sending subscription request to Firebase for topic "$broadcastTopic"...',
      );
      await _messaging.subscribeToTopic(broadcastTopic);
      Logger.log('Successfully subscribed to topic: $broadcastTopic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
      // We don't rethrow here to allow the app to continue, but we log it.
    }
  }

  Future<void> unsubscribeFromBroadcast() async {
    await _messaging.unsubscribeFromTopic(broadcastTopic);
    debugPrint('Unsubscribed from $broadcastTopic');
  }

  // --- Handlers ---

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message: ${message.notification?.title}');
    if (message.notification != null) {
      await _showLocalNotification(message);
    }
    // Handle data payload if needed
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'Important notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          channelShowBadge: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.messageId.hashCode,
      message.notification?.title ?? 'Notification',
      message.notification?.body ?? 'New message',
      details,
      payload: message.data['route'] ?? '',
    );
  }

  void _onMessageOpened(RemoteMessage message) {
    _handleInteraction(message);
  }

  void _handleInteraction(RemoteMessage message) {
    final route = message.data['route'] ?? '';
    _navigateToRoute(route);
  }

  // --- Navigation Logic ---

  void _navigateToRoute(String route) {
    // Access the Navigator State via the global key
    final currentState = navigatorKey.currentState;

    if (currentState == null) {
      debugPrint('Navigator state is null, cannot navigate');
      return;
    }

    // You might need a way to check current route here using ModalRoute or custom logic
    // For now, we simply push named

    switch (route) {
      case '/splash':
        currentState.pushNamed('/splash');
        break;
      case '/usbStreamingPage':
        currentState.pushNamed('/usbStreamingPage');
        break;
      case '/wifiStreamingPage':
        currentState.pushNamed('/wifiStreamingPage');
        break;
      default:
        debugPrint('Unknown route: $route');
    }
  }
}
