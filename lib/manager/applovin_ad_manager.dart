import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:vidmeet/manager/setting_manager.dart';
import '../helper/ad_helper.dart';
import '../screens/ads/native_ads_widget.dart';

class AppLovinAdManager {
  static final String _appOpenAdUnitId = AdHelper.appOpen;
  static final String _interstitialAdUnitId = AdHelper.interstitial;

  static bool _isShowingAppOpen = false;
  static bool _isAppOpenAvailable = false;

  static bool _isInterstitialAvailable = false;
  static bool isMrecAdLoaded = true;

  static bool isBannerLoaded = false;

  static int _screenOpenCount = 0;
  static int _showAdEvery = 3;
  static bool isNativeAdLoaded = false;

  static bool get isAppOpenAvailable => _isAppOpenAvailable;
  static VoidCallback? _appOpenOnDismissed;
  static InterstitialAd? _admobInterstitial;
  static bool _admobLoaded = false;

  static Future<void> initialize() async {
    await AppLovinMAX.initialize(AdHelper.sdkId);

    _setupAppOpenListener();
    _setupInterstitialListener();

    loadAppOpenAd();
    loadInterstitialAd();
    loadMrecAd();
    loadBanner();
    loadAdmobInterstitial();
  }

  // -------------------- Interstitial Listener --------------------

  static void _setupInterstitialListener() {
    AppLovinMAX.setInterstitialListener(
      InterstitialListener(
        onAdLoadedCallback: (ad) {
          _isInterstitialAvailable = true;
          debugPrint("✅ Interstitial loaded");
        },
        onAdLoadFailedCallback: (adUnitId, error) {
          _isInterstitialAvailable = false;
          debugPrint("❌ Interstitial load failed: ${error.message}");
        },
        onAdDisplayedCallback: (ad) {
          debugPrint("📢 Interstitial shown");
        },
        onAdDisplayFailedCallback: (ad, error) {
          _isInterstitialAvailable = false;
          debugPrint("❌ Interstitial show failed: ${error.message}");
          loadInterstitialAd();
        },
        onAdHiddenCallback: (ad) {
          _isInterstitialAvailable = false;
          debugPrint("ℹ️ Interstitial dismissed");
          loadInterstitialAd();
        },
        onAdClickedCallback: (ad) {
          debugPrint("👆 Interstitial clicked: ${ad.adUnitId}");
        },
        onAdRevenuePaidCallback: (ad) {
          debugPrint("💰 Revenue paid for Interstitial: ${ad.adUnitId}");
        },
      ),
    );
  }

  static void loadAdmobInterstitial() {
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _admobInterstitial = ad;
          _admobLoaded = true;
          debugPrint("✅ AdMob Interstitial loaded");
          _admobInterstitial?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _admobLoaded = false;
              loadAdmobInterstitial(); // Preload next
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint("❌ AdMob failed to show: $error");
              ad.dispose();
              _admobLoaded = false;
              loadAdmobInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint("❌ AdMob interstitial failed: $error");
          _admobLoaded = false;
          Future.delayed(const Duration(seconds: 5), loadAdmobInterstitial);
        },
      ),
    );
  }

  // -------------------- Screen Open Handler --------------------

  static void handleScreenOpen(VoidCallback onNavigate) {
    _showAdEvery = SettingManager().fullscreenFrequency ?? 3;
    _screenOpenCount++;

    if (_screenOpenCount >= _showAdEvery) {
      if (_isInterstitialAvailable) {
        _enterFullscreen();
        AppLovinMAX.showInterstitial(_interstitialAdUnitId);
        _isInterstitialAvailable = false;
        _screenOpenCount = 0;
        Future.delayed(const Duration(milliseconds: 300), () {
          _exitFullscreen();
          onNavigate();
        });
      } else if (_admobLoaded && _admobInterstitial != null) {
        _admobInterstitial?.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            loadAdmobInterstitial();
            onNavigate();
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            debugPrint("❌ AdMob failed: $error");
            ad.dispose();
            loadAdmobInterstitial();
            onNavigate();
          },
        );
        _admobInterstitial?.show();
        _admobInterstitial = null;
        _admobLoaded = false;
        _screenOpenCount = 0;
      } else {
        debugPrint("⚠️ No interstitial available → Skipping ad");
        loadAdmobInterstitial();
        loadInterstitialAd();
        _screenOpenCount = 0;
        onNavigate();
      }
    } else {
      onNavigate();
    }
  }

  // -------------------- Other existing code remains untouched --------------------

  static void _setupAppOpenListener() {
    AppLovinMAX.setAppOpenAdListener(
      AppOpenAdListener(
        onAdLoadedCallback: (ad) {
          if (ad.adUnitId == _appOpenAdUnitId) {
            _isAppOpenAvailable = true;
            debugPrint("✅ AppLovin AppOpen loaded");
          }
        },
        onAdLoadFailedCallback: (adUnitId, error) {
          _isAppOpenAvailable = false;
          debugPrint("❌ AppOpen show failed:${error.message}");
          Future.delayed(const Duration(seconds: 5), loadAppOpenAd);
        },
        onAdDisplayedCallback: (ad) {
          _isShowingAppOpen = true;
        },
        onAdDisplayFailedCallback: (ad, error) {
          _isShowingAppOpen = false;
          _isAppOpenAvailable = false;
          debugPrint("❌ AppOpen show failed: ${error.message}");
          loadAppOpenAd();
          _appOpenOnDismissed?.call(); // complete callback even on failure
          _appOpenOnDismissed = null;
        },
        onAdHiddenCallback: (ad) {
          _isShowingAppOpen = false;
          _isAppOpenAvailable = false;
          debugPrint("ℹ️ AppOpen dismissed");
          _appOpenOnDismissed?.call(); // ✅ trigger the dismiss callback
          _appOpenOnDismissed = null;
        },
        onAdClickedCallback: (ad) {
          debugPrint("👆 AppOpen Ad clicked: ${ad.adUnitId}");
        },
      ),
    );
  }

  static void loadAppOpenAd() => AppLovinMAX.loadAppOpenAd(_appOpenAdUnitId);
  static void loadInterstitialAd() => AppLovinMAX.loadInterstitial(_interstitialAdUnitId);
  static void loadMrecAd() => AppLovinMAX.loadMRec(AdHelper.mrecAdUnitId);
  static void loadBanner() => AppLovinMAX.loadBanner(AdHelper.banner);

  static void showAppOpenAd({VoidCallback? onDismissed}) {
    if (!_isAppOpenAvailable || _isShowingAppOpen) {
      debugPrint("⚠️ AppOpen not ready, skipping");
      onDismissed?.call();
      return;
    }
    _appOpenOnDismissed = onDismissed;
    AppLovinMAX.showAppOpenAd(_appOpenAdUnitId);
  }

  static Widget mrecAd({double height = 250, double width = 300}) {
    return NativeAdsWidget(
      onAdLoadChanged: (isLoaded) {
        isMrecAdLoaded = isLoaded;
        debugPrint("MREC Loaded: $isLoaded");
      },
      height: height,
      width: width,
      showSwipeHint: false,
    );
  }

  static Widget largeMrecAd({double height = 300, double width = 300}) {
    return NativeAdsWidget(
      onAdLoadChanged: (isLoaded) {
        isMrecAdLoaded = isLoaded;
        debugPrint("MREC Loaded: $isLoaded");
      },
      height: height,
      width: width,
      isMedium: true,
      showSwipeHint: true,
    );
  }

  static void _enterFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static void _exitFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }


}
