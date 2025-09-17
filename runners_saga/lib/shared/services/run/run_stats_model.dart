import 'package:runners_saga/shared/models/run_model.dart';
import 'package:runners_saga/shared/services/story/scene_trigger_service.dart';

class RunStats {
  final double distance;
  final Duration elapsedTime;
  final double currentPace;
  final double averagePace;
  final double? maxPace;
  final double? minPace;
  final int? heartRate;
  final double progress;
  final List<SceneType> playedScenes;
  final SceneType? currentScene;
  final List<LocationPoint> route;

  const RunStats({
    required this.distance,
    required this.elapsedTime,
    required this.currentPace,
    required this.averagePace,
    this.maxPace,
    this.minPace,
    this.heartRate,
    required this.progress,
    required this.playedScenes,
    this.currentScene,
    required this.route,
  });
}