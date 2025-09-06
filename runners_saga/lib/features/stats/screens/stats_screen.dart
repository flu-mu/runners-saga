import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:runners_saga/core/constants/app_theme.dart';
import 'package:runners_saga/shared/widgets/navigation/bottom_navigation_widget.dart';
import 'package:runners_saga/shared/widgets/ui/seasonal_background.dart';
import 'package:runners_saga/core/themes/theme_factory.dart';
import 'package:runners_saga/shared/services/firebase/firestore_service.dart';
import 'package:runners_saga/shared/providers/run_providers.dart';
import 'package:runners_saga/features/stats/widgets/trends_section.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ThemeFactory.getCurrentTheme();
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Your Running Stats',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SeasonalBackground(
        showHeaderPattern: true,
        headerHeight: 120,
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // New dynamic trends section (charts + week/month selector)
              const StatsTrendsSection(),

              const SizedBox(height: 20),
              // Stats Summary Card
              _buildStatsSummaryCard(ref),
              
              const SizedBox(height: 20),
              
              // Recent Activity Card
              _buildRecentActivityCard(context),
              
              const SizedBox(height: 20),
              
              // Goals Card
              _buildGoalsCard(context),
            ],
          ),
        ),
        ),
      ),
      bottomNavigationBar: BottomNavigationWidget(
        currentIndex: BottomNavIndex.stats.value,
      ),
    );
  }

  Widget _buildStatsSummaryCard(WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(firestoreServiceProvider).getUserRunStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard(context);
        }
        
        if (snapshot.hasError) {
          return _buildErrorCard(context, snapshot.error.toString());
        }
        
        final stats = snapshot.data ?? {};
        return _buildStatsCard(context, stats);
      },
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(kElectricAqua),
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading stats',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, Map<String, dynamic> stats) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Running Stats',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: kElectricAqua,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          
          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Total Runs',
                  '${stats['totalRuns'] ?? 0}',
                  Icons.directions_run,
                  kEmberCoral,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Total Distance',
                  '${(stats['totalDistance'] ?? 0.0).toStringAsFixed(1)} km',
                  Icons.straighten,
                  kMeadowGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  context,
                  'Best Pace',
                  _formatPace(stats['bestPace']),
                  Icons.speed,
                  kDeepTeal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatItem(
                  context,
                  'Total Time',
                  _formatDuration(stats['totalTime']),
                  Icons.timer,
                  kElectricAqua,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onBackground,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your recent running activity will appear here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Complete more runs to see your activity history here.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onBackground,
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

  Widget _buildGoalsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goals & Achievements',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Track your progress towards running goals.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.flag,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Set your first running goal to get started!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onBackground,
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

  String _formatPace(dynamic pace) {
    if (pace == null) return '--:--';
    if (pace is double) {
      final minutes = pace.floor();
      final seconds = ((pace - minutes) * 60).round();
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '--:--';
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '0h 0m';
    if (duration is Duration) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}m';
    }
    return '0h 0m';
  }
}
