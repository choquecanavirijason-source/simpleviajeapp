// lib/core/utils/countdown_controller.dart
import 'dart:async';
import 'package:flutter/material.dart';

class CountdownController extends ChangeNotifier {
  final int initialSeconds;
  Timer? _timer;
  int _secondsRemaining;

  CountdownController({this.initialSeconds = 3}) : _secondsRemaining = 3;

  int get secondsRemaining => _secondsRemaining;

  void start() {
    _timer?.cancel();
    _secondsRemaining = initialSeconds;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else {
        _secondsRemaining--;
        notifyListeners();
      }
    });
  }

  void disposeTimer() {
    _timer?.cancel();
  }
}
