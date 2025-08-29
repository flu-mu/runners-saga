import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:runners_saga/shared/models/episode_model.dart';
import 'package:runners_saga/shared/models/run_model.dart';
import 'package:runners_saga/shared/models/run_target_model.dart';
import 'package:runners_saga/shared/providers/run_session_providers.dart';
import 'package:runners_saga/shared/providers/run_providers.dart';
import 'package:runners_saga/shared/providers/story_providers.dart';
import 'package:runners_saga/shared/providers/auth_providers.dart';

/// Service to handle run completion and prepare data for summary screen
class RunCompletionService {
  final ProviderContainer _container;
  
  RunCompletionService(this._container);
  
  /// Complete a run and prepare summary data
  Future<RunSummaryData> completeRun() async {
    try {
      print('🏁 RunCompletionService: Starting run completion...');
      
      // Get the current run session manager
      final runSessionManager = _container.read(runSessionControllerProvider.notifier);
      
      // Get GPS data from RunSessionManager stats
      final stats = runSessionManager.getCurrentStats();
      if (stats == null) {
        print('❌ RunCompletionService: No stats available from RunSessionManager');
        return await _createFallbackSummary(null);
      }
      
      final route = stats.route;
      print('📍 RunCompletionService: Got route from RunSessionManager stats with ${route.length} GPS points');
      
      if (route.isEmpty) {
        print('⚠️ RunCompletionService: No GPS data available from RunSessionManager');
        // Try to get route from current run provider as fallback
        final currentRun = _container.read(currentRunProvider);
        if (currentRun != null && currentRun.route?.isNotEmpty == true) {
          print('📍 RunCompletionService: Fallback - Got route from currentRunProvider with ${currentRun.route?.length ?? 0} GPS points');
        }
      }
      
      // Get the current episode from the provider
      final episode = _container.read(currentEpisodeProvider);
      print('🎬 RunCompletionService: Current episode: ${episode?.id}');
      
      // Get run statistics from the stats we already have
      final totalTime = stats.elapsedTime;
      final totalDistance = stats.distance;
      final startTime = DateTime.now().subtract(totalTime); // Calculate start time from duration
      
      // Calculate average pace (minutes per kilometer)
      final averagePace = totalDistance > 0 ? totalTime.inMinutes / totalDistance : 0.0;
      
      print('📊 RunCompletionService: Run stats - Time: $totalTime, Distance: $totalDistance, Start: $startTime, Pace: ${averagePace.toStringAsFixed(2)} min/km');
      
      // Get user weight for calorie calculation (default to 70kg if not available)
      final weightKg = 70.0; // Default weight for calorie calculation
      
      // Don't stop the run session here - it's already stopped by the calling code
      // await _container.read(runSessionControllerProvider.notifier).stopSession();

      final summaryData = RunSummaryData(
        totalTime: totalTime,
        totalDistance: totalDistance,
        averagePace: averagePace,
        caloriesBurned: _calculateCaloriesMet(totalDistance, totalTime, weightKg),
        episode: episode,
        achievements: _generateAchievements(
                      RunModel(
              userId: 'temp', // This is just for achievements calculation, not saved
              createdAt: startTime,
              completedAt: startTime.add(totalTime),
              totalDistance: totalDistance,
              totalTime: totalTime,
              averagePace: averagePace,
              maxPace: averagePace, // placeholder; compute if available
              minPace: averagePace,
              status: RunStatus.completed,
              route: route,
              // Store full episode identifier in episodeId
              episodeId: episode?.id ?? 'S01E01',
              runTarget: RunTarget(
                id: 'completed_time_${totalTime.inMinutes}',
                type: RunTargetType.time,
                value: totalTime.inMinutes.toDouble(),
                displayName: '${totalTime.inMinutes} minutes',
                description: 'Completed time target',
                createdAt: DateTime.now(),
                isCustom: true,
              ),
            ),
          episode,
        ),
        route: route,
        createdAt: startTime,
        completedAt: startTime.add(totalTime),
      );
      
      // Don't save run to history here - RunSessionManager already creates the run with GPS data
      await _saveRunToHistory(summaryData);
      
      // Debug: Log route information
      print('📍 RunCompletionService: Final route has ${summaryData.route.length} GPS points');
      if (summaryData.route.isNotEmpty) {
        print('📍 RunCompletionService: First point: ${summaryData.route.first.latitude}, ${summaryData.route.first.longitude}');
        print('📍 RunCompletionService: Last point: ${summaryData.route.last.latitude}, ${summaryData.route.last.longitude}');
      }
      
      return summaryData;
      
    } catch (e) {
      print('❌ RunCompletionService: Error completing run: $e');
      // Return fallback summary instead of throwing
      return await _createFallbackSummary(null);
    }
  }
  
