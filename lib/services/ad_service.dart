import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/constants.dart';

class AdService {
  InterstitialAd? _interstitialAd;
  int _scanCount = 0;

  Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    if (kIsWeb) return;
    InterstitialAd.load(
      adUnitId: AppConstants.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          print('InterstitialAd failed to load: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  void incrementScanCountAndShowAdIfNeeded(bool isPremium) {
    if (isPremium) return;

    _scanCount++;
    if (_scanCount >= 2) {
      if (_interstitialAd != null) {
        _interstitialAd!.show();
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _scanCount = 0;
            _loadInterstitialAd(); // Load the next ad
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            _scanCount = 0;
            _loadInterstitialAd();
          },
        );
      } else {
        // If ad wasn't ready, try loading it again
        _loadInterstitialAd();
      }
    }
  }

  BannerAd? createBannerAd() {
    if (kIsWeb) return null;
    return BannerAd(
      adUnitId: AppConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => print('BannerAd loaded.'),
        onAdFailedToLoad: (ad, error) {
          print('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    );
  }
}
