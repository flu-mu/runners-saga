import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/run_enums.dart';
import '../../models/run_stats_model.dart';
import '../../providers/coach_providers.dart';
import '../../providers/settings_providers.dart';
import '../audio/audio_scheduler_service.dart';

/// Provider for the CoachService.
final coachServiceProvider = Provider<CoachService>((ref) {
  return CoachService(ref);
});

/// A service to handle text-to-speech (TTS) readouts for run statistics.
class CoachService {
  final Ref _ref;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  CoachService(this._ref) {
    _initTts();
  }

  /// Initializes the TTS engine and sets handlers.
  void _initTts() {
    final audioScheduler = _ref.read(audioSchedulerServiceProvider);
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
      // In Phase 4, we'll use this to notify other services to pause audio.
    });
    _flutterTts.setCompletionHandler(() {
      audioScheduler.playbackComplete();
      _isSpeaking = false;
      // In Phase 4, we'll use this to notify other services to resume audio.
    });
    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
  }

  /// Constructs the readout string and speaks it.
  Future<void> performReadout({
    required Duration elapsedTime,
    required double distance,
    required double averagePace,
    int? heartRate,
  }) async {
    final coachEnabled = _ref.read(coachEnabledProvider);
    if (!coachEnabled) return;

    final statsToRead = _ref.read(coachStatsProvider);
    if (statsToRead.isEmpty) return;

    final audioScheduler = _ref.read(audioSchedulerServiceProvider);

    // Create a high-priority audio request.
    final request = AudioRequest(
      priority: AudioPriority.high,
      playFunction: () async {
        final readoutString = await _buildReadoutString(elapsedTime, distance, averagePace, heartRate, statsToRead);
        if (readoutString.isNotEmpty) {
          await _flutterTts.speak(readoutString);
        } else {
          // If there's nothing to say, complete immediately so the queue can proceed.
          audioScheduler.playbackComplete();
        }
      },
    );

    audioScheduler.add(request);
  }

  /// Builds the string to be read out by the TTS engine.
  Future<String> _buildReadoutString(Duration elapsedTime, double distance, double averagePace, int? heartRate, Set<CoachStat> statsToRead) async {
    final settingsService = _ref.read(settingsServiceProvider);
    final parts = <String>[];

    // The order can be customized later if needed.
    for (final stat in statsToRead) {
      switch (stat) {
        case CoachStat.time:
          final minutes = elapsedTime.inMinutes;
          final seconds = elapsedTime.inSeconds % 60;
          parts.add('Time: $minutes minutes, $seconds seconds.');
          break;
        case CoachStat.distance:
          final distanceString = await settingsService.formatDistance(distance);
          parts.add('Distance: $distanceString.');
          break;
        case CoachStat.pace:
          // Using average pace for the readout. Could be currentPace as well.
          final paceString = await settingsService.formatPace(averagePace);
          parts.add('Pace: $paceString.');
          break;
        case CoachStat.heartRate:
          if (heartRate != null && heartRate > 0) {
            parts.add('Heart rate: $heartRate beats per minute.');
          }
          break;
        case CoachStat.splitPace:
          // This requires split data, which would be added to the RunStats model
          // or passed in separately. For now, we'll skip it.
          break;
      }
    }
    return parts.join(' ');
  }
}