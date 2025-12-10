abstract class AnalyticsService {
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  });

  Future<void> setCurrentScreen({required String screenName});

  Future<void> setUserId({required String userId});

  Future<void> setUserProperty({required String name, required String value});
}
