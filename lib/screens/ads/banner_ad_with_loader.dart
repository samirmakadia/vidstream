import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../helper/ad_helper.dart';

class BannerAdWithLoader extends StatefulWidget {
  final double height;
  final Color? backgroundColor;

  const BannerAdWithLoader({
    super.key,
    this.height = 60,
    this.backgroundColor,
  });

  @override
  State<BannerAdWithLoader> createState() => _BannerAdWithLoaderState();
}

class _BannerAdWithLoaderState extends State<BannerAdWithLoader> {
  bool _isAppLovinLoaded = false;
  bool _isAppLovinFailed = false;

  BannerAd? _adMobBanner;
  bool _isAdMobLoaded = false;
  bool _isAdMobFailed = false;

  @override
  void initState() {
    super.initState();
    _loadAppLovin();
  }

  /// 🔹 Load AppLovin Banner
  void _loadAppLovin() {
    setState(() {
      _isAppLovinLoaded = false;
      _isAppLovinFailed = false;
    });
    // AppLovin banner is handled by MaxAdView directly in build
    // We'll just rely on callbacks to update states
  }

  /// 🔹 Load AdMob Banner
  void _loadAdMob() {
    debugPrint("🔄 Loading AdMob Banner...");
    _adMobBanner = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint("✅ AdMob Banner loaded");
          if (mounted) {
            setState(() {
              _isAdMobLoaded = true;
              _isAdMobFailed = false;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint("❌ AdMob Banner failed: $error");
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdMobFailed = true;
              _isAdMobLoaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    // 🔄 Show AppLovin first
    if (!_isAppLovinFailed) {
      return Container(
        width: double.infinity,
        color: widget.backgroundColor ?? Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            MaxAdView(
              adUnitId: AdHelper.banner,
              adFormat: AdFormat.banner,
              listener: AdViewAdListener(
                onAdLoadedCallback: (ad) {
                  debugPrint("✅ AppLovin Banner loaded: ${ad.networkName}");
                  if (mounted) setState(() => _isAppLovinLoaded = true);
                },
                onAdLoadFailedCallback: (adUnitId, error) {
                  debugPrint("❌ AppLovin failed: ${error.message}");
                  if (mounted) {
                    setState(() {
                      _isAppLovinFailed = true;
                    });
                    _loadAdMob(); // ➡️ Fallback to AdMob
                  }
                },
                onAdClickedCallback: (ad) => debugPrint("👆 Banner clicked"),
                onAdExpandedCallback: (ad) => debugPrint("🔼 Banner expanded"),
                onAdCollapsedCallback: (ad) => debugPrint("🔽 Banner collapsed"),
              ),
            ),
            if (!_isAppLovinLoaded)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 1,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
      );
    }

    // 🔄 If AppLovin failed, show AdMob
    if (_isAppLovinFailed && !_isAdMobFailed && _isAdMobLoaded) {
      return Container(
        width: MediaQuery.of(context).size.width,
        height: AdSize.banner.height.toDouble(),
        color: widget.backgroundColor ?? Colors.black,
        child: AdWidget(ad: _adMobBanner!),
      );
    }

    // ⏳ If AdMob is loading
    if (_isAppLovinFailed && !_isAdMobFailed && !_isAdMobLoaded) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }

    // ⚠️ Both failed → Skip
    if (_isAdMobFailed) {
      return const SizedBox.shrink();
    }

    // Default placeholder while waiting
    return SizedBox(
      height: widget.height,
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
    );
  }

  @override
  void dispose() {
    _adMobBanner?.dispose();
    super.dispose();
  }
}
