import 'dart:io';

class AdHelper {

  // -------------------- BANNER --------------------
  static String get banner {
    if (Platform.isAndroid) return "e68afcdc201fa981";
    if (Platform.isIOS) return "a57aa97a5649b713";
    throw UnsupportedError("Unsupported platform");
  }

  // -------------------- APP OPEN --------------------
  static String get appOpen {
    if (Platform.isAndroid) return "00698d8e6276574b";
    if (Platform.isIOS) return "2f07198fa79f57ff";
    throw UnsupportedError("Unsupported platform");
  }

  // -------------------- INTERSTITIAL --------------------
  static String get interstitial {
    if (Platform.isAndroid) return "e4e46d71ce6816eb";
    if (Platform.isIOS) return "d3372a21579004c7";
    throw UnsupportedError("Unsupported platform");
  }

  // -------------------- REWARDED --------------------
  static String get rewarded {
    if (Platform.isAndroid) return "57c32c84b8962f66";
    if (Platform.isIOS) return "e8be7897a8972dad";
    throw UnsupportedError("Unsupported platform");
  }

  // -------------------- NATIVE --------------------
  static String get native {
    if (Platform.isAndroid) return "bc071eff6999bfea";
    if (Platform.isIOS) return "5bfae7fd54dd8e11";
    throw UnsupportedError("Unsupported platform");
  }

  // -------------------- NATIVE --------------------
  static String get mrecAdUnitId {
    if (Platform.isAndroid) return "6143938bf3c8cc37";
    if (Platform.isIOS) return "45d926b7c85fa773";
    throw UnsupportedError("Unsupported platform");
  }

  // -------------------- ADMOB --------------------

  static String get bannerAdUnitId {
    final id = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-3940256099942544/2934735716';
    print('🔍 Banner Ad Unit ID: $id (${Platform.isIOS ? "iOS" : "Android"})');
    return id;
  }

  static String get interstitialAdUnitId {
    final id = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712'
        : 'ca-app-pub-3940256099942544/4411468910';
    print('🔍 Interstitial Ad Unit ID: $id (${Platform.isIOS ? "iOS" : "Android"})');
    return id;
  }

  static String get appOpenAdUnitId {
    final id = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/3419835294'
        : 'ca-app-pub-3940256099942544/5662855259';
    print('🔍 App Open Ad Unit ID: $id (${Platform.isIOS ? "iOS" : "Android"})');
    return id;
  }

  static String get nativeAdUnitId {
    final id = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/2247696110'
        : 'ca-app-pub-3940256099942544/3986624511';
    print('🔍 App Open Ad Unit ID: $id (${Platform.isIOS ? "iOS" : "Android"})');
    return id;
  }
}
