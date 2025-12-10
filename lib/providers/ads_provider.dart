import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:webcamo/utils/ad_helper.dart';

// 1. Define the Global Provider
final adsProvider = ChangeNotifierProvider<AdsProvider>((ref) {
  return AdsProvider();
});

class AdsProvider with ChangeNotifier {
  bool isWirelessBannerLoaded = false;
  bool isUsbBannerLoaded = false;

  late BannerAd wireless_banner;
  late BannerAd usb_banner;

  void initializeWirelessBanner() async {
    wireless_banner = BannerAd(
      size: AdSize.banner,
      adUnitId: AdHelper.wireless_banner(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('wireless banner ad loaded!');
          isWirelessBannerLoaded = true;
          notifyListeners(); // <--- MOVE THIS HERE (Updates UI when ad is ready)
        },
        onAdClosed: (ad) {
          print("wirless ad closed!");
          ad.dispose();
          isWirelessBannerLoaded = false;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          print("wirless ad load failed!");
          print(error.toString());
          isWirelessBannerLoaded = false;
          ad.dispose(); // Good practice to dispose on failure
          notifyListeners();
        },
      ),
      request: const AdRequest(),
    );

    await wireless_banner.load();
    // notifyListeners(); <--- REMOVE FROM HERE
  }

  void initializeusbBanner() async {
    usb_banner = BannerAd(
      size: AdSize.banner,
      adUnitId: AdHelper.usb_banner(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('usb banner ad loaded!');
          isUsbBannerLoaded = true;
          notifyListeners(); // <--- MOVE THIS HERE
        },
        onAdClosed: (ad) {
          print('usb banner ad closed!');
          ad.dispose();
          isUsbBannerLoaded = false;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          print('usb banner ad load failed!');
          print(error.toString());
          isUsbBannerLoaded = false;
          ad.dispose();
          notifyListeners();
        },
      ),
      request: const AdRequest(),
    );

    await usb_banner.load();
  }

  // Don't forget to dispose ads when the app closes (optional but recommended)
  @override
  void dispose() {
    wireless_banner.dispose();
    usb_banner.dispose();
    super.dispose();
  }
}
