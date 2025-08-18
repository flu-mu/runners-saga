# Audio Assets for The Runner's Saga

This folder contains the audio files for the saga story scenes.

## File Structure

```
assets/audio/
├── episodes/
│   └── S01E01/
│       ├── scene_1_mission_briefing.wav
│       ├── scene_2_the_journey.wav
│       ├── scene_3_first_contact.wav
│       ├── scene_4_the_crisis.wav
│       └── scene_5_extraction_debrief.wav
├── music/
│   ├── background/
│   ├── action/
│   └── ambient/
└── sfx/
    ├── footsteps.wav
    ├── zombie_sounds.wav
    └── ui_sounds.wav
```

## Episode 1: "First Run" - Scene Details

### Scene 1: Mission Briefing (3 minutes)
- **File:** `scene_1_mission_briefing.wav`
- **Runtime:** ~3 minutes
- **Content:** Commander Morrison briefing Riley, Maya introduction, mission overview
- **Status:** ✅ Recorded (.wav file available)

### Scene 2: The Journey (4 minutes)
- **File:** `scene_2_the_journey.wav`
- **Runtime:** ~4 minutes
- **Content:** Riley and Maya traveling through suburbs, first encounter with runner zombies
- **Status:** ✅ Recorded (.wav file available)

### Scene 3: First Contact (4 minutes)
- **File:** `scene_3_first_contact.wav`
- **Runtime:** ~4 minutes
- **Content:** Runner zombie chase, mall entrance, shopping cart obstacle course
- **Status:** ⏳ Pending recording

### Scene 4: The Crisis (5 minutes)
- **File:** `scene_4_the_crisis.wav`
- **Runtime:** ~5 minutes
- **Content:** Mall interior, GameStop supply retrieval, rooftop escape
- **Status:** ⏳ Pending recording

### Scene 5: Extraction/Debrief (3 minutes)
- **File:** `scene_5_extraction_debrief.wav`
- **Runtime:** ~3 minutes
- **Content:** Return to base, mission debrief, Dr. Chen communication
- **Status:** ⏳ Pending recording

## Audio Specifications

- **Format:** WAV (uncompressed for best quality)
- **Sample Rate:** 44.1 kHz
- **Bit Depth:** 16-bit
- **Channels:** Stereo
- **File Size:** Approximately 2-4 MB per scene

## Integration Notes

- Scenes are triggered automatically based on run progress
- Scene 1 plays at run start
- Scenes 2-4 are spaced evenly throughout the run
- Scene 5 plays toward the end
- Music volume is reduced to minimum during scene playback
- Background music resumes after each scene completes

## Next Steps

1. ✅ Place recorded .wav files in appropriate folders
2. ⏳ Record remaining scenes (3-5)
3. ⏳ Create background music tracks
4. ⏳ Add sound effects for immersion
5. ⏳ Test audio integration in the app
