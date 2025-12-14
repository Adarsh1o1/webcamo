import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localStorageProvider = Provider<LocalStorage>((ref) {
  throw UnimplementedError('LocalStorage not initialized');
});

class LocalStorage {
  final SharedPreferences _prefs;

  LocalStorage(this._prefs);

  /// Initialize the storage (Static factory method)
  static Future<LocalStorage> init() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorage(prefs);
  }

  // --- Generic Read Method ---
  T? read<T>(String key) {
    try {
      if (T == String) {
        return _prefs.getString(key) as T?;
      } else if (T == int) {
        return _prefs.getInt(key) as T?;
      } else if (T == double) {
        return _prefs.getDouble(key) as T?;
      } else if (T == bool) {
        return _prefs.getBool(key) as T?;
      } else if (T == List<String>) {
        return _prefs.getStringList(key) as T?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- Generic Write Method ---
  Future<void> write(String key, dynamic value) async {
    if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(key, value);
    } else {
      throw Exception("Invalid Type for Shared Preferences");
    }
  }

  // --- Remove Method ---
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  // --- Clear All ---
  Future<void> clear() async {
    await _prefs.clear();
  }
}