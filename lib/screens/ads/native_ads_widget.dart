import 'package:flutter/material.dart';
import 'package:applovin_max/applovin_max.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as admob;  
import '../../helper/ad_helper.dart';
import '../../widgets/fancy_swipe_arrow.dart';
import '../../widgets/loading_ads_text.dart';

class NativeAdsWidget extends StatefulWidget {
  final double height;
  final double width;
  final bool showSwipeHint;
  final ValueChanged<bool>? onAdLoadChanged;
  final bool isMedium;

  const NativeAdsWidget({
    Key? key,
    this.height = 300,
    this.width = 300,
    this.showSwipeHint = true,
    this.onAdLoadChanged,
    this.isMedium = false,
  }) : super(key: key);

  @override
  State<NativeAdsWidget> createState() => _NativeAdsWidgetState();
}

class _NativeAdsWidgetState extends State<NativeAdsWidget> {
  bool _showAdMob = false;
  admob.NativeAd? _adMobNativeAd;
  bool _adMobLoaded = false;
  bool _appLovinLoaded = false;

  @override
  void dispose() {
    _adMobNativeAd?.dispose();
    super.dispose();
  }

  void _loadAdMobAd() {
    final adUnitId = AdHelper.admobNativeUnitId;
    _adMobNativeAd = admob.NativeAd(
      adUnitId: adUnitId,
      factoryId: widget.isMedium ? 'mediumTile' : 'listTile',
      request: const admob.AdRequest(),
      listener: admob.NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint("✅ AdMob native ad loaded");
          if (mounted) {
            setState(() {
              _adMobLoaded = true;
            });
            widget.onAdLoadChanged?.call(true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint("❌ AdMob native failed to load: $error");
          ad.dispose();
          if (mounted) {
            setState(() {
              _showAdMob = false;
              _adMobLoaded = false;
            });
            widget.onAdLoadChanged?.call(false);
          }
        },
      ),
    );

    _adMobNativeAd!.load();
  }

  @override
  Widget build(BuildContext context) {
    if (_showAdMob) {
      if (_adMobLoaded && _adMobNativeAd != null) {
        return Center(
          child: SizedBox(
            height: widget.isMedium ? 320 : 80,
            width: widget.width,
            child: Stack(
              children: [
                admob.AdWidget(ad: _adMobNativeAd!),
                if (!_adMobLoaded)
                  const Center(
                    child: LoadingAdsText(),
                  ),
                if (widget.showSwipeHint)
                  _buildSwipeHint(),
              ],
            ),
          ),
        );
      }
      return SizedBox(height: widget.height, width: widget.width);
    }

    return Center(
      child: SizedBox(
        height: widget.height,
        width: widget.width,
        child: Stack(
          alignment: Alignment.center,
          children: [
            MaxAdView(
              adUnitId: AdHelper.mrecAdUnitId,
              adFormat: AdFormat.mrec,
              listener: AdViewAdListener(
                onAdLoadedCallback: (ad) {
                  if (mounted) setState(() => _appLovinLoaded = true);
                  debugPrint("✅ AppLovin MREC loaded");
                  widget.onAdLoadChanged?.call(true);
                },
                onAdLoadFailedCallback: (adUnitId, error) {
                  debugPrint("❌ AppLovin MREC failed: ${error.message}");
                  widget.onAdLoadChanged?.call(false);
                  // fallback to AdMob
                  if (mounted) {
                    setState(() {
                      _showAdMob = true;
                      _appLovinLoaded = false;
                    });
                    _loadAdMobAd();
                  }
                },
                onAdClickedCallback: (ad) =>
                    debugPrint("👆 AppLovin clicked: ${ad.adUnitId}"),
                onAdRevenuePaidCallback: (ad) =>
                    debugPrint("💰 AppLovin revenue: ${ad.revenue}"),
                onAdExpandedCallback: (ad) {},
                onAdCollapsedCallback: (ad) {},
              ),
            ),
            if (!_appLovinLoaded)
              const Center(
                child: LoadingAdsText(),
              ),
            if (widget.showSwipeHint)
              _buildSwipeHint(),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeHint() {
    return const Positioned(
      bottom: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Swipe to next",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black45,
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
          SizedBox(height: 4),
          FancySwipeArrow(size: 50, color: Colors.white),
        ],
      ),
    );
  }

}
