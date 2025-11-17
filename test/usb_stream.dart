import 'dart:async';
import 'package:flutter/services.dart';

class CamstreamPlugin {
  static const MethodChannel _channel = MethodChannel('camstream_plugin');

  /// Start the camera streaming service on Android.
  ///
  /// [port] - TCP port the service will listen on (default 5000).
  /// [width],[height],[fps],[bitrate] - encoder settings.
  static Future<bool> start({
    int port = 23233,
    int width = 1280,
    int height = 720,
    int fps = 30,
    int bitrate = 2000000,
  }) async {
    final res = await _channel.invokeMethod('start', {
      'port': port,
      'width': width,
      'height': height,
      'fps': fps,
      'bitrate': bitrate,
    });
    return res == true;
  }

  /// Stop the camera streaming service.
  static Future<bool> stop() async {
    final res = await _channel.invokeMethod('stop');
    return res == true;
  }

  /// Query status: 'stopped'|'running'
  static Future<String> status() async {
    final res = await _channel.invokeMethod('status');
    return res as String;
  }
}
