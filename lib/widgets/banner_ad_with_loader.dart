import 'package:flutter/material.dart';
import '../manager/app_open_ad_manager.dart';

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
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _isBannerLoaded = AppLovinAdManager.isBannerLoaded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.backgroundColor ?? Colors.black,
      width: MediaQuery.of(context).size.width,
      child: _isBannerLoaded
          ? AppLovinAdManager.bannerAdWidget()
          : Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 1,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
