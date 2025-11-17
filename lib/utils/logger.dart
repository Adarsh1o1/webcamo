import 'package:flutter/foundation.dart';

class Logger {
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _yellow = '\x1B[33m';

  static void log(String message, {String name = 'APP', bool error = false}) {
    if (kDebugMode) {
      final color = error ? _red : _yellow;
      print('$color[${name.toUpperCase()}] $message$_reset');
    }
  }
}
