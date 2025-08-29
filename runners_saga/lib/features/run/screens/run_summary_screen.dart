import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_theme.dart';
import '../../../shared/models/episode_model.dart';
import '../../../shared/providers/run_providers.dart';
import '../../../shared/providers/run_session_providers.dart';
import '../../../shared/providers/run_completion_providers.dart';
import '../../../shared/services/run/run_completion_service.dart';
import '../../../shared/providers/settings_providers.dart';

class RunSummaryScreen extends ConsumerStatefulWidget {
  final String? episodeId;
  
  const RunSummaryScreen({super.key, this.episodeId});

  @override
  ConsumerState<RunSummaryScreen> createState() => _RunSummaryScreenState();
}

class _RunSummaryScreenState extends ConsumerState<RunSummaryScreen> {
  late EpisodeModel? _episode;
  late Duration _totalTime;
  late double _totalDistance;
  late double _averagePace;
  late int _caloriesBurned;
  late List<String> _achievements;

  @override
  void initState() {
    super.initState();
    _loadRunData();
  }

  void _loadRunData() {
    print('📊 RunSummaryScreen: Loading run data...');
    
    // Try to get data from completion service first
    final summaryData = ref.read(currentRunSummaryProvider);
    
    if (summaryData != null) {
      print('✅ RunSummaryScreen: Using completion service data');
      // Use completion service data
      _totalTime = summaryData.totalTime;
      _totalDistance = summaryData.totalDistance;
      _averagePace = summaryData.averagePace;
      _caloriesBurned = summaryData.caloriesBurned;
      _episode = summaryData.episode;
      _achievements = summaryData.achievements;
    } else {
      print('⚠️ RunSummaryScreen: No completion data, using fallback sources');
      // Prefer live stats if available
      final liveStats = ref.read(currentRunStatsProvider);
      final run = ref.read(currentRunProvider);
      final episode = ref.read(currentRunEpisodeProvider);
      
      if (liveStats != null && (liveStats.elapsedTime > Duration.zero || liveStats.distance > 0)) {
        print('📊 RunSummaryScreen: Using live stats');
        _totalTime = liveStats.elapsedTime;
        _totalDistance = liveStats.distance;
        _averagePace = (liveStats.averagePace > 0)
            ? liveStats.averagePace
            : (_totalDistance > 0 ? _totalTime.inMinutes / _totalDistance : 0);
        _caloriesBurned = _calculateCalories(_totalDistance, _totalTime);
      } else if (run != null) {
        print('📊 RunSummaryScreen: Using current run data');
        _totalTime = run.totalTime ?? Duration.zero;
        _totalDistance = run.totalDistance ?? 0.0;
        _averagePace = run.averagePace ?? 0.0;
        _caloriesBurned = _calculateCalories(_totalDistance, _totalTime);
      } else {
        print('📊 RunSummaryScreen: Using default fallback data');
        // Fallback data if run is not available
        _totalTime = const Duration(minutes: 15);
        _totalDistance = 2.5;
        _averagePace = 6.0;
        _caloriesBurned = _calculateCalories(_totalDistance, _totalTime);
      }
      
      _episode = episode;
      _achievements = _generateAchievements();
    }
    
    print('📊 RunSummaryScreen: Data loaded - Time: ${_totalTime.inMinutes}m, Distance: ${_totalDistance}km, Achievements: ${_achievements.length}');
  }

  int _calculateCalories(double distance, Duration time) {
    // Use the same MET-based approach as run screen; weight from settings provider
    final minutes = time.inSeconds / 60.0;
    if (minutes <= 0) return 0;
    final weightKg = ref.read(userWeightKgProvider);
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

  List<String> _generateAchievements() {
    final achievements = <String>[];
    
    // Distance achievements
    if (_totalDistance >= 5.0) achievements.add('5K Runner');
    if (_totalDistance >= 10.0) achievements.add('10K Warrior');
    if (_totalDistance >= 21.1) achievements.add('Half Marathon Hero');
    
    // Time achievements
    if (_totalTime.inMinutes <= 20) achievements.add('Speed Demon');
    if (_totalTime.inMinutes <= 30) achievements.add('Quick Runner');
    
    // Pace achievements
    if (_averagePace <= 5.0) achievements.add('Elite Pace');
    if (_averagePace <= 6.0) achievements.add('Fast Runner');
    
    // Episode completion
    if (_episode != null) achievements.add('Episode Complete');
    
    // First run achievement
    achievements.add('First Run');
    
    return achievements;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMidnightNavy,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Run Statistics Card
                    _buildStatsCard(),
                    const SizedBox(height: 20),
                    
                    // Episode Summary Card
                    if (_episode != null) ...[
                      _buildEpisodeCard(),
                      const SizedBox(height: 20),
                    ],
                    
                    // Achievements Card
                    _buildAchievementsCard(),
                    const SizedBox(height: 20),
                    
                    // Action Buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: kSurfaceBase,
        selectedItemColor: kElectricAqua,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Workouts'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: 1, // Set to Workouts since this is a run summary
        onTap: (index) {
          if (index == 0) {
            context.go('/home');
          } else if (index == 1) {
            context.go('/run/history');
          } else if (index == 2) {
            context.go('/settings');
          }
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kElectricAqua.withValues(alpha: 0.2), kDeepTeal.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/home'),
                icon: Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
              Expanded(
                child: Text(
                  'Run Complete!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48), // Balance the back button
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Great job on your run!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: kTextMid,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Run Statistics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: kElectricAqua,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Stats Grid
          Row(
            children: [
              Expanded(child: _buildStatItem('Time', _formatDuration(_totalTime), Icons.timer, kEmberCoral)),
              Expanded(child: _buildStatItem('Distance', '${_totalDistance.toStringAsFixed(1)} km', Icons.flag, kMeadowGreen)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatItem('Pace', '${_averagePace.toStringAsFixed(1)} min/km', Icons.speed, kDeepTeal)),
              Expanded(child: _buildStatItem('Calories', '$_caloriesBurned', Icons.local_fire_department, kElectricAqua)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: kTextMid,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kRoyalPlum.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle, color: kRoyalPlum, size: 24),
              const SizedBox(width: 12),
              Text(
                'Episode Complete',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: kRoyalPlum,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _episode!.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _episode!.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: kTextMid,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kMeadowGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kMeadowGreen.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: kMeadowGreen, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Objective Complete',
                  style: TextStyle(
                    color: kMeadowGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kEmberCoral.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: kEmberCoral, size: 24),
              const SizedBox(width: 12),
              Text(
                'Achievements Unlocked',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: kEmberCoral,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _achievements.map((achievement) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kEmberCoral.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kEmberCoral.withValues(alpha: 0.5)),
              ),
              child: Text(
                achievement,
                style: TextStyle(
                  color: kEmberCoral,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // Action buttons removed - user should use bottom menu navigation
  Widget _buildActionButtons() {
    return const SizedBox.shrink(); // No buttons, just bottom menu
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // _saveRun method removed - run is already saved when Finish Run is clicked
}
