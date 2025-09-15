import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../shared/providers/run_providers.dart';
import '../../../shared/models/run_model.dart';
import '../../../shared/services/settings/settings_service.dart';
import '../../../core/constants/app_theme.dart';
import '../../../shared/widgets/navigation/bottom_navigation_widget.dart';
import '../../../shared/widgets/ui/seasonal_background.dart';
import '../../../core/themes/theme_factory.dart';
import 'dart:math';

class RunHistoryScreen extends ConsumerStatefulWidget {
  const RunHistoryScreen({super.key});

  @override
  ConsumerState<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends ConsumerState<RunHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _splitMultiplier = 1; // 1 unit or 5 units per split

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Test indexes when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testIndexes(ref);
    });
    
    final runsAsync = ref.watch(userRunsProvider);
    final statsAsync = ref.watch(userRunStatsProvider);

    final theme = ThemeFactory.getCurrentTheme();
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Run History', style: TextStyle(color: Colors.white)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: () {
              // Test indexes manually
              _testIndexes(ref);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Testing indexes... Check console for results'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            tooltip: 'Test Indexes',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // Force refresh the runs data
              ref.refresh(userRunsProvider);
              ref.refresh(userCompletedRunsProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing run data...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Refresh runs',
          ),
        ],
      ),
      body: SeasonalBackground(
        showHeaderPattern: true,
        headerHeight: 120,
        child: runsAsync.when(
        data: (runs) => _buildRunHistory(context, ref, runs, statsAsync),
        loading: () => const Center(
          child: CircularProgressIndicator(color: kElectricAqua),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: kEmberCoral, size: 64),
              const SizedBox(height: 16),
              Text(
                'Failed to load runs',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'This is likely due to missing Firestore indexes.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Required Indexes:',
                      style: TextStyle(color: kElectricAqua, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Collection: runs\n• Fields: userId (Ascending), createdAt (Descending)',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Collection: runs\n• Fields: userId (Ascending), completedAt (Descending)',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(userRunsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kElectricAqua,
                  foregroundColor: kMidnightNavy,
                ),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  // Copy the Firebase Console URL to clipboard
                  // You can implement clipboard functionality here
                  print('Firebase Console URL: https://console.firebase.google.com/project/_/firestore/indexes');
                },
                child: Text(
                  'Open Firebase Console',
                  style: TextStyle(color: kElectricAqua),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
      bottomNavigationBar: BottomNavigationWidget(
        currentIndex: BottomNavIndex.workouts.value,
      ),
    );
  }

  /// Test all required indexes and show detailed error information
  void _testIndexes(WidgetRef ref) {
    try {
      print('🔍 RunHistoryScreen: Testing all required indexes...');
      
      // Get the firestore service
      final firestoreService = ref.read(firestoreServiceProvider);
      
      // Test the indexes asynchronously
      firestoreService.testIndexes().catchError((e) {
        print('❌ Error testing indexes: $e');
      });
      
      print('🔍 Index testing initiated. Check console for results.');
    } catch (e) {
      print('❌ Error initiating index test: $e');
    }
  }

  Widget _buildRunHistory(BuildContext context, WidgetRef ref, List<RunModel> runs, AsyncValue<Map<String, dynamic>> statsAsync) {
    if (runs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_run,
              size: 80,
              color: kTextMid.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No runs yet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first run to see it here!',
              style: TextStyle(color: kTextMid),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/run'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kElectricAqua,
                foregroundColor: kMidnightNavy,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Start Your First Run'),
            ),
          ],
        ),
      );
    }

    // Ensure consistent ordering: most recent first
    final sortedRuns = [...runs]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      children: [
        // Statistics summary
        if (statsAsync.hasValue) _buildStatsSummary(statsAsync.value!),
        
        // Runs list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedRuns.length,
            itemBuilder: (context, index) {
              final run = sortedRuns[index];
              return _buildRunCard(context, run);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSummary(Map<String, dynamic> stats) {
    // This card has been moved to the Stats page
    return const SizedBox.shrink();
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRunCard(BuildContext context, RunModel run) {
    // Derive metrics if missing (e.g., some runs lack persisted stats but have route)
    final route = run.route ?? const [];
    final derivedDistanceKm = (run.totalDistance == null || (run.totalDistance ?? 0) <= 0)
        ? _computeDistanceFromRoute(route)
        : (run.totalDistance ?? 0);
    final derivedDuration = (run.totalTime == null || (run.totalTime?.inSeconds ?? 0) <= 0)
        ? _computeDurationFromRun(run)
        : (run.totalTime ?? Duration.zero);
    final derivedAvgPace = (run.averagePace == null || (run.averagePace ?? 0) <= 0)
        ? _computeAveragePace(derivedDistanceKm, derivedDuration)
        : (run.averagePace ?? 0);
    // Derive a sensible status when field is missing in older documents
    final derivedStatus = run.status ??
        (run.completedAt != null
            ? RunStatus.completed
            : (run.totalTime != null && (run.totalTime!.inSeconds > 0)
                ? RunStatus.inProgress
                : RunStatus.notStarted));
    final statusColor = _getStatusColor(derivedStatus);
    final statusIcon = _getStatusIcon(derivedStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(statusIcon, color: statusColor, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${run.episodeId?.replaceAll('_', ' ').toUpperCase() ?? 'EPISODE'}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                derivedStatus.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                FutureBuilder<String>(
                  future: _formatDistanceAsync(derivedDistanceKm),
                  builder: (context, snapshot) {
                    return _buildRunStat('Distance', snapshot.data ?? _formatDistance(derivedDistanceKm));
                  },
                ),
                const SizedBox(width: 24),
                _buildRunStat('Time', _formatDuration(derivedDuration)),
                const SizedBox(width: 24),
                FutureBuilder<String>(
                  future: _formatPaceWithUnitsAsync(derivedAvgPace),
                  builder: (context, snapshot) {
                    return _buildRunStat('Pace', snapshot.data ?? _formatPaceWithUnits(derivedAvgPace));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Started: ${_formatDateTime(run.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            // Show completion time if available (completedAt maps to completedAt in Firestore)
            if (run.completedAt != null)
              Text(
                'Completed: ${_formatDateTime(run.completedAt!)}',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        onTap: () => _showRunDetails(context, run),
      ),
    );
  }

  Widget _buildRunStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  Color _getStatusColor(RunStatus status) {
    switch (status) {
      case RunStatus.completed:
        return Colors.green;
      case RunStatus.inProgress:
        return Colors.blue;
      case RunStatus.paused:
        return Colors.orange;
      case RunStatus.cancelled:
        return Colors.red;
      case RunStatus.notStarted:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(RunStatus status) {
    switch (status) {
      case RunStatus.completed:
        return Icons.check_circle;
      case RunStatus.inProgress:
        return Icons.play_circle;
      case RunStatus.paused:
        return Icons.pause_circle;
      case RunStatus.cancelled:
        return Icons.cancel;
      case RunStatus.notStarted:
        return Icons.schedule;
    }
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

  String _formatPace(double pace) {
    if (pace == 0) return '0:00';
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Format distance using settings service
  String _formatDistance(double distanceInKm) {
    // For synchronous display, we'll use a default conversion
    // The async version will be used for the main display
    return '${distanceInKm.toStringAsFixed(2)} km';
  }

  // Format distance asynchronously using settings service
  Future<String> _formatDistanceAsync(double distanceInKm) async {
    final settingsService = SettingsService();
    return await settingsService.formatDistance(distanceInKm);
  }

  // Format pace using settings service
  Future<String> _formatPaceAsync(double paceInMinPerKm) async {
    final settingsService = SettingsService();
    return await settingsService.formatPace(paceInMinPerKm);
  }

  // Format energy using settings service
  Future<String> _formatEnergyAsync(double energyInKcal) async {
    final settingsService = SettingsService();
    return await settingsService.formatEnergy(energyInKcal);
  }

  // Format pace with units (synchronous fallback) with slow cap
  String _formatPaceWithUnits(double paceInMinPerKm) {
    const double capPaceMinPerKm = 20.0; // display cap for anomalously slow pace
    if (paceInMinPerKm > 0 && paceInMinPerKm >= capPaceMinPerKm) {
      return '+20:00 min/km';
    }
    return '${_formatPace(paceInMinPerKm)}/km';
  }

  // Format pace with units using settings service + slow cap
  Future<String> _formatPaceWithUnitsAsync(double paceInMinPerKm) async {
    const double capPaceMinPerKm = 20.0;
    if (paceInMinPerKm > 0 && paceInMinPerKm >= capPaceMinPerKm) {
      return '+20:00 min/km';
    }
    final settingsService = SettingsService();
    return await settingsService.formatPace(paceInMinPerKm);
  }

  // Format pace for splits with slow cap (no units)
  String _formatPaceCapped(double paceInMinPerKm) {
    const double capPaceMinPerKm = 20.0;
    if (paceInMinPerKm > 0 && paceInMinPerKm >= capPaceMinPerKm) {
      return '+20:00';
    }
    return _formatPace(paceInMinPerKm);
  }

  // Format speed using settings service
  Future<String> _formatSpeedAsync(double speedInKmh) async {
    final settingsService = SettingsService();
    return await settingsService.formatSpeed(speedInKmh);
  }

  // Get distance unit text (km or mi)
  Future<String> _getDistanceUnitText() async {
    final settingsService = SettingsService();
    final distanceUnit = await settingsService.getDistanceUnit();
    return distanceUnit == DistanceUnit.miles ? 'mi' : 'km';
  }

  void _showRunDetails(BuildContext context, RunModel run) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          // Map as background (full screen)
          Positioned.fill(
            child: _buildMapTab(run),
          ),
          
          // Draggable workout details card (slides over the map)
          DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.25,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: kMidnightNavy,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title and workout summary
                          _buildWorkoutSummary(run),
                          
                          const SizedBox(height: 20),
                          
                          // Tab bar for switching between pace details and other stats
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                color: kElectricAqua,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              labelColor: Colors.black,
                              unselectedLabelColor: Colors.white70,
                              tabs: const [
                                Tab(text: 'Pace Details'),
                                Tab(text: 'More Stats'),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Tab content
                          SizedBox(
                            height: 400,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildPaceDetailsTab(run),
                                _buildMoreStatsTab(run),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailCard(String label, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build workout summary section
  Widget _buildWorkoutSummary(RunModel run) {
    final route = run.route ?? const [];
    final totalDistance = (run.totalDistance == null || (run.totalDistance ?? 0) <= 0)
        ? _computeDistanceFromRoute(route)
        : (run.totalDistance ?? 0.0);
    final totalTime = (run.totalTime == null || (run.totalTime?.inSeconds ?? 0) <= 0)
        ? _computeDurationFromRun(run)
        : (run.totalTime ?? Duration.zero);
    final averagePace = (run.averagePace == null || (run.averagePace ?? 0) <= 0)
        ? _computeAveragePace(totalDistance, totalTime)
        : (run.averagePace ?? 0.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title + Delete action
        Row(
          children: [
            Expanded(
              child: Text(
                'Outdoor Run',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Delete run',
              icon: const Icon(Icons.delete_outline, color: Colors.white70),
              onPressed: () => _confirmAndDeleteRun(context, run),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // User info and workout summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              // User info row
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: kElectricAqua.withValues(alpha: 0.2),
                    child: Icon(Icons.person, color: kElectricAqua, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Run',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatDateTime(run.createdAt),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FutureBuilder<String>(
                    future: _formatDistanceAsync(totalDistance),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? '${totalDistance.toStringAsFixed(2)} km',
                        style: TextStyle(
                          color: kElectricAqua,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Stats grid
              Row(
                children: [
                  Expanded(child: _buildSummaryStat('Workout Time', _formatDuration(totalTime), Icons.timer)),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _formatEnergyAsync(_calculateCalories(totalDistance, totalTime).toDouble()),
                      builder: (context, snapshot) {
                        return _buildSummaryStat('Calories', snapshot.data ?? '${_calculateCalories(totalDistance, totalTime)} kcal', Icons.local_fire_department);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _formatPaceWithUnitsAsync(averagePace),
                      builder: (context, snapshot) {
                        return _buildSummaryStat('Avg Pace', snapshot.data ?? _formatPace(averagePace), Icons.speed);
                      },
                    ),
                  ),
                  Expanded(child: _buildSummaryStat('Route Points', '${run.route?.length ?? 0}', Icons.map)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build summary stat item
  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: kElectricAqua, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndDeleteRun(BuildContext context, RunModel run) async {
    // Ensure we have a valid ID
    if (run.id == null || run.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: invalid run ID')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Run?'),
        content: const Text(
          'This will permanently delete this workout from your history and Firebase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final firestore = ref.read(firestoreServiceProvider);
      await firestore.deleteRun(run.id!);

      // Refresh lists
      ref.refresh(userRunsProvider);
      ref.refresh(userCompletedRunsProvider);

      // Close the bottom sheet
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Notify user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Run deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete run: $e')),
      );
    }
  }

  /// Build map tab
  Widget _buildMapTab(RunModel run) {
    if (run.route == null || run.route!.isEmpty) {
      return _buildNoRoutePlaceholder();
    }
    
    final route = run.route!;
    final polylinePoints = route.map((p) => LatLng(p.latitude, p.longitude)).toList();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: polylinePoints.isNotEmpty ? polylinePoints.first : const LatLng(0, 0),
            initialZoom: 15,
            maxZoom: 18,
            minZoom: 10,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'runners_saga',
            ),
            // Route polyline
            if (polylinePoints.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints,
                    color: kElectricAqua,
                    strokeWidth: 4,
                  ),
                ],
              ),
            // Start and end markers
            if (polylinePoints.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: polylinePoints.first,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: kMeadowGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                    ),
                  ),
                  if (polylinePoints.length > 1)
                    Marker(
                      point: polylinePoints.last,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: kEmberCoral,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flag, color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Build more stats tab
  Widget _buildMoreStatsTab(RunModel run) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Statistics',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          
          // Additional stats cards
          _buildDetailCard('Total Elevation', '${run.elevationGain?.toStringAsFixed(0) ?? '0'} m', Icons.terrain),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: _formatSpeedAsync(run.maxSpeed ?? 0.0),
            builder: (context, snapshot) {
              return _buildDetailCard('Max Speed', snapshot.data ?? '${run.maxSpeed?.toStringAsFixed(1) ?? '0.0'} km/h', Icons.speed);
            },
          ),
          const SizedBox(height: 12),
          _buildDetailCard('Avg Heart Rate', '${run.avgHeartRate?.toStringAsFixed(0) ?? '--'} bpm', Icons.favorite),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: _formatEnergyAsync(run.caloriesBurned ?? 0.0),
            builder: (context, snapshot) {
              return _buildDetailCard('Calories Burned', snapshot.data ?? '${run.caloriesBurned?.toStringAsFixed(0) ?? '0'} kcal', Icons.local_fire_department);
            },
          ),
        ],
      ),
    );
  }

  /// Build pace details tab
  Widget _buildPaceDetailsTab(RunModel run) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FutureBuilder<String>(
                future: _getDistanceUnitText(),
                builder: (context, snapshot) {
                  return Text(
                    'Details per ${snapshot.data ?? 'km'}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  );
                },
              ),
              IconButton(
                onPressed: () {
                  // TODO: Show options for customizing details
                },
                icon: Icon(Icons.add_circle_outline, color: kElectricAqua),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Distance filter buttons (labels reflect unit)
          FutureBuilder<String>(
            future: _getDistanceUnitText(),
            builder: (context, snapshot) {
              final unit = snapshot.data ?? 'km';
              return Row(
                children: [
                  _buildFilterButton('1 $unit', _splitMultiplier == 1, () {
                    setState(() => _splitMultiplier = 1);
                  }),
                  const SizedBox(width: 12),
                  _buildFilterButton('5 $unit', _splitMultiplier == 5, () {
                    setState(() => _splitMultiplier = 5);
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Build segments and table based on current distance unit
          FutureBuilder<DistanceUnit>(
            future: SettingsService().getDistanceUnit(),
            builder: (context, snapshot) {
              final unit = snapshot.data ?? DistanceUnit.kilometers;
              final unitSymbol = unit == DistanceUnit.miles ? 'mi' : 'km';
              final baseKm = unit == DistanceUnit.miles ? 1.60934 : 1.0;
              final segments = _calculateSplitSegments(run, baseKm * _splitMultiplier);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${segments.length} records',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (segments.isNotEmpty) ...[
                    _buildPaceTableHeader(unitSymbol),
                    ...segments.map((segment) => _buildPaceTableRow(segment)),
                  ] else ...[
                    _buildNoDataPlaceholder(),
                  ],
                ],
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Feedback section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white70.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  'Any problem with the data?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    // TODO: Show feedback form
                  },
                  child: Text(
                    'Tap to send feedback',
                    style: TextStyle(
                      color: kElectricAqua,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate kilometer segments from GPS route (uses derived metrics when needed)
  List<KilometerSegment> _calculateKilometerSegments(RunModel run) {
    if (run.route == null || run.route!.isEmpty) return [];
    final route = run.route!;
    // Use derived fallbacks so splits appear when stored metrics are missing
    final totalDistance = (run.totalDistance == null || (run.totalDistance ?? 0) <= 0)
        ? _computeDistanceFromRoute(route)
        : (run.totalDistance ?? 0.0);
    final totalTime = (run.totalTime == null || (run.totalTime?.inSeconds ?? 0) <= 0)
        ? _computeDurationFromRun(run)
        : (run.totalTime ?? Duration.zero);
    if (totalDistance <= 0 || totalTime.inSeconds <= 0) return [];
    
    final segments = <KilometerSegment>[];
    double accumulatedDistance = 0.0;
    int startIndex = 0;
    int allocatedTimeSec = 0; // For fallback timing distribution
    
    for (int i = 1; i < route.length; i++) {
      final prev = route[i - 1];
      final curr = route[i];
      
      // Calculate distance between consecutive points
      final segmentDistance = _calculateDistance(
        prev.latitude, prev.longitude,
        curr.latitude, curr.longitude,
      );
      
      accumulatedDistance += segmentDistance;
      
      // Check if we've reached a kilometer boundary
      if (accumulatedDistance >= 1.0 || i == route.length - 1) {
        // Calculate time for this kilometer
        final startTime = route[startIndex].elapsedSeconds;
        final endTime = curr.elapsedSeconds;
        final segmentTime = endTime - startTime;
        
        // Calculate pace for this kilometer (minutes per km)
        final pace = segmentTime > 0 ? (segmentTime / 60.0) : 0.0;
        
        // Simulate heart rate based on pace
        final simulatedHeartRate = 120 + (pace * 10).round();
        
        segments.add(KilometerSegment(
          kilometer: segments.length + 1,
          pace: pace,
          heartRate: simulatedHeartRate,
          cumulativeTime: Duration(seconds: endTime),
          distance: accumulatedDistance,
        ));
        
        // Reset for next kilometer
        accumulatedDistance = 0.0;
        startIndex = i;
      }
    }
    
    return segments;
  }

  /// Calculate distance between two points in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Compute distance (km) from route when not persisted
  double _computeDistanceFromRoute(List<LocationPoint> route) {
    if (route.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 1; i < route.length; i++) {
      final a = route[i - 1];
      final b = route[i];
      total += _calculateDistance(a.latitude, a.longitude, b.latitude, b.longitude);
    }
    return total;
  }

  // Compute duration from route elapsedSeconds or from createdAt/completedAt
  Duration _computeDurationFromRun(RunModel run) {
    final route = run.route ?? const [];
    if (route.length >= 2) {
      final start = route.first.elapsedSeconds;
      final end = route.last.elapsedSeconds;
      if (end > start) {
        return Duration(seconds: end - start);
      }
    }
    if (run.completedAt != null) {
      return run.completedAt!.difference(run.createdAt);
    }
    return Duration.zero;
  }

  // Compute average pace (min/km)
  double _computeAveragePace(double distanceKm, Duration duration) {
    if (distanceKm > 0 && duration.inSeconds > 0) {
      return (duration.inSeconds / 60.0) / distanceKm;
    }
    return 0.0;
  }

  /// Calculate generic split segments by unit length (in km)
  List<KilometerSegment> _calculateSplitSegments(RunModel run, double splitLengthKm) {
    if (run.route == null || run.route!.isEmpty) return [];
    final route = run.route!;
    // Use derived fallbacks for robustness
    final totalDistance = (run.totalDistance == null || (run.totalDistance ?? 0) <= 0)
        ? _computeDistanceFromRoute(route)
        : (run.totalDistance ?? 0.0);
    final totalTime = (run.totalTime == null || (run.totalTime?.inSeconds ?? 0) <= 0)
        ? _computeDurationFromRun(run)
        : (run.totalTime ?? Duration.zero);
    if (totalDistance <= 0 || totalTime.inSeconds <= 0) return [];

    final segments = <KilometerSegment>[];
    int allocatedTimeSec = 0; // running total to ensure cumulative time continuity
    double accumulatedDistance = 0.0;
    int startIndex = 0;

    for (int i = 1; i < route.length; i++) {
      final prev = route[i - 1];
      final curr = route[i];
      final segmentDistance = _calculateDistance(
        prev.latitude, prev.longitude,
        curr.latitude, curr.longitude,
      );
      accumulatedDistance += segmentDistance;

      if (accumulatedDistance >= splitLengthKm || i == route.length - 1) {
        final startTime = route[startIndex].elapsedSeconds;
        final endTime = curr.elapsedSeconds;
        int segmentTimeSec = endTime - startTime; // seconds

        // Distance covered in this segment (km)
        final segmentDistanceKm = accumulatedDistance;

        // Fallback if elapsedSeconds are missing/non-increasing: distribute by distance share
        if (segmentTimeSec <= 0) {
          if (i == route.length - 1) {
            // Last segment gets remaining time
            segmentTimeSec = (totalTime.inSeconds - allocatedTimeSec)
                .clamp(0, totalTime.inSeconds)
                .toInt();
          } else {
            segmentTimeSec = ((totalTime.inSeconds * (segmentDistanceKm / totalDistance))).round();
          }
        }

        // Pace in min per split unit length
        final pace = segmentDistanceKm > 0 ? (segmentTimeSec / 60.0) / segmentDistanceKm : 0.0;
        final simulatedHeartRate = 120 + (pace * 10).round();

        // Determine cumulative time consistently
        allocatedTimeSec += segmentTimeSec;
        final cumulativeSec = (endTime > 0 && startTime >= 0 && (endTime - startTime) > 0)
            ? endTime
            : allocatedTimeSec;

        segments.add(KilometerSegment(
          kilometer: segments.length + 1,
          pace: pace,
          heartRate: simulatedHeartRate,
          cumulativeTime: Duration(seconds: cumulativeSec),
          distance: segmentDistanceKm,
        ));

        accumulatedDistance = 0.0;
        startIndex = i;
      }
    }
    return segments;
  }

  /// Build filter button
  Widget _buildFilterButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kElectricAqua : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kElectricAqua : Colors.white70.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Build pace table header
  Widget _buildPaceTableHeader(String unitSymbol) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerTheme.color ?? theme.colorScheme.onBackground.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              unitSymbol,
              style: TextStyle(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Pace ($unitSymbol)',
              style: TextStyle(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              'Heart Rate',
              style: TextStyle(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              'Time',
              style: TextStyle(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build pace table row
  Widget _buildPaceTableRow(KilometerSegment segment) {
    final paceZone = _getPaceZone(segment.pace);
    final zoneColor = _getPaceZoneColor(context, paceZone);
    
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerTheme.color ?? theme.colorScheme.onBackground.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Kilometer number
          SizedBox(
            width: 40,
            child: Text(
              '${segment.kilometer}',
              style: TextStyle(
                color: theme.colorScheme.onBackground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Pace with visual indicator
          Expanded(
            child: Row(
              children: [
                Text(
                  _formatPaceCapped(segment.pace),
                  style: TextStyle(
                    color: theme.colorScheme.onBackground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    color: zoneColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
          
          // Heart rate
          SizedBox(
            width: 80,
            child: Text(
              '${segment.heartRate}',
              style: TextStyle(
                color: theme.colorScheme.onBackground,
              ),
            ),
          ),
          
          // Cumulative time
          SizedBox(
            width: 80,
            child: Text(
              _formatDuration(segment.cumulativeTime),
              style: TextStyle(
                color: theme.colorScheme.onBackground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build no route placeholder
  Widget _buildNoRoutePlaceholder() {
    final theme = Theme.of(context);
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerTheme.color ?? theme.colorScheme.onBackground.withOpacity(0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map,
              size: 48,
              color: theme.colorScheme.onBackground.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Route Data',
              style: TextStyle(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            Text(
              'GPS route data not available for this run',
              style: TextStyle(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build no data placeholder
  Widget _buildNoDataPlaceholder() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerTheme.color ?? theme.colorScheme.onBackground.withOpacity(0.3)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.analytics,
              size: 48,
              color: theme.colorScheme.onBackground.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No Pace Data',
              style: TextStyle(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            Text(
              'Pace data not available for this run',
              style: TextStyle(
                color: theme.colorScheme.onBackground.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get pace zone for color coding
  String _getPaceZone(double pace) {
    if (pace <= 5.0) return 'fast';
    if (pace <= 6.5) return 'good';
    if (pace <= 8.0) return 'moderate';
    return 'slow';
  }

  /// Get color for pace zone
  Color _getPaceZoneColor(BuildContext context, String zone) {
    final theme = Theme.of(context);
    switch (zone) {
      case 'fast':
        return theme.colorScheme.error;
      case 'good':
        return theme.colorScheme.tertiary;
      case 'moderate':
        return theme.colorScheme.primary;
      case 'slow':
      default:
        return theme.colorScheme.onBackground.withOpacity(0.6);
    }
  }

  /// Calculate calories burned
  int _calculateCalories(double distance, Duration time) {
    final minutes = time.inSeconds / 60.0;
    if (minutes <= 0) return 0;
    
    // Assume average person burns ~100 calories per km
    final baseCalories = distance * 100;
    
    // Adjust based on pace (faster pace = more calories)
    final pace = distance > 0 ? minutes / distance : 0.0;
    final paceMultiplier = pace < 5.0 ? 1.3 : pace < 7.0 ? 1.1 : 1.0;
    
    return (baseCalories * paceMultiplier).round();
  }

}

/// Data class for kilometer segments
class KilometerSegment {
  final int kilometer;
  final double pace; // minutes per kilometer
  final int heartRate;
  final Duration cumulativeTime;
  final double distance;
  
  const KilometerSegment({
    required this.kilometer,
    required this.pace,
    required this.heartRate,
    required this.cumulativeTime,
    required this.distance,
  });
}
