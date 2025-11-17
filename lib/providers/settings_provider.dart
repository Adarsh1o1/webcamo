import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool isDarkMode;
  final bool autoConnect;
  final String videoQuality; // low, medium, high
  final int fps; // 15, 30, 60

  const SettingsState({
    this.isDarkMode = true,
    this.autoConnect = false,
    this.videoQuality = 'high',
    this.fps = 30,
  });

  SettingsState copyWith({
    bool? isDarkMode,
    bool? autoConnect,
    String? videoQuality,
    int? fps,
  }) {
    return SettingsState(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      autoConnect: autoConnect ?? this.autoConnect,
      videoQuality: videoQuality ?? this.videoQuality,
      fps: fps ?? this.fps,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = SettingsState(
      isDarkMode: prefs.getBool('isDarkMode') ?? true,
      autoConnect: prefs.getBool('autoConnect') ?? false,
      videoQuality: prefs.getString('videoQuality') ?? 'high',
      fps: prefs.getInt('fps') ?? 30,
    );
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    state = state.copyWith(isDarkMode: value);
  }

  Future<void> setAutoConnect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoConnect', value);
    state = state.copyWith(autoConnect: value);
  }

  Future<void> setVideoQuality(String quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('videoQuality', quality);
    state = state.copyWith(videoQuality: quality);
  }

  Future<void> setFPS(int fps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fps', fps);
    state = state.copyWith(fps: fps);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);

// Selectors
final isDarkModeProvider = Provider((ref) {
  return ref.watch(settingsProvider).isDarkMode;
});

final autoConnectProvider = Provider((ref) {
  return ref.watch(settingsProvider).autoConnect;
});

final videoQualityProvider = Provider((ref) {
  return ref.watch(settingsProvider).videoQuality;
});

final fpsProvider = Provider((ref) {
  return ref.watch(settingsProvider).fps;
});
