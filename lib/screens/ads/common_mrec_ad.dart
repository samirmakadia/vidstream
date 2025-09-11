import 'package:flutter/material.dart';
import 'package:applovin_max/applovin_max.dart';
import '../../helper/ad_helper.dart';
import '../../widgets/fancy_swipe_arrow.dart';

class CommonMrecAd extends StatelessWidget {
  final double height;
  final double width;
  final bool showSwipeHint;
  final ValueChanged<bool>? onAdLoadChanged;

  const CommonMrecAd({
    Key? key,
    this.height = 300,
    this.width = 300,
    this.showSwipeHint = true,
    this.onAdLoadChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: height,
        width: width,
        child: Stack(
          alignment: Alignment.center,
          children: [
            MaxAdView(
              adUnitId: AdHelper.mrecAdUnitId,
              adFormat: AdFormat.mrec,
              listener: AdViewAdListener(
                onAdLoadedCallback: (ad) {
                  debugPrint("✅ Large MREC loaded");
                  onAdLoadChanged?.call(true);
                },
                onAdLoadFailedCallback: (adUnitId, error) {
                  debugPrint("❌ Large MREC load failed: ${error.message}");
                  onAdLoadChanged?.call(false);
                },
                onAdClickedCallback: (ad) =>
                    debugPrint("👆 Large MREC clicked: ${ad.adUnitId}"),
                onAdRevenuePaidCallback: (ad) =>
                    debugPrint("💰 Large MREC revenue: ${ad.revenue}"),
                onAdExpandedCallback: (MaxAd ad) {},
                onAdCollapsedCallback: (MaxAd ad) {},
              ),
            ),
            if (showSwipeHint)
              Positioned(
                bottom: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
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
              ),
          ],
        ),
      ),
    );
  }
}
