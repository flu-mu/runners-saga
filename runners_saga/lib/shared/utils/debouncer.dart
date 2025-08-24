import 'dart:async';
import 'package:flutter/foundation.dart';

/// A utility class that debounces function calls to improve performance
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// Debounce a function call
  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancel any pending debounced calls
  void cancel() {
    _timer?.cancel();
  }

  /// Check if there's a pending debounced call
  bool get isActive => _timer?.isActive ?? false;

  /// Dispose the debouncer
  void dispose() {
    _timer?.cancel();
  }
}

/// A debouncer specifically for search input
class SearchDebouncer extends Debouncer {
  SearchDebouncer() : super(delay: const Duration(milliseconds: 500));
}

/// A debouncer for rapid UI updates
class UIDebouncer extends Debouncer {
  UIDebouncer() : super(delay: const Duration(milliseconds: 100));
}

/// A debouncer for network requests
class NetworkDebouncer extends Debouncer {
  NetworkDebouncer() : super(delay: const Duration(milliseconds: 1000));
}








