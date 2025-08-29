import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/run_providers.dart';
import '../../../shared/models/run_model.dart';
import '../../../core/constants/app_theme.dart';

class RunHistoryScreen extends ConsumerWidget {
  const RunHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(userRunsProvider);
    final statsAsync = ref.watch(userRunStatsProvider);

    return Scaffold(
      backgroundColor: kMidnightNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Run History', style: TextStyle(color: Colors.white)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
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
      body: runsAsync.when(
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
                error.toString(),
                style: TextStyle(color: kEmberCoral),
                textAlign: TextAlign.center,
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
            ],
          ),
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
        currentIndex: 1, // Set to Workouts since this is the run history screen
        onTap: (index) {
          if (index == 0) {
            context.go('/home');
          } else if (index == 2) {
            context.go('/settings');
          }
        },
      ),
    );
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
    final sortedRuns = [...runs]..sort((a, b) => b.startTime.compareTo(a.startTime));

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
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Running Stats',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Runs',
                  '${stats['totalRuns']}',
                  Icons.directions_run,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total Distance',
                  '${stats['totalDistance'].toStringAsFixed(1)} km',
                  Icons.straighten,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Best Pace',
                  _formatPace(stats['bestPace']),
                  Icons.speed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Time',
                  _formatDuration(stats['totalTime']),
                  Icons.timer,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Avg Pace',
                  _formatPace(stats['averagePace']),
                  Icons.trending_up,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Route Points',
                  '${stats['totalPoints']}',
                  Icons.map,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    final statusColor = _getStatusColor(run.status);
    final statusIcon = _getStatusIcon(run.status);

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
                '${run.seasonId.replaceAll('_', ' ').toUpperCase()} - ${run.missionId.replaceAll('_', ' ').toUpperCase()}',
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
                run.status.name.toUpperCase(),
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
                _buildRunStat('Distance', '${(run.totalDistance ?? 0.0).toStringAsFixed(2)} km'),
                const SizedBox(width: 24),
                                  _buildRunStat('Time', _formatDuration(run.totalTime ?? Duration.zero)),
                const SizedBox(width: 24),
                                  _buildRunStat('Pace', _formatPace(run.averagePace ?? 0.0)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Started: ${_formatDateTime(run.startTime)}',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            if (run.endTime != null)
              Text(
                'Ended: ${_formatDateTime(run.endTime!)}',
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

  void _showRunDetails(BuildContext context, RunModel run) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Title
              Text(
                'Run Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              
              // Run information
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailCard(
                        'Mission',
                        '${run.seasonId.replaceAll('_', ' ').toUpperCase()} - ${run.missionId.replaceAll('_', ' ').toUpperCase()}',
                        Icons.flag,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailCard(
                        'Distance',
                        '${(run.totalDistance ?? 0.0).toStringAsFixed(2)} km',
                        Icons.straighten,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailCard(
                        'Duration',
                        _formatDuration(run.totalTime ?? Duration.zero),
                        Icons.timer,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailCard(
                        'Average Pace',
                        _formatPace(run.averagePace ?? 0.0),
                        Icons.speed,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailCard(
                        'Route Points',
                        '${run.route?.length ?? 0}',
                        Icons.map,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailCard(
                        'Started',
                        _formatDateTime(run.startTime),
                        Icons.play_arrow,
                      ),
                      if (run.endTime != null) ...[
                        const SizedBox(height: 8),
                        _buildDetailCard(
                          'Ended',
                          _formatDateTime(run.endTime!),
                          Icons.stop,
                        ),
                      ],
                      const SizedBox(height: 16),
                      
                      // Route visualization placeholder
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map,
                                size: 48,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Route Map',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${run.route?.length ?? 0} GPS points recorded',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
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
        ),
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
}
