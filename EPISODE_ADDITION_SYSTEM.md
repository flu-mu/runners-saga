# Episode Addition System for The Runner's Saga

## Overview
The Runner's Saga is designed with a scalable, database-driven architecture that makes adding new episodes straightforward and maintainable. The system follows a clear hierarchy:

- **Season** (e.g., S01) contains 8-10 episodes
- **Episode** (e.g., S01E02) contains 5 scenes that happen during one complete run
- **Scenes** are the story segments that play throughout the run

## Naming Convention
- **Seasons**: S01, S02, S03, etc.
- **Episodes**: S01E01, S01E02, S01E03, etc.
- **Audio Files**: `scene_1_mission_briefing.wav`, `scene_2_the_journey.wav`, etc.

## How New Episodes Are Added

### 1. Content Creation
1. **Script Writing**: Create a 5-scene script for the new episode
2. **Audio Recording**: Record each scene in .wav format
3. **File Naming**: Use consistent naming convention for audio files

### 2. Database Updates
The episode is added to Firestore with the following structure:

```dart
EpisodeModel(
  id: 'S01E02', // Season 1, Episode 2
  sagaId: 'fantasy_quest_saga',
  title: 'Episode Title',
  description: 'Episode description',
  status: 'locked', // 'locked', 'available', 'in_progress', 'completed'
  order: 2, // Episode sequence number
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  objective: 'Episode objective',
  targetDistance: 10.0, // km
  targetTime: Duration(minutes: 30),
  audioFile: 'episode_audio_reference',
  requirements: {
    'totalDistance': 15.0, // User must have run 15km total
    'totalRuns': 3, // User must have completed 3 runs
  },
  rewards: {
    'experience': 100,
    'unlockNextEpisode': true,
  },
)
```

### 3. Audio File Management
Audio files are stored in Firebase Cloud Storage with organized folder structure:
```
assets/audio/episodes/
├── S01E01/
│   ├── scene_1_mission_briefing.wav
│   ├── scene_2_the_journey.wav
│   ├── scene_3_first_contact.wav
│   ├── scene_4_the_crisis.wav
│   └── scene_5_extraction_debrief.wav
├── S01E02/
│   ├── scene_1_mission_briefing.wav
│   └── ... (5 scenes)
└── S01E03/
    └── ... (5 scenes)
```

### 4. Automatic Progression
The app automatically handles episode progression:
- Users complete episodes in sequence (S01E01 → S01E02 → S01E03)
- No manual episode selection required
- Progress is tracked in Firestore
- Requirements automatically unlock next episodes

### 5. Scene Timing
Each episode's 5 scenes are automatically spaced throughout the run:
- **Scene 1**: Beginning of run (0% progress)
- **Scene 2**: 25% through run
- **Scene 3**: 50% through run  
- **Scene 4**: 75% through run
- **Scene 5**: End of run (100% progress)

## Technical Implementation

### Database Collections
- `sagas`: Saga metadata and episode references
- `episodes`: Individual episode data
- `story_segments`: Scene-level story content
- `user_progress`: User completion status for episodes

### Code Structure
- `EpisodeModel`: Data model for episodes
- `StorySegmentModel`: Data model for scenes
- `StoryService`: Service for episode management
- `StoryProviders`: State management for episodes

### Adding a New Episode
1. Create episode data in Firestore
2. Upload audio files to Cloud Storage
3. Update saga metadata to include new episode
4. The app automatically recognizes and loads the new episode

## Benefits of This System

### Scalability
- Easy to add new seasons and episodes
- No app updates required for new content
- Database-driven content management

### User Experience
- Seamless progression through episodes
- Automatic unlocking based on progress
- Consistent story structure

### Development
- Clear separation of concerns
- Reusable code patterns
- Easy testing and maintenance

## Future Enhancements
- **Dynamic Content**: AI-generated episode variations
- **User-Generated Content**: Community-created episodes
- **Seasonal Events**: Special limited-time episodes
- **Cross-Season Storylines**: Episodes that span multiple seasons

## Example: Adding S01E02
1. Write script for 5 scenes
2. Record audio files
3. Create EpisodeModel in Firestore
4. Upload audio to Cloud Storage
5. Update saga metadata
6. Users automatically see S01E02 after completing S01E01

This system ensures that The Runner's Saga can grow organically while maintaining quality and consistency across all episodes.
