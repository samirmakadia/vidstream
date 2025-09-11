import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vidmeet/manager/setting_manager.dart';
import '../helper/ad_helper.dart';
import '../screens/ads/common_mrec_ad.dart';
import '../widgets/fancy_swipe_arrow.dart';

class AppLovinAdManager {
  static final String _appOpenAdUnitId = AdHelper.appOpen;
  static final String _interstitialAdUnitId = AdHelper.interstitial;
  static final String _nativeAdUnitId = AdHelper.native;

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

  static Future<void> initialize() async {
    await AppLovinMAX.initialize("1RJL6Ot743MAvgfG8BeGvetoyp6DS_TTQsqXFgeJk_Tdf8upJX3DAx_7l6KB5tfWkT2z8gHtgmULuN8CvCP48P",);

    _setupAppOpenListener();
    _setupInterstitialListener();

    loadAppOpenAd();
    loadInterstitialAd();
    loadMrecAd();
    loadBanner();
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
    _showAdEvery = SettingManager().fullscreenFrequency ?? 3;
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

  static void showInterstitialAd({VoidCallback? onDismissed}) {
    if (!_isInterstitialAvailable) {
      onDismissed?.call();
      return;
    }
    AppLovinMAX.showInterstitial(_interstitialAdUnitId);
  }

  static Widget nativeAdLarge({double height = 300}) {
    final MaxNativeAdViewController controller = MaxNativeAdViewController();
    double mediaViewAspectRatio = 1.91; // default fallback

    return SizedBox(
      height: height,
      child: MaxNativeAdView(
        adUnitId: _nativeAdUnitId,
        controller: controller,
        listener: NativeAdListener(
          onAdLoadedCallback: (ad) {
            debugPrint("✅ Native large loaded from ${ad.networkName}");
            isNativeAdLoaded = true;
            if (ad.nativeAd?.mediaContentAspectRatio != null) {
              mediaViewAspectRatio = ad.nativeAd!.mediaContentAspectRatio!;
            }
          },
          onAdLoadFailedCallback: (adUnitId, error) {
            debugPrint("❌ Native large failed: ${error.message}");
            isNativeAdLoaded = false;
          },
          onAdClickedCallback: (ad) => debugPrint("👆 Native clicked: ${ad.adUnitId}"),
          onAdRevenuePaidCallback: (ad) => debugPrint("💰 Native revenue: ${ad.revenue}"),
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xffefefef),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const MaxNativeAdIconView(width: 48, height: 48),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        MaxNativeAdTitleView(
                          maxLines: 1,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        MaxNativeAdAdvertiserView(
                          maxLines: 1,
                          style: TextStyle(fontSize: 10),
                        ),
                        MaxNativeAdStarRatingView(size: 10),
                      ],
                    ),
                  ),
                  const MaxNativeAdOptionsView(width: 20, height: 20),
                ],
              ),
              const SizedBox(height: 8),
              // Body text
              const MaxNativeAdBodyView(
                maxLines: 3,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              // Media View
              Expanded(
                child: AspectRatio(
                  aspectRatio: mediaViewAspectRatio,
                  child: const MaxNativeAdMediaView(),
                ),
              ),
              const SizedBox(height: 8),
              // CTA Button
              SizedBox(
                width: double.infinity,
                child: const MaxNativeAdCallToActionView(
                  style: ButtonStyle(
                    backgroundColor: MaterialStatePropertyAll(Color(0xff2d545e)),
                    textStyle: MaterialStatePropertyAll(
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget nativeAdSmall({double height = 110, double width = double.infinity}) {
    final MaxNativeAdViewController controller = MaxNativeAdViewController();

    return SizedBox(
      height: height,
      width: width,
      child: MaxNativeAdView(
        adUnitId: _nativeAdUnitId,
        controller: controller,
        listener: NativeAdListener(
          onAdLoadedCallback: (ad) {
            debugPrint("✅ Native small loaded from ${ad.networkName}");
          },
          onAdLoadFailedCallback: (adUnitId, error) {
            debugPrint("❌ Native small load failed: ${error.message}");
          },
          onAdClickedCallback: (ad) => debugPrint("👆 Native small clicked"),
          onAdRevenuePaidCallback: (ad) => debugPrint("💰 Native revenue: ${ad.revenue}"),
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const MaxNativeAdIconView(width: 40, height: 40),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MaxNativeAdTitleView(
                      maxLines: 1,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    MaxNativeAdBodyView(
                      maxLines: 1,
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MaxNativeAdCallToActionView(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              const MaxNativeAdOptionsView(width: 16, height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static Widget mrecAd({double height = 250, double width = 300}) {
    return CommonMrecAd(
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
    return CommonMrecAd(
      onAdLoadChanged: (isLoaded) {
        isMrecAdLoaded = isLoaded;
        debugPrint("MREC Loaded: $isLoaded");
      },
      height: height,
      width: width,
      showSwipeHint: true,
    );
  }

}
