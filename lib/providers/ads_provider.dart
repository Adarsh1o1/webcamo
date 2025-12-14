import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:webcamo/utils/ad_helper.dart';
import 'package:webcamo/utils/logger.dart';

// 1. Define the Global Provider
final adsProvider = ChangeNotifierProvider<AdsProvider>((ref) {
  return AdsProvider();
});

class AdsProvider with ChangeNotifier {
  bool isWirelessBannerLoaded = false;
  bool isUsbBannerLoaded = false;

  late BannerAd wireless_banner;
  late BannerAd usb_banner;

  int _wirelessRetryAttempt = 0;
  int _usbRetryAttempt = 0;
  static const int _maxRetries = 3;

  void initializeWirelessBanner() async {
    wireless_banner = BannerAd(
      size: AdSize.banner,
      adUnitId: AdHelper.wireless_banner(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          Logger.log('wireless banner ad loaded!');
          isWirelessBannerLoaded = true;
          _wirelessRetryAttempt = 0; // Reset retry counter on success
          notifyListeners(); // <--- MOVE THIS HERE (Updates UI when ad is ready)
        },
        onAdClosed: (ad) {
          Logger.log("wirless ad closed!");
          ad.dispose();
          isWirelessBannerLoaded = false;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          Logger.log(
            "wirless ad load failed! code: ${error.code} message: ${error.message}",
          );
          isWirelessBannerLoaded = false;
          ad.dispose(); // Good practice to dispose on failure
          notifyListeners();

          if (_wirelessRetryAttempt < _maxRetries) {
            _wirelessRetryAttempt++;
            Logger.log(
              'Retrying wireless banner load (Attempt $_wirelessRetryAttempt of $_maxRetries)...',
            );
            Future.delayed(Duration(seconds: 2 * _wirelessRetryAttempt), () {
              initializeWirelessBanner();
            });
          }
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
          Logger.log('usb banner ad loaded!');
          isUsbBannerLoaded = true;
          _usbRetryAttempt = 0; // Reset retry counter on success
          notifyListeners(); // <--- MOVE THIS HERE
        },
        onAdClosed: (ad) {
          Logger.log('usb banner ad closed!');
          ad.dispose();
          isUsbBannerLoaded = false;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          Logger.log(
            'usb banner ad load failed! code: ${error.code} message: ${error.message}',
          );
          isUsbBannerLoaded = false;
          ad.dispose();
          notifyListeners();

          if (_usbRetryAttempt < _maxRetries) {
            _usbRetryAttempt++;
            Logger.log(
              'Retrying usb banner load (Attempt $_usbRetryAttempt of $_maxRetries)...',
            );
            Future.delayed(Duration(seconds: 2 * _usbRetryAttempt), () {
              initializeusbBanner();
            });
          }
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
