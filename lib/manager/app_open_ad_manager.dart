import 'dart:ffi';

import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../helper/ad_helper.dart';

class AppLovinAdManager {
  static final String _appOpenAdUnitId = AdUnitIds.appOpen;
  static final String _bannerAdUnitId = AdUnitIds.banner;
  static final String _interstitialAdUnitId = AdUnitIds.interstitial;
  static final String _rewardedAdUnitId = AdUnitIds.rewarded;
  static final String _nativeAdUnitId = AdUnitIds.native;

  static bool _isShowingAppOpen = false;
  static bool _isAppOpenAvailable = false;

  static bool _isInterstitialAvailable = false;
  static bool _isRewardedAvailable = false;

  static bool isBannerLoaded = false;

  // --- New variables for screen open tracking ---
  static int _screenOpenCount = 0;
  static const int _showAdEvery = 3;

  static bool get isAppOpenAvailable => _isAppOpenAvailable;

  static Future<void> initialize() async {
    await AppLovinMAX.initialize(
      "1RJL6Ot743MAvgfG8BeGvetoyp6DS_TTQsqXFgeJk_Tdf8upJX3DAx_7l6KB5tfWkT2z8gHtgmULuN8CvCP48P",
    );

    _setupAppOpenListener();
    _setupInterstitialListener();
    _setupRewardedListener();

    // Initial loads
    loadAppOpenAd();
    loadInterstitialAd();
    loadRewardedAd();
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

  // -------------------- Screen Open Handler --------------------

  static void handleScreenOpen(VoidCallback onNavigate) {
    _screenOpenCount++;

    try {
      if (_screenOpenCount >= _showAdEvery && _isInterstitialAvailable) {
        _enterFullscreen();
        AppLovinMAX.showInterstitial(_interstitialAdUnitId);

        _isInterstitialAvailable = false;
        _screenOpenCount = 0;

        Future.delayed(const Duration(milliseconds: 300), () {
          _exitFullscreen();
          onNavigate();
        });
        return;
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Error showing interstitial: $e\n$stackTrace");
    }

    onNavigate();
  }

  static void _enterFullscreen() {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static void _exitFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // -------------------- Banner --------------------
  static Widget bannerAdWidget({AdFormat format = AdFormat.banner}) {
    return MaxAdView(
      adUnitId: _bannerAdUnitId,
      adFormat: format,
      listener: AdViewAdListener(
        onAdLoadedCallback: (ad) {
          isBannerLoaded = true;
          debugPrint("✅ Banner loaded from network: ${ad.networkName}");
        },
        onAdLoadFailedCallback: (adUnitId, error) {
          isBannerLoaded = false;
          debugPrint("❌ Banner load failed: ${error.message}");
        },
        onAdClickedCallback: (ad) =>
            debugPrint("👆 Banner clicked: ${ad.adUnitId}"),
        onAdExpandedCallback: (ad) =>
            debugPrint("🔼 Banner expanded (fullscreen)"),
        onAdCollapsedCallback: (ad) =>
            debugPrint("🔽 Banner collapsed (returned to normal)"),
      ),
    );
  }

  // -------------------- Other existing code remains untouched --------------------
  static void _setupRewardedListener() {
    AppLovinMAX.setRewardedAdListener(
      RewardedAdListener(
        onAdLoadedCallback: (ad) {
          _isRewardedAvailable = true;
          debugPrint("✅ Rewarded loaded");
        },
        onAdLoadFailedCallback: (adUnitId, error) {
          _isRewardedAvailable = false;
          debugPrint("❌ Rewarded load failed: ${error.message}");
        },
        onAdDisplayedCallback: (ad) {
          debugPrint("📢 Rewarded shown");
        },
        onAdDisplayFailedCallback: (ad, error) {
          _isRewardedAvailable = false;
          debugPrint("❌ Rewarded show failed: ${error.message}");
          loadRewardedAd();
        },
        onAdHiddenCallback: (ad) {
          _isRewardedAvailable = false;
          debugPrint("ℹ️ Rewarded dismissed");
          loadRewardedAd();
        },
        onAdReceivedRewardCallback: (ad, reward) {
          debugPrint("🎁 User earned reward: ${reward.amount} ${reward.label}");
        },
        onAdClickedCallback: (ad) {
          debugPrint("👆 Rewarded clicked: ${ad.adUnitId}");
        },
        onAdRevenuePaidCallback: (ad) {
          debugPrint("💰 Revenue paid for Rewarded: ${ad.adUnitId}");
        },
      ),
    );
  }

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
          debugPrint("❌ AppOpen load failed: ${error.message}");
          // 🔁 retry after short delay
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
        },
        onAdHiddenCallback: (ad) {
          _isShowingAppOpen = false;
          _isAppOpenAvailable = false;
          debugPrint("ℹ️ AppOpen dismissed");
         // loadAppOpenAd();
        },
        onAdClickedCallback: (ad) {
          debugPrint("👆 AppOpen Ad clicked: ${ad.adUnitId}");
        },
      ),
    );
  }


  static void loadAppOpenAd() => AppLovinMAX.loadAppOpenAd(_appOpenAdUnitId);
  static void loadInterstitialAd() =>
      AppLovinMAX.loadInterstitial(_interstitialAdUnitId);
  static void loadRewardedAd() =>
      AppLovinMAX.loadRewardedAd(_rewardedAdUnitId);

  static void showAppOpenAd({VoidCallback? onDismissed}) {
    if (!_isAppOpenAvailable || _isShowingAppOpen) {
      debugPrint("⚠️ AppOpen not ready, skipping");
      onDismissed?.call();
      return;
    }
    AppLovinMAX.showAppOpenAd(_appOpenAdUnitId);
  }

  static void showInterstitialAd({VoidCallback? onDismissed}) {
    if (!_isInterstitialAvailable) {
      onDismissed?.call();
      return;
    }
    AppLovinMAX.showInterstitial(_interstitialAdUnitId);
  }

  static void showRewardedAd({VoidCallback? onDismissed}) {
    if (!_isRewardedAvailable) {
      onDismissed?.call();
      return;
    }
    AppLovinMAX.showRewardedAd(_rewardedAdUnitId);
  }


  static Widget nativeAdLarge({double height = 300}) {
    final controller = MaxNativeAdViewController();

    return SizedBox(
      height: height,
      child: MaxNativeAdView(
        adUnitId: _nativeAdUnitId,
        controller: controller,
        listener: NativeAdListener(
          onAdLoadedCallback: (ad) =>
              debugPrint("✅ Native loaded from ${ad.networkName}"),
          onAdLoadFailedCallback: (adUnitId, error) =>
              debugPrint("❌ Native load failed: ${error.message}"),
          onAdClickedCallback: (ad) =>
              debugPrint("👆 Native clicked: ${ad.adUnitId}"),
          onAdRevenuePaidCallback: (ad) =>
              debugPrint("💰 Native revenue: ${ad.revenue}"),
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  MaxNativeAdIconView(width: 48, height: 48),
                  SizedBox(width: 8),
                  Expanded(
                    child: MaxNativeAdTitleView(
                      maxLines: 1,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  MaxNativeAdOptionsView(width: 20, height: 20),
                ],
              ),
              SizedBox(height: 8),
              Expanded(child: MaxNativeAdMediaView()),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: MaxNativeAdCallToActionView(),
              ),
            ],
          ),
        ),
      ),
    );
  }


  static Widget nativeAdSmall({double height = 110, double width =double.infinity}) {
    final controller = MaxNativeAdViewController();

    return SizedBox(
      height: height,
      width: width,
      child: MaxNativeAdView(
        adUnitId: _nativeAdUnitId,
        controller: controller,
        listener: NativeAdListener(
          onAdLoadedCallback: (ad) =>
              debugPrint("✅ vSmall Native loaded from ${ad.networkName}"),
          onAdLoadFailedCallback: (adUnitId, error) =>
              debugPrint("❌ vSmall Native load failed: ${error.message}"),
          onAdClickedCallback: (ad) =>
              debugPrint("👆 vSmall Native clicked: ${ad.adUnitId}"),
          onAdRevenuePaidCallback: (ad) =>
              debugPrint("💰 vSmall Native revenue: ${ad.revenue}"),
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MaxNativeAdIconView(width: 40, height: 40),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MaxNativeAdTitleView(
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    MaxNativeAdBodyView(
                      maxLines: 1,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MaxNativeAdCallToActionView(),
              const SizedBox(width: 6),
              MaxNativeAdOptionsView(width: 16, height: 16),
            ],
          ),
        ),
      ),
    );
  }

}
