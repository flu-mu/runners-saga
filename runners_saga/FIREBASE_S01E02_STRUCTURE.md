# **Firebase Data Structure for S01E02 - Single Audio File**

## **Episode Document Structure**

**Collection**: `episodes`  
**Document ID**: `S01E02`

```json
{
  "id": "S01E02",
  "seasonId": "S01",
  "title": "Distraction",
  "description": "Dead herring",
  "status": "unlocked",
  "order": 2,
  "createdAt": "2025-08-31T18:00:00.000Z",
  "updatedAt": "2025-08-31T18:00:00.000Z",
  "objective": "Continue your investigation",
  "targetDistance": 7.0,
  "targetTime": 2400000,
  "audioFiles": [], // Keep empty array for backward compatibility
  "audioFile": "https://runners-saga-app.firebasestorage.app/audio/episodes/S01E02/S01E02_complete_episode.mp3",
  "sceneTimestamps": [
    {
      "sceneType": "missionBriefing",
      "startTime": "0:00",
      "endTime": "0:07",
      "startSeconds": 0,
      "endSeconds": 7
    },
    {
      "sceneType": "theJourney",
      "startTime": "0:08",
      "endTime": "2:06",
      "startSeconds": 8,
      "endSeconds": 126
    },
    {
      "sceneType": "firstContact",
      "startTime": "2:07",
      "endTime": "3:52",
      "startSeconds": 127,
      "endSeconds": 232
    },
    {
      "sceneType": "theCrisis",
      "startTime": "3:53",
      "endTime": "5:28",
      "startSeconds": 233,
      "endSeconds": 328
    },
    {
      "sceneType": "extractionDebrief",
      "startTime": "5:29",
      "endTime": "6:40",
      "startSeconds": 329,
      "endSeconds": 400
    }
  ],
  "requirements": {},
  "rewards": {},
  "metadata": {
    "audioDuration": "6:40",
    "audioDurationSeconds": 400,
    "singleFileMode": true,
    "sceneCount": 5
  }
}
```

## **Firebase Storage Structure**

**Path**: `audio/episodes/S01E02/S01E02_complete_episode.mp3`

- **File**: Single MP3/WAV file containing all 5 scenes
- **Duration**: 6 minutes 40 seconds (400 seconds)
- **Format**: MP3 or WAV (recommended: MP3 at 128kbps or higher)

## **Scene Mapping**

| Scene Type | Start Time | End Time | Duration | Trigger % |
|------------|------------|----------|----------|-----------|
| Mission Briefing | 0:00 | 0:07 | 7s | 0% |
| The Journey | 0:08 | 2:06 | 1m 58s | 20% |
| First Contact | 2:07 | 3:52 | 1m 45s | 40% |
| The Crisis | 3:53 | 5:28 | 1m 35s | 70% |
| Extraction & Debrief | 5:29 | 6:40 | 1m 11s | 90% |

## **Implementation Notes**

### **1. Backward Compatibility**
- Keep `audioFiles` as empty array for existing code
- Add new `audioFile` field for single file
- Add `sceneTimestamps` array for scene timing

### **2. Automatic Detection**
The system will automatically:
- Detect if episode has `audioFile` and `sceneTimestamps`
- Enable single audio file mode automatically
- Fall back to multiple files if single file data is missing

### **3. Scene Triggering**
- Scene 1 (Mission Briefing): Triggers at 0% progress
- Scene 2 (The Journey): Triggers at 20% progress  
- Scene 3 (First Contact): Triggers at 40% progress
- Scene 4 (The Crisis): Triggers at 70% progress
- Scene 5 (Extraction & Debrief): Triggers at 90% progress

### **4. Audio File Requirements**
- **Single file**: All 5 scenes in sequence
- **No gaps**: Ensure smooth transitions between scenes
- **Quality**: High enough for good audio experience
- **Size**: Optimize for download (recommend < 50MB)

## **Testing Steps**

1. **Upload the single audio file** to Firebase Storage
2. **Update the episode document** with the new structure
3. **Test the app** by selecting S01E02
4. **Verify single file mode** is automatically enabled
5. **Test scene triggering** during a run
6. **Test background/foreground** transitions

## **Expected Behavior**

- **Episode Selection**: S01E02 should download the single audio file
- **Run Start**: Single audio file mode should be automatically enabled
- **Scene Triggers**: Audio should seek to exact timestamps
- **Background Audio**: Should work reliably with single audio session
- **Fallback**: If single file fails, should fall back to multiple files

---

**Note**: This structure maintains backward compatibility while adding the new single audio file functionality. Existing episodes will continue to work, and new episodes can use either approach.
