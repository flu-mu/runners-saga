# Episode Progression System

## Overview

The Episode Progression System is a simple and effective lookup table that manages episode unlocking and progression in The Runner's Saga. It ensures users can only access episodes after listening to/completing the required previous episodes, maintaining story continuity.

**Important**: This system is completely separate from user running statistics (distance, time, pace, etc.). User stats are tracked independently and do not influence episode progression - they serve different purposes in the app.

## Key Features

### 1. Prerequisite-Based Unlocking
- Episodes are unlocked only after completing required previous episodes
- Prevents users from skipping ahead in the story
- Maintains narrative continuity and game balance

### 2. Episode Completion-Based Progression
- Episodes are unlocked only after listening to/completing required previous episodes
- No distance, level, or other gameplay requirements
- Simple and straightforward progression based on story consumption
- **Note**: User running stats are tracked separately and do not affect episode unlocking

### 3. Smart Episode Recommendations
- Automatically suggests the next best episode to play
- Considers user progress across all seasons
- Prioritizes incomplete seasons with highest progress

## Data Structure

### EpisodeProgression
```dart
class EpisodeProgression {
  final String episodeId;           // Unique episode identifier
  final List<String> prerequisites; // Required completed episodes
  final List<String> nextEpisodes;  // Episodes unlocked after this one
  final Map<String, dynamic> unlockRequirements; // Additional requirements
}
```

### EpisodeStatus
```dart
class EpisodeStatus {
  final String episodeId;
  final bool isCompleted;    // User has finished this episode
  final bool canUnlock;      // User meets requirements to unlock
  final bool isLocked;       // User cannot access this episode yet
  final int order;           // Episode sequence number
}
```

## Current Progression Table

### Season 1
- **S01E01**: First episode (no prerequisites)
- **S01E02**: Requires listening to S01E01
- **S01E03**: Requires listening to S01E02
- **S01E04**: Requires listening to S01E03
- **S01E05**: Requires listening to S01E04 (Season Finale)

### Season 2 (Example)
- **S02E01**: Requires listening to S01E05

## Usage Examples

### Check if User Can Unlock Episode
```dart
final storyService = StoryService();
final canUnlock = await storyService.canUnlockEpisode(userId, 'S01E03');
if (canUnlock) {
  print('User can unlock S01E03');
} else {
  print('User needs to complete S01E02 first');
}
```

### Get Next Available Episode
```dart
final nextEpisode = await storyService.getNextEpisodeByProgression(userId, seasonId);
if (nextEpisode != null) {
  print('Next episode: ${nextEpisode.title}');
} else {
  print('Season completed!');
}
```

### Get User's Overall Progress
```dart
final progress = await storyService.getUserProgressionStatus(userId);
print('Overall progress: ${progress.overallProgressPercentage}%');
print('Total completed episodes: ${progress.totalCompletedEpisodes}');

for (final season in progress.seasonStatuses.values) {
  print('${season.seasonTitle}: ${season.progressPercentage}%');
}
```

### Get Recommended Next Episode
```dart
final recommended = await storyService.getRecommendedNextEpisode(userId);
if (recommended != null) {
  print('Recommended: ${recommended.title}');
}
```

## Adding New Episodes

### 1. Update the Progression Table
```dart
// In StoryService class, add to _episodeProgressionTable
'S01E06': EpisodeProgression(
  episodeId: 'S01E06',
  prerequisites: ['S01E05'],
  nextEpisodes: ['S01E07'],
  unlockRequirements: {
    'completedEpisodes': ['S01E05'],
  },
),
```

### 2. Validate the Table
```dart
final issues = StoryService.validateProgressionTable();
for (final issue in issues) {
  print(issue);
}
```

## Progression Logic

### Unlock Requirements Check
1. **Prerequisites**: All required episodes must be listened to/completed
2. **Story Progression**: User must follow the narrative sequence
3. **No Gameplay Requirements**: Distance, level, or other stats are not required

### Next Episode Selection
1. Find user's highest completed episode in season
2. Check progression table for next available episodes
3. Verify user meets unlock requirements
4. Return first available episode

### Progress Tracking
- Tracks completed episodes per season
- Calculates progress percentages
- Identifies unlockable vs. locked episodes
- Provides overall user progression status

## Error Handling

The system includes comprehensive error handling:
- Graceful fallbacks when episodes aren't found
- Detailed logging for debugging
- Safe defaults for missing data
- Validation for circular dependencies

## Performance Considerations

- Progression table is stored in memory for fast lookups
- Database queries are minimized through caching
- Batch operations for multiple episode checks
- Efficient dependency graph traversal

## Future Enhancements

### Planned Features
- Dynamic progression table updates from database
- Time-based episode availability (weekly releases)
- Social progression (friend completion requirements)
- Story branching based on user choices
- Episode ratings and feedback system

### Configuration Options
- Custom prerequisite logic
- Season-specific progression rules
- User group progression paths
- Story arc dependencies

## Testing

Run the demonstration file to test the system:
```bash
cd runners_saga/lib/shared/services
dart story_service_test.dart
```

## Integration Points

### UI Components
- Episode selection screens
- Progress indicators
- Unlock notifications
- Achievement displays

### Services
- **Episode Progress**: Story progression and episode unlocking
- **User Stats**: Running performance tracking (separate system)
- **Achievement System**: Game accomplishments and rewards
- **Notification System**: Episode unlocks and progress updates

### Database
- **User Progress Collection**: Episode completion status
- **Episode Metadata**: Story content and progression rules
- **User Stats Collection**: Running performance data (separate)
- **Achievement Records**: Game accomplishments

## System Separation

### Episode Progress vs User Stats
The app maintains two completely separate tracking systems:

1. **Episode Progression System** (This document)
   - Tracks which episodes user has listened to/completed
   - Determines episode unlocking based on story sequence
   - Focuses on narrative continuity and user engagement

2. **User Statistics System** (Separate system)
   - Tracks running performance (distance, time, pace, etc.)
   - Records achievements and milestones
   - Provides personal fitness insights and goals
   - **Does NOT affect episode progression**

### Why This Separation?
- **Story Integrity**: Episode progression follows narrative logic, not fitness performance
- **User Experience**: Users can enjoy the story regardless of running ability
- **Data Clarity**: Clean separation of story progress vs. fitness tracking
- **Flexibility**: Each system can evolve independently

## Best Practices

1. **Always check prerequisites** before allowing episode access
2. **Validate progression table** when adding new episodes
3. **Keep episode progress separate** from user running statistics
4. **Cache user progress** to minimize database calls
5. **Log progression events** for analytics and debugging
6. **Handle edge cases** gracefully (missing episodes, invalid data)

## Troubleshooting

### Common Issues
- **Episode not unlocking**: Check prerequisites and requirements
- **Circular dependencies**: Use validation method to detect
- **Missing episodes**: Verify episode IDs in progression table
- **Performance issues**: Check for excessive database queries

### Debug Commands
```dart
// Validate progression table
final issues = StoryService.validateProgressionTable();

// Check episode dependencies
final dependent = service.getDependentEpisodes('S01E01');

// Get progression path
final path = service.getProgressionPath('S01E05');
```

This system ensures a balanced, engaging progression experience while maintaining story integrity and preventing users from accessing content they haven't earned.
