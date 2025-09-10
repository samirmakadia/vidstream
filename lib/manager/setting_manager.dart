import 'package:shared_preferences/shared_preferences.dart';

class SettingManager {
  static final SettingManager _instance = SettingManager._internal();
  factory SettingManager() => _instance;

  SettingManager._internal();

  static const String _frequencyKey = "ad_frequency";

  Future<void> setAdFrequency(int frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_frequencyKey, frequency);
  }

  Future<int?> getAdFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_frequencyKey);
  }

  Future<int> getAdFrequencyOrDefault({int defaultValue = 4}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_frequencyKey) ?? defaultValue;
  }

  Future<void> clearAdFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_frequencyKey);
  }
}
