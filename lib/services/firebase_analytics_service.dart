import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:webcamo/services/analytics_service.dart';
import 'package:webcamo/utils/logger.dart';

class FirebaseAnalyticsService implements AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    await _analytics.logEvent(name: name, parameters: parameters);
    Logger.log(
      "LogEvent: {name: $name, parameters: $parameters}",
      name: "ANALYTICS",
    );
  }

  @override
  Future<void> setCurrentScreen({required String screenName}) async {
    await _analytics.logScreenView(screenName: screenName);
    Logger.log(
      "Set Current Screen: {screenName: $screenName}",
      name: "ANALYTICS",
    );
  }

  @override
  Future<void> setUserId({required String userId}) async {
    await _analytics.setUserId(id: userId);
    Logger.log("Set User Id: {id: $userId}", name: "ANALYTICS");
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    await _analytics.setUserProperty(name: name, value: value);
    Logger.log(
      "Set User Property: {name: $name, value: $value}",
      name: "ANALYTICS",
    );
  }
}
