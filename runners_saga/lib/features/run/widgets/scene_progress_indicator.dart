import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_theme.dart';
import '../../../shared/providers/run_session_providers.dart';
import '../../../shared/services/story/scene_trigger_service.dart';

class SceneProgressIndicator extends ConsumerWidget {
  const SceneProgressIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentScene = ref.watch(currentSceneProvider);
    
    if (currentScene == null) {
      return const SizedBox.shrink();
    }

    // Calculate progress based on scene type only (sessionState not needed for this calculation)
    final progress = _calculateSceneProgress(currentScene);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceBase.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDeepTeal.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scene title and progress bar
          Row(
            children: [
              Expanded(
                child: Text(
                  SceneTriggerService.getSceneTitle(currentScene),
                  style: TextStyle(
                    color: kTextHigh,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: kDeepTeal,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: kSurfaceElev.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(kDeepTeal),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          
          const SizedBox(height: 8),
          
          // Scene description
          Text(
            _getSceneDescription(currentScene),
            style: TextStyle(
              color: kTextMid,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Calculate progress for the current scene based on scene type
  double _calculateSceneProgress(SceneType sceneType) {
    // This is a simplified calculation - in a real app, you'd track actual scene progress
    switch (sceneType) {
      case SceneType.scene1:
        return 0.2;
      case SceneType.scene2:
        return 0.4;
      case SceneType.scene3:
        return 0.6;
      case SceneType.scene4:
        return 0.8;
      case SceneType.scene5:
        return 1.0;
      default:
        return 0.5;
    }
  }
  
  /// Get a brief description for each scene type
  String _getSceneDescription(SceneType sceneType) {
    switch (sceneType) {
      case SceneType.scene1:
        return 'Scene 1 in progress...';
      case SceneType.scene2:
        return 'Scene 2 in progress...';
      case SceneType.scene3:
        return 'Scene 3 in progress...';
      case SceneType.scene4:
        return 'Scene 4 in progress...';
      case SceneType.scene5:
        return 'Scene 5 in progress...';
      default:
        return 'Story in progress...';
    }
  }
}
