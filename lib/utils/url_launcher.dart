import 'package:flutter/material.dart';
import 'package:webcamo/utils/constants.dart';
import 'package:webcamo/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherUtil {
  UrlLauncherUtil._();

  static Future<void> _launchUrl(String url, LaunchMode launchMode) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      try {
        await launchUrl(uri, mode: launchMode);
        Logger.log('Successfully launched URL: $url', name: 'UrlLauncher');
      } catch (e) {
        Logger.log(
          'Could not launch URL: $url. Error: $e',
          name: 'UrlLauncher',
          error: true,
        );
        ScaffoldMessenger(
          child: SnackBar(content: Text('Could not open the link.')),
        );
      }
    } else {
      Logger.log('Cannot launch URL: $url', name: 'UrlLauncher', error: true);
      ScaffoldMessenger(
        child: SnackBar(content: Text('Invalid or unsupported link.')),
      );
    }
  }

  static Future<void> launchInAppView(String url) async {
    await _launchUrl(url, LaunchMode.inAppWebView);
  }

  static Future<void> launchPhoneNumber({String? phoneNumber}) async {
    final String number = phoneNumber ?? AppConstants.SUPPORT_PHONE_NUMBER;
    await _launchUrl('tel:$number', LaunchMode.externalApplication);
  }

  static Future<void> launchEmail({String? emailAddress}) async {
    final String email = emailAddress ?? AppConstants.SUPPORT_EMAIL;
    await _launchUrl('mailto:$email', LaunchMode.externalApplication);
  }

  static Future<void> launchWhatsApp({
    String? phoneNumber,
    String? message,
  }) async {
    final String number = phoneNumber ?? AppConstants.SUPPORT_WHATSAPP_NUMBER;

    final String? encodedMessage = message != null
        ? Uri.encodeComponent(message)
        : null;

    String whatsappUrl = 'https://wa.me/$number';

    if (encodedMessage != null) {
      whatsappUrl = '$whatsappUrl?text=$encodedMessage';
    }

    await _launchUrl(whatsappUrl, LaunchMode.externalApplication);
  }
}
