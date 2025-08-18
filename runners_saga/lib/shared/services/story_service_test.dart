import 'story_service.dart';

/// Test file demonstrating the episode progression system
/// This is not a formal test, but a demonstration of the new functionality
void main() {
  print('🎬 Testing Episode Progression System\n');
  
  // Test progression table validation
  print('🔍 Validating progression table...');
  final validationResults = StoryService.validateProgressionTable();
  for (final result in validationResults) {
    print(result);
  }
  
  print('\n📊 Episode Progression Table:');
  final progressions = StoryService().getAllEpisodeProgressions();
  for (final entry in progressions.entries) {
    final progression = entry.value;
    print('  ${progression.episodeId}:');
    print('    Prerequisites: ${progression.prerequisites.isEmpty ? "None" : progression.prerequisites.join(", ")}');
    print('    Next Episodes: ${progression.nextEpisodes.isEmpty ? "Season Finale" : progression.nextEpisodes.join(", ")}');
    if (progression.unlockRequirements.isNotEmpty) {
      print('    Requirements: ${progression.unlockRequirements}');
    }
    print('');
  }
  
  // Test progression path finding
  print('🛤️ Testing progression paths:');
  final service = StoryService();
  
  // Test path to S01E03
  final pathToE03 = service.getProgressionPath('S01E03');
  print('  Path to S01E03: ${pathToE03.join(" → ")}');
  
  // Test dependent episodes
  final dependentOnE01 = service.getDependentEpisodes('S01E01');
  print('  Episodes dependent on S01E01: ${dependentOnE01.join(", ")}');
  
  print('  Note: This system only tracks episode completion/listening status');
  print('  User running stats are tracked separately and do not affect episode progression');
  
  print('\n✅ Episode progression system demonstration complete!');
}

/// Example usage of the progression system in a real app:
class ProgressionSystemExample {
  final StoryService _storyService = StoryService();
  
  /// Example: Check if user can unlock an episode
  Future<void> checkEpisodeUnlock(String userId, String episodeId) async {
    final canUnlock = await _storyService.canUnlockEpisode(userId, episodeId);
    print('User $userId can unlock $episodeId: $canUnlock');
  }
  
  /// Example: Get next recommended episode
  Future<void> getNextEpisode(String userId) async {
    final nextEpisode = await _storyService.getRecommendedNextEpisode(userId);
    if (nextEpisode != null) {
      print('Recommended next episode: ${nextEpisode.title}');
    } else {
      print('No episodes available');
    }
  }
  
  /// Example: Get user's overall progress
  Future<void> getUserProgress(String userId) async {
    final progress = await _storyService.getUserProgressionStatus(userId);
    print('User progress: ${progress.overallProgressPercentage.toStringAsFixed(1)}%');
    print('Completed episodes: ${progress.totalCompletedEpisodes}');
    
    for (final seasonStatus in progress.seasonStatuses.values) {
      print('  ${seasonStatus.seasonTitle}: ${seasonStatus.progressPercentage.toStringAsFixed(1)}%');
    }
  }
}
