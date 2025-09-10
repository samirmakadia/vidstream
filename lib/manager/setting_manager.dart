import 'package:shared_preferences/shared_preferences.dart';
import '../models/response_model.dart';
import '../services/api_service.dart';

class SettingManager {
  static final SettingManager _instance = SettingManager._internal();
  factory SettingManager() => _instance;
  SettingManager._internal();

  static const String _fullscreenKey = "fullscreen_ads_frequency";
  static const String _nativeKey = "native_ads_frequency";

  String get fullscreenKey => _fullscreenKey;
  String get nativeKey => _nativeKey;

  int fullscreenFrequency = 3;
  int nativeFrequency = 5;

  Future<void> setFullscreenAdFrequency(int frequency) async {
    fullscreenFrequency = frequency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fullscreenKey, frequency);
  }

  Future<void> setNativeAdFrequency(int frequency) async {
    nativeFrequency = frequency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_nativeKey, frequency);
  }

  Future<int> getFullscreenAdFrequencyOrDefault({int defaultValue = 4}) async {
    if (fullscreenFrequency != 0) return fullscreenFrequency;
    final prefs = await SharedPreferences.getInstance();
    fullscreenFrequency = prefs.getInt(_fullscreenKey) ?? defaultValue;
    return fullscreenFrequency;
  }

  Future<int> getNativeAdFrequencyOrDefault({int defaultValue = 5}) async {
    if (nativeFrequency != 0) return nativeFrequency;
    final prefs = await SharedPreferences.getInstance();
    nativeFrequency = prefs.getInt(_nativeKey) ?? defaultValue;
    return nativeFrequency;
  }

  Future<void> fetchAndStoreAdFrequencies() async {
    try {
      final List<AppSetting> settings = await ApiService().getAppSettings();

      final fullscreenSetting = settings.firstWhere(
            (s) => s.key == _fullscreenKey,
        orElse: () => AppSetting(id: '', key: _fullscreenKey, value: '3'),
      );

      final nativeSetting = settings.firstWhere(
            (s) => s.key == _nativeKey,
        orElse: () => AppSetting(id: '', key: _nativeKey, value: '3'),
      );

      await setFullscreenAdFrequency(int.tryParse(fullscreenSetting.value) ?? 3);
      await setNativeAdFrequency(int.tryParse(nativeSetting.value) ?? 3);

      print('Ad frequencies stored successfully!');
    } catch (e) {
      print('Failed to fetch/store ad frequencies: $e');
    }
  }
}
