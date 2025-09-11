import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../helper/ad_helper.dart';


class GoogleAdsManager extends StatefulWidget {
  const GoogleAdsManager({super.key});

  @override
  State<GoogleAdsManager> createState() => GoogleAdsManagerState();
}

class GoogleAdsManagerState extends State<GoogleAdsManager> {
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  bool _isBannerLoaded = false;
  bool _isInterstitialLoaded = false;
  int _clickCount = 0;
  final int _countbase = 3;

  final String bannerAdUnitId = AdHelper.bannerAdUnitId;
  final String interstitialAdUnitId = AdHelper.interstitialAdUnitId;

  @override
  void initState() {
    super.initState();
    // Add a delay for iOS to ensure proper initialization
    final delay = Platform.isIOS ? const Duration(seconds: 2) : const Duration(milliseconds: 500);
    Future.delayed(delay, () {
      if (mounted) {
        print('📱 Initializing ads for ${Platform.isIOS ? "iOS" : "Android"}...');
        _loadBannerAd();
        _loadInterstitialAd();
      }
    });
  }



  void _loadBannerAd() {
    print('🔄 Loading Banner Ad...');
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('✅ BannerAd loaded successfully');
          setState(() {
            _isBannerLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ BannerAd failed to load: $error');
          ad.dispose();
          setState(() {
            _isBannerLoaded = false;
          });
          // Retry loading after a delay
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _loadBannerAd();
          });
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    print('🔄 Loading Interstitial Ad...');
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('✅ InterstitialAd loaded successfully');
          _interstitialAd = ad;
          setState(() {
            _isInterstitialLoaded = true;
          });
          _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('❌ InterstitialAd failed to show: $error');
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('❌ InterstitialAd failed to load: $error');
          setState(() {
            _isInterstitialLoaded = false;
          });
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _loadInterstitialAd();
          });
        },
      ),
    );
  }

  void handleClick(VoidCallback onNavigate) {
    setState(() {
      _clickCount++;
      if (_clickCount >= _countbase) {
        if (_isInterstitialLoaded && _interstitialAd != null) {
          _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
              onNavigate();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('InterstitialAd failed to show: $error');
              ad.dispose();
              _loadInterstitialAd();
              onNavigate();
            },
          );
          _interstitialAd?.show();
          _interstitialAd = null;
          _isInterstitialLoaded = false;
          _clickCount = 0;
        } else {
          debugPrint('Interstitial ad not ready yet.');
          _loadInterstitialAd();
          _clickCount = 0;
          onNavigate();
        }
      } else {
        onNavigate();
      }
    });
  }

  void showInterstitialAd() {
    if (_isInterstitialLoaded && _interstitialAd != null) {
      _interstitialAd?.show();
      _interstitialAd = null;
      setState(() {
        _isInterstitialLoaded = false;
      });
      _loadInterstitialAd();
    } else {
      debugPrint('Interstitial ad not ready yet.');
      _loadInterstitialAd();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: AdSize.banner.height.toDouble(),
      color: Theme.of(context).colorScheme.background,
      child: _isBannerLoaded
          ? Center(
        child: AdWidget(ad: _bannerAd!),
      )
          : const Center(
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
          ),
        ),
      ),
    );
  }
}