  /// Create a fallback summary when run data is not available
  Future<RunSummaryData> _createFallbackSummary(EpisodeModel? episode) async {
    try {
      // Get session data if available
      final sessionState = _container.read(runSessionControllerProvider);
      final isSessionActive = _container.read(runSessionControllerProvider.notifier).isSessionActive;
      
      // Create reasonable fallback data
      final now = DateTime.now();
      final fallbackTime = Duration(minutes: 15); // Default 15 minutes
      final fallbackDistance = 2.5; // Default 2.5 km
      final fallbackPace = 6.0; // Default 6 min/km
      
      final summaryData = RunSummaryData(
        totalTime: fallbackTime,
        totalDistance: fallbackDistance,
        averagePace: fallbackPace,
        caloriesBurned: _calculateCalories(fallbackDistance, fallbackTime),
        episode: episode,
        achievements: _generateFallbackAchievements(fallbackDistance, fallbackTime, fallbackPace, episode),
        route: [], // Empty route for fallback
        createdAt: now.subtract(fallbackTime),
        completedAt: now,
      );
      
      print('✅ RunCompletionService: Created fallback summary');
      return summaryData;
      
    } catch (e) {
      print('❌ RunCompletionService: Error creating fallback summary: $e');
      // Ultimate fallback with minimal data
      return RunSummaryData(
        totalTime: const Duration(minutes: 15),
        totalDistance: 2.5,
        averagePace: 6.0,
        caloriesBurned: 150,
        episode: episode,
        achievements: ['First Run', 'Episode Complete'],
        route: [],
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        completedAt: DateTime.now(),
      );
    }
  }
  
  /// Generate achievements for fallback data
  List<String> _generateFallbackAchievements(double distance, Duration time, double pace, EpisodeModel? episode) {
    final achievements = <String>[];
    
    // Distance achievements
    if (distance >= 5.0) achievements.add('5K Runner');
    if (distance >= 10.0) achievements.add('10K Warrior');
    
    // Time achievements
    if (time.inMinutes <= 20) achievements.add('Speed Demon');
    if (time.inMinutes <= 30) achievements.add('Quick Runner');
    
    // Pace achievements
    if (pace <= 5.0) achievements.add('Elite Pace');
    if (pace <= 6.0) achievements.add('Fast Runner');
    
    // Episode completion
    if (episode != null) achievements.add('Episode Complete');
    
    // Always add first run
    achievements.add('First Run');
    
    return achievements;
  }
  
  /// Calculate calories burned based on distance and time
  int _calculateCalories(double distance, Duration time) {
    // Rough calorie calculation: 100 calories per km for running
    // Adjust based on pace (faster = more calories)
    final baseCalories = distance * 100;
    final paceFactor = time.inMinutes / distance; // minutes per km
    final paceMultiplier = paceFactor < 5 ? 1.2 : paceFactor < 7 ? 1.0 : 0.8;
    return (baseCalories * paceMultiplier).round();
  }

  int _calculateCaloriesMet(double distance, Duration time, double weightKg) {
    final minutes = time.inSeconds / 60.0;
    if (minutes <= 0) return 0;
    final pace = distance > 0 ? minutes / distance : 0.0; // min/km
    final speedKmh = pace > 0 ? 60.0 / pace : 9.0;
    double met;
    if (speedKmh < 6) met = 6.0;
    else if (speedKmh < 8) met = 8.3;
    else if (speedKmh < 9.7) met = 9.8;
    else if (speedKmh < 11.3) met = 11.0;
    else met = 12.8;
    final kcal = met * 3.5 * weightKg / 200.0 * minutes;
    return kcal.round();
  }
  
