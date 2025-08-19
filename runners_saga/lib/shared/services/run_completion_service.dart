import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/run_model.dart';
import '../models/episode_model.dart';
import '../providers/run_providers.dart';
import 'firestore_service.dart';
import '../providers/run_session_providers.dart';
import '../providers/settings_providers.dart';
import '../models/run_target_model.dart';
import '../../main.dart'; // Import to access isFirebaseReady

/// Service to handle run completion and prepare data for summary screen
class RunCompletionService {
  final ProviderContainer _container;
  
  RunCompletionService(this._container);
  
  /// Complete the current run and prepare summary data
  Future<RunSummaryData> completeRun() async {
    try {
      // Prefer live stats from session
      final stats = _container.read(currentRunStatsProvider);
      final episode = _container.read(currentRunEpisodeProvider);
      final weightKg = _container.read(userWeightKgProvider);

      Duration totalTime;
      double totalDistance;
      double averagePace;
      List<LocationPoint> route = [];
      DateTime startTime = DateTime.now();
      
      if (stats != null && (stats.elapsedTime > Duration.zero || stats.distance > 0)) {
        totalTime = stats.elapsedTime;
        totalDistance = stats.distance;
        averagePace = stats.averagePace > 0
            ? stats.averagePace
            : (totalDistance > 0 ? (totalTime.inSeconds / 60) / totalDistance : 0);
        
        // Get route from RunSessionManager stats (includes GPS route)
        final runSessionManager = _container.read(runSessionControllerProvider.notifier);
        if (runSessionManager != null) {
          final stats = runSessionManager.getCurrentStats();
          if (stats != null) {
            route = stats.route;
            startTime = DateTime.now().subtract(totalTime); // Calculate start time from duration
            
            print('📍 RunCompletionService: Got route from RunSessionManager stats with ${route.length} GPS points');
          }
        }
        
        // Fallback to currentRunProvider if no route from session manager
        if (route.isEmpty) {
          final run = _container.read(currentRunProvider);
          if (run != null) {
            route = run.route;
            startTime = run.startTime;
            print('📍 RunCompletionService: Fallback to currentRunProvider with ${route.length} GPS points');
          }
        }
      } else {
        // Fallback to run provider data
        final run = _container.read(currentRunProvider);
        if (run != null) {
          totalTime = run.totalTime;
          totalDistance = run.totalDistance;
          averagePace = run.averagePace;
          route = run.route;
          startTime = run.startTime;
        } else {
          // As a last resort, use defaults
          totalTime = const Duration(minutes: 15);
          totalDistance = 2.5;
          averagePace = 6.0;
        }
      }

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
            startTime: startTime,
            endTime: startTime.add(totalTime),
            totalDistance: totalDistance,
            totalTime: totalTime,
            averagePace: averagePace,
            maxPace: averagePace, // placeholder; compute if available
            minPace: averagePace,
            status: RunStatus.completed,
            route: route,
            // Store full episode identifier in seasonId per request (e.g., S01E01)
            seasonId: episode?.id ?? 'S01E01',
            missionId: episode?.id ?? 'S01E01',
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
        startTime: startTime,
        endTime: startTime.add(totalTime),
      );
      
      // Don't save run to history here - RunSessionManager already creates the run with GPS data
      // await _saveRunToHistory(summaryData);
      
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
        startTime: now.subtract(fallbackTime),
        endTime: now,
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
        startTime: DateTime.now().subtract(const Duration(minutes: 15)),
        endTime: DateTime.now(),
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
    if (run.totalDistance >= 5.0) achievements.add('5K Runner');
    if (run.totalDistance >= 10.0) achievements.add('10K Warrior');
    if (run.totalDistance >= 21.1) achievements.add('Half Marathon Hero');
    
    // Time achievements
    if (run.totalTime.inMinutes <= 20) achievements.add('Speed Demon');
    if (run.totalTime.inMinutes <= 30) achievements.add('Quick Runner');
    
    // Pace achievements
    if (run.averagePace <= 5.0) achievements.add('Elite Pace');
    if (run.averagePace <= 6.0) achievements.add('Fast Runner');
    
    // Episode completion
    if (episode != null) achievements.add('Episode Complete');
    
    // First run achievement
    achievements.add('First Run');
    
    // Personal best achievements (could be enhanced with user history)
    if (run.totalDistance >= 3.0) achievements.add('Distance Milestone');
    if (run.totalTime.inMinutes >= 15) achievements.add('Endurance Runner');
    
    return achievements;
  }
  
  /// Save run to user's history - NO LONGER NEEDED
  /// RunSessionManager now handles saving runs with GPS data
  Future<void> _saveRunToHistory(RunSummaryData summaryData) async {
    // This method is no longer used - RunSessionManager saves the run
    print('ℹ️ RunCompletionService: _saveRunToHistory called but no longer needed');
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
  final DateTime startTime;
  final DateTime endTime;
  
  RunSummaryData({
    required this.totalTime,
    required this.totalDistance,
    required this.averagePace,
    required this.caloriesBurned,
    this.episode,
    required this.achievements,
    required this.route,
    required this.startTime,
    required this.endTime,
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
