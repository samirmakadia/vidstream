import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import '../helper/ad_helper.dart';

class BannerAdWithLoader extends StatefulWidget {
  final double height;
  final Color? backgroundColor;

  const BannerAdWithLoader({super.key, this.height = 60, this.backgroundColor});

  @override
  State<BannerAdWithLoader> createState() => _BannerAdWithLoaderState();
}

class _BannerAdWithLoaderState extends State<BannerAdWithLoader> {
  bool _isBannerLoaded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: widget.backgroundColor ?? Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          MaxAdView(
            adUnitId: AdUnitIds.banner,
            adFormat: AdFormat.banner,
            listener: AdViewAdListener(
              onAdLoadedCallback: (ad) {
                debugPrint("✅ Banner loaded: ${ad.networkName}");
                if (mounted) setState(() => _isBannerLoaded = true);
              },
              onAdLoadFailedCallback: (adUnitId, error) {
                debugPrint("❌ Banner load failed: ${error.message}");
              },
              onAdRevenuePaidCallback: (ad) {
                debugPrint("💰 Revenue paid for Banner: ${ad.adUnitId}");
              },
              onAdClickedCallback: (ad) => debugPrint("👆 Banner clicked"),
              onAdExpandedCallback: (ad) => debugPrint("🔼 Banner expanded"),
              onAdCollapsedCallback: (ad) => debugPrint("🔽 Banner collapsed"),
            ),
          ),
          if (!_isBannerLoaded)
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

  @override
  void initState() {
    super.initState();
    _isBannerLoaded = false;
  }
}
