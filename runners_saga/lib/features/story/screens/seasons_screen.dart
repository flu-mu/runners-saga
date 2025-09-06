import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runners_saga/core/constants/app_theme.dart';
import 'package:runners_saga/shared/widgets/ui/seasonal_background.dart';
import 'package:runners_saga/core/themes/theme_factory.dart';
import 'package:runners_saga/shared/models/episode_model.dart';
import 'package:runners_saga/shared/models/season_model.dart';
import 'package:runners_saga/shared/providers/story_providers.dart';

class SeasonsScreen extends ConsumerStatefulWidget {
  const SeasonsScreen({super.key});

  @override
  ConsumerState<SeasonsScreen> createState() => _SeasonsScreenState();
}

class _SeasonsScreenState extends ConsumerState<SeasonsScreen> {
  int _selectedSeasonIndex = 0;

  @override
  Widget build(BuildContext context) {
    final seasonsAsync = ref.watch(seasonsProvider);
    final episodesAsync = ref.watch(episodesBySeasonProvider(_selectedSeasonIndex + 1));
    
    // Debug logging
    print('🎬 SeasonsScreen: Building with season index: $_selectedSeasonIndex');
    print('🎬 SeasonsScreen: Seasons provider state: ${seasonsAsync.toString()}');
    print('🎬 SeasonsScreen: Episodes provider state: ${episodesAsync.toString()}');

    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SeasonalBackground(
        showHeaderPattern: true,
        headerHeight: 120,
        child: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onBackground,
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Abel Township Saga',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onBackground,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),

            // Season tabs
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: seasonsAsync.when(
                data: (seasons) => ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: seasons.length,
                  itemBuilder: (context, index) {
                    final season = seasons[index];
                    final isSelected = index == _selectedSeasonIndex;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSeasonIndex = index;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onBackground.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Season ${season.order}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onBackground,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Error loading seasons')),
              ),
            ),

            const SizedBox(height: 24),

            // Episodes list
            Expanded(
              child: episodesAsync.when(
                data: (episodes) => episodes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 64,
                              color: theme.colorScheme.onBackground.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No episodes available yet',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onBackground.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Complete previous episodes to unlock more content',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onBackground.withOpacity(0.7),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: episodes.length,
                        itemBuilder: (context, index) {
                          final episode = episodes[index];
                          return _buildEpisodeCard(context, episode, index + 1);
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Error loading episodes')),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildEpisodeCard(BuildContext context, EpisodeModel episode, int episodeNumber) {
    final isUnlocked = episode.status == 'unlocked' || episode.status == 'completed';
    final isCompleted = episode.status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked 
              ? (isCompleted ? Theme.of(context).colorScheme.tertiary.withOpacity(0.5) : Theme.of(context).colorScheme.primary.withOpacity(0.3))
              : Theme.of(context).colorScheme.onBackground.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUnlocked ? () {
            context.push('/episode/${episode.id}');
          } : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Episode thumbnail
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isUnlocked ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onBackground.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // Episode number badge
                      Positioned(
                        top: 8,
                        left: 8,
                          child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isCompleted 
                                ? Theme.of(context).colorScheme.tertiary 
                                : (isUnlocked ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onBackground.withOpacity(0.6)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '$episodeNumber',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Episode icon
                      Center(
                        child: Icon(
                          isUnlocked ? Icons.play_arrow : Icons.lock,
                          size: 32,
                          color: isUnlocked ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Episode details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isUnlocked ? Theme.of(context).colorScheme.onBackground : Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        episode.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onBackground.withOpacity(isUnlocked ? 0.7 : 0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.tertiary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.tertiary.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Completed',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.tertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else if (isUnlocked)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Available',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'Locked',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ],
                ),
              ),

                // Arrow indicator
                if (isUnlocked)
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
