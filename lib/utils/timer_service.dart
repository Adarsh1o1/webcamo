import 'dart:async';

class TimerService {
  Timer? _screenOnTimer;
  int _secondsElapsed = 0;

  void startTimer() {
    _screenOnTimer?.cancel();
    
    _secondsElapsed = 0;
    
    _screenOnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsElapsed++;
    });
  }

  double stopTimer() {
    _screenOnTimer?.cancel();
    _screenOnTimer = null;

    double minutes = _secondsElapsed / 60.0;
    
    return minutes;
  }
}