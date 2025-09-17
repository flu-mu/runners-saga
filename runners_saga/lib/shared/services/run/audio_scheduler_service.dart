import 'dart:async';
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Enum for audio priority
enum AudioPriority {
  high, // For coach readouts
  normal, // For story scenes
}

// Class to represent an audio request
class AudioRequest {
  final Future<void> Function() playFunction;
  final AudioPriority priority;
  final Function? onComplete;

  AudioRequest({
    required this.playFunction,
    required this.priority,
    this.onComplete,
  });
}

/// Provider for the AudioSchedulerService.
final audioSchedulerServiceProvider = Provider<AudioSchedulerService>((ref) {
  return AudioSchedulerService();
});

/// A service to manage a priority queue for audio playback.
class AudioSchedulerService {
  final Queue<AudioRequest> _queue = Queue<AudioRequest>();
  bool _isPlaying = false;

  /// Adds an audio request to the queue.
  void add(AudioRequest request) {
    if (request.priority == AudioPriority.high) {
      _queue.addFirst(request);
    } else {
      _queue.addLast(request);
    }
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isPlaying || _queue.isEmpty) return;
    _isPlaying = true;
    final request = _queue.removeFirst();
    await request.playFunction();
  }

  void playbackComplete() {
    _isPlaying = false;
    _processQueue();
  }
}