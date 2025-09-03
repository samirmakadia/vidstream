import 'dart:io';

class AdUnitIds {

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
}
