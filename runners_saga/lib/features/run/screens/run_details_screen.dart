import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runners_saga/shared/models/run_model.dart';
import 'package:runners_saga/shared/widgets/ui/seasonal_background.dart';
import 'package:runners_saga/core/themes/theme_factory.dart';
import 'package:runners_saga/shared/providers/run_providers.dart';
import 'package:runners_saga/shared/services/settings/settings_service.dart';

/// Run details screen following the Paul Revere design pattern
class RunDetailsScreen extends ConsumerWidget {
  final String runId;
  
  const RunDetailsScreen({
    super.key,
    required this.runId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ThemeFactory.getCurrentTheme();
    final firestore = ref.read(firestoreServiceProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: theme.colorScheme.onBackground,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Run Details',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onBackground,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Delete run',
            icon: Icon(
              Icons.delete_outline,
              color: theme.colorScheme.onBackground.withValues(alpha: 0.8),
            ),
            onPressed: () => _confirmAndDeleteRun(context, ref),
          ),
        ],
      ),
      body: FutureBuilder<RunModel?>(
        future: firestore.getRun(runId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(context, theme);
          }
          if (snapshot.hasError) {
            return _buildErrorState(context, theme, snapshot.error!);
          }
          final run = snapshot.data;
          if (run == null) {
            return _buildErrorState(context, theme, 'Run not found');
          }
          return _buildRunDetails(context, theme, run);
        },
      ),
    );
  }

  Future<void> _confirmAndDeleteRun(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Run?'),
        content: const Text('This will permanently delete this workout from your history and Firebase.'),
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
      await firestore.deleteRun(runId);

      // Refresh lists that depend on runs
      ref.refresh(userRunsProvider);
      ref.refresh(userCompletedRunsProvider);

      if (context.mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Run deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete run: $e')),
        );
      }
    }
  }

  Widget _buildRunDetails(BuildContext context, ThemeData theme, RunModel run) {
    return SeasonalBackground(
      showHeaderPattern: true,
      headerHeight: 120,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // Episode Title and Date
            _buildEpisodeHeader(context, theme, run),
            
            const SizedBox(height: 24),
            
            // Statistics Grid
            _buildStatisticsGrid(context, theme, run),
            
            const SizedBox(height: 24),
            
            // Story Collectibles
            _buildStoryCollectibles(context, theme, run),
            
            const SizedBox(height: 24),
            
            // Timeline
            _buildTimeline(context, theme, run),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeHeader(BuildContext context, ThemeData theme, RunModel run) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Episode Title
        Text(
          run.episodeId != null && run.episodeId!.isNotEmpty
              ? 'Episode ${run.episodeId}'
              : 'Untitled Episode',
          style: theme.textTheme.headlineLarge?.copyWith(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Date and Time
        Text(
          _formatRunDateTime(run),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onBackground.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsGrid(BuildContext context, ThemeData theme, RunModel run) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        FutureBuilder<String>(
          future: SettingsService().formatDistance(run.totalDistance ?? 0.0),
          builder: (context, snapshot) {
            return _buildStatCard(
              context,
              theme,
              'Distance',
              snapshot.data ?? '${(run.totalDistance ?? 0.0).toStringAsFixed(2)} km',
              theme.colorScheme.primary,
              Icons.straighten,
            );
          },
        ),
        _buildStatCard(
          context,
          theme,
          'Total Time',
          _formatDuration(run.totalTime ?? Duration.zero),
          theme.colorScheme.secondary,
          Icons.timer,
        ),
        _buildStatCard(
          context,
          theme,
          'Route Points',
          '${run.route?.length ?? 0}',
          theme.colorScheme.tertiary,
          Icons.map,
        ),
        FutureBuilder<String>(
          future: SettingsService().formatPace(_computeAvgPace(run)),
          builder: (context, snapshot) {
            return _buildStatCard(
              context,
              theme,
              'Pace',
              snapshot.data ?? _formatPace(run),
              theme.colorScheme.primary,
              Icons.speed,
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    ThemeData theme,
    String label,
    String value,
    Color valueColor,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCollectibles(BuildContext context, ThemeData theme, RunModel run) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACHIEVEMENTS',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Achievements list
        if (run.achievements?.isNotEmpty == true)
          ...run.achievements!.map((ach) => _buildCollectibleCard(
            context,
            theme,
            ach,
          ))
        else
          _buildEmptyCollectibles(context, theme),
      ],
    );
  }

  Widget _buildCollectibleCard(
    BuildContext context,
    ThemeData theme,
    String collectible,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.description,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collectible,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Collected during run',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCollectibles(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: Text(
          'No collectibles found for this run',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, ThemeData theme, RunModel run) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TIMELINE',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        
        const SizedBox(height: 12),
        
        _buildTimelineEvent(
          context,
          theme,
          'Started',
          run.episodeId != null && run.episodeId!.isNotEmpty
              ? 'Episode ${run.episodeId}'
              : 'Untitled Episode',
          Icons.play_arrow,
          theme.colorScheme.primary,
        ),
        
        if (run.achievements?.isNotEmpty == true)
          ...run.achievements!.map((event) => _buildTimelineEvent(
            context,
            theme,
            event,
            'Achievement',
            Icons.radio,
            theme.colorScheme.secondary,
          )),
        
        _buildTimelineEvent(
          context,
          theme,
          'Completed',
          'Run finished',
          Icons.check_circle,
          theme.colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildTimelineEvent(
    BuildContext context,
    ThemeData theme,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onBackground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onBackground.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading run details...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onBackground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ThemeData theme, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load run details',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onBackground.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  String _formatRunDateTime(RunModel run) {
    final startTime = run.startTime; // alias of createdAt (non-null)
    final endTime = run.endTime ?? startTime.add(run.totalTime ?? Duration.zero);
    
    final startFormatted = '${startTime.day}/${startTime.month}/${startTime.year} at ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final endFormatted = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    
    return '$startFormatted – $endFormatted';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _formatPace(RunModel run) {
    final distance = run.totalDistance ?? 0.0;
    final duration = run.totalTime ?? Duration.zero;
    if (distance <= 0 || duration.inSeconds <= 0) return '0:00/km';
    
    final paceInSeconds = duration.inSeconds / distance;
    final minutes = (paceInSeconds / 60).floor();
    final seconds = (paceInSeconds % 60).round();
    
    return '${minutes}:${seconds.toString().padLeft(2, '0')}/km';
  }

  // Compute average pace value in min/km from run data
  double _computeAvgPace(RunModel run) {
    final distance = run.totalDistance ?? 0.0;
    final duration = run.totalTime ?? Duration.zero;
    if (distance <= 0 || duration.inSeconds <= 0) return 0.0;
    return duration.inMinutes / distance;
  }
}