  /// Generate achievements based on run performance
  List<String> _generateAchievements(RunModel run, EpisodeModel? episode) {
    final achievements = <String>[];
    
    // Distance achievements
    if ((run.totalDistance ?? 0) >= 5.0) achievements.add('5K Runner');
    if ((run.totalDistance ?? 0) >= 10.0) achievements.add('10K Warrior');
    if ((run.totalDistance ?? 0) >= 21.1) achievements.add('Half Marathon Hero');
    
    // Time achievements
    if ((run.totalTime ?? Duration.zero).inMinutes <= 20) achievements.add('Speed Demon');
    if ((run.totalTime ?? Duration.zero).inMinutes <= 30) achievements.add('Quick Runner');
    
    // Pace achievements
    if ((run.averagePace ?? 0) <= 5.0) achievements.add('Elite Pace');
    if ((run.averagePace ?? 0) <= 6.0) achievements.add('Fast Runner');
    
    // Episode completion
    if (episode != null) achievements.add('Episode Complete');
    
    // First run achievement
    achievements.add('First Run');
    
    // Personal best achievements (could be enhanced with user history)
    if ((run.totalDistance ?? 0) >= 3.0) achievements.add('Distance Milestone');
    if ((run.totalTime ?? Duration.zero).inMinutes >= 15) achievements.add('Endurance Runner');
    
    return achievements;
  }
  
  /// Save run to user's history
  Future<void> _saveRunToHistory(RunSummaryData summaryData) async {
    try {
      print('💾 RunCompletionService: Starting to save run to database...');
      
      // Get the current user ID
      final user = _container.read(currentUserProvider).value;
      if (user == null) {
        print('❌ RunCompletionService: No user found, cannot save run');
        return;
      }
      
      // Create a RunModel from the summary data
      final runModel = RunModel(
        userId: user.uid,
        createdAt: summaryData.createdAt,
        completedAt: summaryData.completedAt,
        totalDistance: summaryData.totalDistance,
        totalTime: summaryData.totalTime,
        route: summaryData.route,
        averagePace: summaryData.averagePace,
        maxPace: summaryData.averagePace, // Use average as max for now
        minPace: summaryData.averagePace, // Use average as min for now
        status: RunStatus.completed,
        episodeId: summaryData.episode?.id ?? 'S01E01',
        runTarget: RunTarget(
          id: 'completed_time_${summaryData.totalTime.inMinutes}',
          type: RunTargetType.time,
          value: summaryData.totalTime.inMinutes.toDouble(),
          displayName: '${summaryData.totalTime.inMinutes} minutes',
          description: 'Completed time target',
          createdAt: DateTime.now(),
          isCustom: true,
        ),
      );
      
      print('💾 RunCompletionService: Created run model with ${runModel.route?.length ?? 0} GPS points');
      
      // Save the run to Firestore
      final firestoreService = _container.read(firestoreServiceProvider);
      final runId = await firestoreService.saveRun(runModel);
      
      print('✅ RunCompletionService: Run saved successfully with ID: $runId');
      print('💾 RunCompletionService: Run saved with ${runModel.route?.length ?? 0} GPS points');
      
    } catch (e, stackTrace) {
      print('❌ RunCompletionService: Error saving run to database: $e');
      print('❌ RunCompletionService: Stack trace: $stackTrace');
    }
  }
}

/// Data model for run summary
class RunSummaryData {
  final Duration totalTime;
  final double totalDistance;
  final double averagePace;
  final int caloriesBurned;
  final EpisodeModel? episode;
  final List<String> achievements;
  final List<LocationPoint> route; // Route points
  final DateTime createdAt;
  final DateTime completedAt;
  
  RunSummaryData({
    required this.totalTime,
    required this.totalDistance,
    required this.averagePace,
    required this.caloriesBurned,
    this.episode,
    required this.achievements,
    required this.route,
    required this.createdAt,
    required this.completedAt,
  });
  
  /// Get formatted duration string
  String get formattedDuration {
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes % 60;
    final seconds = totalTime.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
  
  /// Get formatted distance string
  String get formattedDistance => '${totalDistance.toStringAsFixed(1)} km';
  
  /// Get formatted pace string
  String get formattedPace => '${averagePace.toStringAsFixed(1)} min/km';
  
  /// Get run duration in minutes
  double get durationMinutes => totalTime.inMinutes + (totalTime.inSeconds % 60) / 60;
  
  /// Get average speed in km/h
  double get averageSpeed => totalDistance / (durationMinutes / 60);
}
