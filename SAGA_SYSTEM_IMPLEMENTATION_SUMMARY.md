# Saga System Implementation Summary

**Date:** January 2025  
**Status:** Requirements Updated & Planning Complete

## What We've Accomplished

### ✅ **Updated Functional Document**
- Added new requirements for target time/distance selection
- Specified music volume control during story scenes
- Defined automatic scene triggering system
- Added saga content structure requirements (5 scenes)

### ✅ **Updated Implementation Checklist**
- Revised core saga system requirements (7 total)
- Added new saga content structure section (6 requirements)
- Updated overall progress to 55% (reflecting new requirements)
- Prioritized immediate next steps

### ✅ **Created Audio Asset Structure**
- Organized folder structure for episodes, music, and sound effects
- Documented Episode 1 scene details and timing
- Created placeholders for .wav file placement
- Updated pubspec.yaml to include audio assets

## Current Saga System Requirements

### **Core Saga System (7 Requirements)**
1. ✅ Single complete saga structure
2. ✅ Mission selection from Saga Hub
3. ⏳ **Target time/distance selection before run**
4. ⏳ Music playback during missions
5. ⏳ **Music volume reduction for story scenes**
6. ⏳ **Automatic scene triggering based on time/distance**
7. ⏳ Sprint interval triggering mechanism

### **Saga Content Structure (6 Requirements)**
1. ⏳ 5-scene saga structure implementation
2. ⏳ Scene 1 at run beginning
3. ⏳ Scenes 2-4 spaced throughout run
4. ⏳ Scene 5 toward run end
5. ⏳ .wav audio file integration
6. ⏳ Automatic scene timing calculation

## Audio Content Status

### **Episode 1: "First Run"**
- **Scene 1:** Mission Briefing (3 min) - ✅ Recorded (.wav available)
- **Scene 2:** The Journey (4 min) - ✅ Recorded (.wav available)
- **Scene 3:** First Contact (4 min) - ⏳ Pending recording
- **Scene 4:** The Crisis (5 min) - ⏳ Pending recording
- **Scene 5:** Extraction/Debrief (3 min) - ⏳ Pending recording

**Total Runtime:** 19 minutes (when all scenes complete)

## Next Implementation Steps

### **Immediate (Next 2 weeks)**
1. **Place Recorded Audio Files**
   - Move your .wav files to `assets/audio/episodes/episode_1/`
   - Use exact naming: `scene_1_mission_briefing.wav`, `scene_2_the_journey.wav`

2. **Create Target Time/Distance Selection UI**
   - Add screen before run starts
   - Allow user to choose: "Run for 20 minutes" or "Run 3 miles"
   - Store selection for scene timing calculations

3. **Implement Scene Timing Logic**
   - Calculate when each scene should play based on user's choice
   - Scene 1: Run start (0%)
   - Scene 2: 25% of run
   - Scene 3: 50% of run
   - Scene 4: 75% of run
   - Scene 5: 90% of run

4. **Build Audio Control System**
   - Implement audioplayers package functionality
   - Create music volume reduction during story scenes
   - Resume music after scene completion

### **Short-term (Next month)**
1. **Complete Audio Integration**
   - Test scene playback with recorded files
   - Implement background music system
   - Add sound effects for immersion

2. **Scene Triggering System**
   - Automatic scene activation based on run progress
   - Handle edge cases (run shorter/longer than expected)
   - Add visual indicators during scene playback

## Technical Implementation Notes

### **Scene Timing Algorithm**
```dart
// Example timing calculation
void calculateSceneTimings(RunTarget target) {
  if (target.type == RunTargetType.time) {
    // Time-based spacing
    scene1Time = Duration.zero;
    scene2Time = target.duration * 0.25;
    scene3Time = target.duration * 0.50;
    scene4Time = target.duration * 0.75;
    scene5Time = target.duration * 0.90;
  } else {
    // Distance-based spacing
    scene1Distance = 0.0;
    scene2Distance = target.distance * 0.25;
    scene3Distance = target.distance * 0.50;
    scene4Distance = target.distance * 0.75;
    scene5Distance = target.distance * 0.90;
  }
}
```

### **Audio Volume Control**
```dart
// Example volume management
Future<void> playStoryScene(String sceneFile) async {
  // Reduce music volume to minimum
  await audioPlayer.setVolume(0.1);
  
  // Play story scene
  await storyPlayer.play(AssetSource(sceneFile));
  
  // Wait for scene completion
  await storyPlayer.onPlayerComplete.first;
  
  // Restore music volume
  await audioPlayer.setVolume(1.0);
}
```

## Success Criteria

### **Phase 1: Basic Functionality**
- [ ] User can select run target (time/distance)
- [ ] Scene 1 plays at run start
- [ ] Scene 2 plays at 25% of run
- [ ] Music volume reduces during story scenes
- [ ] Music resumes after scene completion

### **Phase 2: Full Integration**
- [ ] All 5 scenes play at correct intervals
- [ ] Scene timing adapts to actual run duration
- [ ] Background music system works seamlessly
- [ ] Sprint intervals are triggered appropriately

### **Phase 3: Polish & Testing**
- [ ] Audio quality is clear and immersive
- [ ] Scene transitions are smooth
- [ ] System handles edge cases gracefully
- [ ] User experience is engaging and motivating

## Files to Create/Modify

### **New Files Needed**
- `lib/features/run/screens/run_target_selection_screen.dart`
- `lib/features/run/services/scene_timing_service.dart`
- `lib/features/run/services/audio_control_service.dart`
- `lib/shared/models/run_target_model.dart`

### **Files to Modify**
- `lib/features/run/screens/run_screen.dart` - Add scene triggering
- `lib/shared/providers/run_providers.dart` - Add run target state
- `lib/shared/models/run_model.dart` - Add target information

## Questions for You

1. **Audio Files:** Where are your recorded .wav files currently located? I can help you move them to the correct assets folder.

2. **Scene Timing:** Do you want the scenes to be evenly spaced (25%, 50%, 75%, 90%) or would you prefer different timing intervals?

3. **Music Integration:** Do you want to integrate with specific music streaming services (Spotify, Apple Music) or just local device music?

4. **Sprint Intervals:** Should these be triggered at specific story moments or based on user pace changes?

## Next Session Goals

1. Place recorded audio files in assets folder
2. Create run target selection UI
3. Implement basic scene timing logic
4. Test audio playback with existing files

This will give us a working foundation to build upon for the complete saga system.
