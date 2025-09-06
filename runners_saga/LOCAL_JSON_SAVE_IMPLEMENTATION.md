# Local JSON Save Implementation

## Overview
Implemented a comprehensive local JSON file save system for run data that allows users to save their run data locally on their phone and upload it to Firebase later.

## What Was Implemented

### 1. Local Run Storage Service (`lib/shared/services/local/local_run_storage_service.dart`)
- **Purpose**: Handles saving run data to local JSON files
- **Key Features**:
  - Saves run data with GPS points, duration, distance, episode info
  - Generates unique filenames with timestamps
  - Converts `Position` objects to JSON-serializable format
  - Manages file storage in app documents directory
  - Tracks file status (pending_upload, uploaded)
  - Provides storage statistics

### 2. Firebase Upload Service (`lib/shared/services/local/local_to_firebase_upload_service.dart`)
- **Purpose**: Handles uploading locally saved run data to Firebase
- **Key Features**:
  - Uploads all pending run files to Firebase
  - Converts local JSON data back to Firebase format
  - Marks files as uploaded after successful upload
  - Provides upload statistics and error handling
  - Cleans up uploaded files

### 3. Updated Finish Run Method (`lib/features/run/screens/run_screen.dart`)
- **Integration**: Added local JSON save to the `_finishRun()` method
- **Process**:
  1. Generates unique run ID
  2. Saves run data locally as JSON file
  3. Continues with existing Firebase save
  4. Provides error handling for local save failures

## How It Works

### Data Flow
1. **Run Completion**: When user finishes a run, `_finishRun()` is called
2. **Local Save**: Run data is immediately saved to local JSON file
3. **Firebase Save**: Run data is also saved to Firebase (existing functionality)
4. **Upload Later**: Local files can be uploaded to Firebase when network is available

### File Structure
```
App Documents Directory/
└── runs/
    ├── run_1234567890_1234567890.json
    ├── run_1234567891_1234567891.json
    └── ...
```

### JSON Format
```json
{
  "runId": "run_1234567890",
  "userId": "user_1234567890",
  "episodeId": "S01E01",
  "timestamp": "2025-01-05T21:30:00.000Z",
  "duration": 225,
  "distance": 0.5,
  "gpsPoints": [
    {
      "latitude": 40.7128,
      "longitude": -74.0060,
      "accuracy": 5.0,
      "altitude": 10.0,
      "heading": 90.0,
      "speed": 5.0,
      "timestamp": "2025-01-05T21:30:00.000Z"
    }
  ],
  "gpsPointCount": 1,
  "additionalData": {
    "episodeTitle": "Episode S01E01",
    "runType": "story_driven",
    "deviceInfo": "mobile",
    "appVersion": "1.0.0"
  },
  "status": "pending_upload",
  "version": "1.0"
}
```

## Key Benefits

### 1. **Offline Support**
- Run data is saved locally even without internet connection
- Users can complete runs offline and upload later

### 2. **Data Safety**
- Run data is never lost due to network issues
- Local backup provides redundancy

### 3. **Performance**
- Local save is immediate and doesn't block UI
- Firebase save can happen in background

### 4. **Flexibility**
- Can upload data when network is available
- Can retry failed uploads
- Can manage storage locally

## Usage

### Automatic Local Save
The local save happens automatically when a run is finished. No user interaction required.

### Manual Upload (Programmatic)
```dart
// Upload all pending runs
final result = await LocalToFirebaseUploadService.uploadAllPendingRuns();

// Upload specific run
final success = await LocalToFirebaseUploadService.uploadRunByPath('/path/to/run.json');

// Get storage stats
final stats = await LocalRunStorageService.getStorageStats();
```

### File Management
```dart
// Get pending files
final pendingFiles = await LocalRunStorageService.getPendingRunFiles();

// Mark as uploaded
await LocalRunStorageService.markAsUploaded('/path/to/run.json');

// Delete uploaded file
await LocalRunStorageService.deleteRunFile('/path/to/run.json');
```

## Error Handling
- Local save failures don't prevent Firebase save
- Upload failures are logged and can be retried
- File operations include comprehensive error handling
- Graceful degradation if local storage is unavailable

## Future Enhancements
- Background sync service for automatic uploads
- Compression for large GPS datasets
- Encryption for sensitive data
- Cloud storage integration (Google Drive, iCloud)
- Data export functionality

## Files Modified
- `lib/features/run/screens/run_screen.dart` - Added local save to `_finishRun()`
- `lib/shared/services/local/local_run_storage_service.dart` - New service
- `lib/shared/services/local/local_to_firebase_upload_service.dart` - New service

## Dependencies Used
- `path_provider` - For app documents directory access
- `dart:convert` - For JSON serialization
- `dart:io` - For file operations
- `geolocator` - For GPS data types
- `cloud_firestore` - For Firebase uploads
- `firebase_auth` - For user authentication

The implementation is complete and ready for use. Run data will now be automatically saved locally as JSON files when users finish their runs.











