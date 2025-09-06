# **Single Audio File System Usage Guide**

## **Overview**

The new single audio file system solves background audio compatibility issues by using one continuous audio file with precise scene timestamps instead of multiple separate audio files.

## **How It Works**

1. **Single Audio File**: One MP3/WAV file containing all 5 scenes in sequence
2. **Scene Timestamps**: Precise time markers for each scene trigger point
3. **Audio Seeking**: Uses `just_audio`'s `seek()` method for precise positioning
4. **Pause/Resume Logic**: Automatically pauses at scene boundaries, resumes when triggered

## **Benefits**

- ✅ **Better background compatibility** - One audio session is easier to maintain
- ✅ **No file loading issues** - Audio is already loaded and playing
- ✅ **Precise scene timing** - Exact timestamp control for scene triggers
- ✅ **Simpler state management** - One audio player instance
- ✅ **More reliable background operation** - Pause/unpause is more reliable than file loading

## **Implementation**

### **1. SceneTriggerService Changes**

The service now supports both modes:
- **Single File Mode**: Uses timestamps and seeking
- **Multiple File Mode**: Original system (fallback)

### **2. New Methods Added**

```dart
// Enable single audio file mode
void setSingleAudioFile(String audioFilePath)

// Update scene timestamps
void updateSceneTimestamps(Map<SceneType, Duration> timestamps)

// Start playback from beginning
Future<void> startSingleAudioFilePlayback()

// Check if in single file mode
bool get isSingleFileMode
```

### **3. RunSessionManager Integration**

```dart
// Enable single audio file mode during an active session
await runSessionManager.enableSingleAudioFileMode(
  audioFilePath: '/path/to/episode_audio.mp3',
  sceneTimestamps: {
    SceneType.missionBriefing: Duration.zero,
    SceneType.theJourney: Duration(seconds: 120),      // 2:00
    SceneType.firstContact: Duration(seconds: 240),    // 4:00
    SceneType.theCrisis: Duration(seconds: 420),       // 7:00
    SceneType.extractionDebrief: Duration(seconds: 540), // 9:00
  },
);
```

## **Usage Example**

### **Step 1: Create Single Audio File**
- Combine all 5 scenes into one MP3/WAV file
- Ensure scenes are in the correct order
- Note the exact timestamps for each scene

### **Step 2: Determine Scene Timestamps**
```dart
final sceneTimestamps = {
  SceneType.missionBriefing: Duration.zero,           // 0:00
  SceneType.theJourney: Duration(seconds: 120),       // 2:00
  SceneType.firstContact: Duration(seconds: 240),     // 4:00
  SceneType.theCrisis: Duration(seconds: 420),        // 7:00
  SceneType.extractionDebrief: Duration(seconds: 540), // 9:00
};
```

### **Step 3: Enable Single File Mode**
```dart
// After starting a session
await runSessionManager.enableSingleAudioFileMode(
  audioFilePath: '/path/to/episode_audio.mp3',
  sceneTimestamps: sceneTimestamps,
);
```

### **Step 4: Start Playback**
```dart
// Start from the beginning
await sceneTriggerService.startSingleAudioFilePlayback();
```

## **Scene Triggering Logic**

1. **Progress Calculation**: Based on elapsed time vs. target time
2. **Scene Check**: When progress reaches trigger percentage
3. **Audio Seeking**: Seeks to exact scene timestamp
4. **Playback**: Resumes audio from that position
5. **Auto-Pause**: Pauses 1 second before next scene boundary

## **Background Audio Handling**

- **In Foreground**: Audio plays normally with seeking
- **In Background**: Scenes are queued, audio continues playing
- **Return to Foreground**: Queued scenes automatically resume
- **No File Loading**: Audio session remains active throughout

## **Fallback Compatibility**

The system automatically falls back to the original multiple file system if:
- Single audio file is not provided
- Scene timestamps are missing
- Single file mode is not enabled

## **Testing**

### **Test Single File Mode**
1. Start a run session
2. Enable single audio file mode with test file
3. Verify scene triggering works with timestamps
4. Test background/foreground transitions

### **Test Fallback Mode**
1. Start a run session without single file
2. Verify original multiple file system works
3. Ensure no breaking changes

## **File Requirements**

### **Audio File Format**
- **Format**: MP3 or WAV (recommended)
- **Quality**: 128kbps or higher for good audio
- **Duration**: ~10 minutes (based on your estimate)
- **Scenes**: All 5 scenes in sequence

### **Scene Structure**
```
0:00 - 2:00   : Mission Briefing
2:00 - 4:00   : The Journey  
4:00 - 7:00   : First Contact
7:00 - 9:00   : The Crisis
9:00 - 10:00  : Extraction & Debrief
```

## **Next Steps**

1. **Create the single audio file** with all 5 scenes
2. **Determine exact timestamps** for each scene
3. **Test the system** with the new audio file
4. **Verify background compatibility** works as expected

## **Troubleshooting**

### **Audio Not Playing**
- Check file path is correct
- Verify audio file format is supported
- Check scene timestamps are accurate

### **Scene Timing Issues**
- Verify timestamps match actual audio content
- Check if audio file has correct scene order
- Ensure no gaps between scenes

### **Background Issues**
- Verify audio session configuration
- Check app lifecycle handling
- Test with different background states

---

**Note**: This system is designed to be backward compatible. You can test it alongside the existing multiple file system and switch between them as needed.













