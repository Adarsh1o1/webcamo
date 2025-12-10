import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webcamo/main.dart';

// --- Providers ---

// Placeholder for your LocalStorage provider
final localStorageProvider = Provider<LocalStorageInterface>((ref) {
  throw UnimplementedError('Override this provider in main.dart');
});

// The main Notification Service Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});


// --- Service Implementation ---

class NotificationService {
  final Ref ref;
  
  NotificationService(this.ref);

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String broadcastTopic = 'broadcast';
  static const String _permissionRequestedKey = 'notification_permission_requested';
  static const String _topicSubscribedKey = 'notification_topic_subscribed';

  // --- Initialization ---

  Future<void> init() async {
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

      // Token Refresh
      _messaging.onTokenRefresh.listen((String token) async {
        debugPrint('FCM Token refreshed: $token');
        await _subscribeToTopic(token);
      });

      debugPrint('NotificationService initialized');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  // --- Storage Helpers ---
  
  // Helper to access storage via ref
  LocalStorageInterface get _storage => ref.read(localStorageProvider);

  bool hasRequestedPermission() {
    return _storage.read<bool>(_permissionRequestedKey) ?? false;
  }

  bool hasSubscribedToTopic() {
    return _storage.read<bool>(_topicSubscribedKey) ?? false;
  }

  // --- Permissions & Setup ---

  Future<bool> requestNotificationPermissions() async {
    try {
      bool alreadyRequested = hasRequestedPermission();
      bool alreadySubscribed = hasSubscribedToTopic();

      if (alreadyRequested && alreadySubscribed) {
        debugPrint('Permission granted and already subscribed, skipping');
        return true;
      }

      // Logic for retry or first time request
      NotificationSettings settings;
      
      if (alreadyRequested && !alreadySubscribed) {
        debugPrint('Permission requested but subscription failed, retrying...');
        settings = await _messaging.requestPermission(
          alert: true, badge: true, sound: true, provisional: false,
        );
      } else {
        debugPrint('First time permission request');
        settings = await _messaging.requestPermission(
          alert: true, badge: true, sound: true, provisional: false,
        );
        _storage.write(_permissionRequestedKey, true);
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('Notification permission granted/authorized');
        bool subscriptionSuccess = await _getAndSubscribeToken();

        if (subscriptionSuccess) {
          _storage.write(_topicSubscribedKey, true);
          return true;
        }
        return false;
      } else {
        debugPrint('Notification permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/launcher_icon');
        
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
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // --- Token Management ---

  Future<bool> _getAndSubscribeToken() async {
    int retries = 3;
    int delaySeconds = 2;

    for (int i = 0; i < retries; i++) {
      try {
        String? token = await _messaging.getToken();
        if (token != null) {
          debugPrint('FCM Token obtained: $token');
          await _subscribeToTopic(token);
          _storage.write('FcmToken', token);
          return true;
        } else {
          debugPrint('FCM Token is null');
        }
      } catch (e) {
        debugPrint('Error getting FCM token (attempt ${i + 1}): $e');
      }

      if (i < retries - 1) {
        await Future.delayed(Duration(seconds: delaySeconds));
        delaySeconds *= 2;
      }
    }
    debugPrint('Failed to get FCM token after $retries attempts');
    return false;
  }

  Future<void> _subscribeToTopic(String token) async {
    try {
      await _messaging.subscribeToTopic(broadcastTopic);
      debugPrint('Subscribed to topic: $broadcastTopic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
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
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Important notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
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

// --- Mock Interface for Local Storage (Replace with your actual class) ---
abstract class LocalStorageInterface {
  T? read<T>(String key);
  void write(String key, dynamic value);
}