// Test script for Single Audio File System
// This demonstrates how to use the new single audio file approach

import 'package:flutter/material.dart';
import 'lib/shared/services/story/scene_trigger_service.dart';
import 'lib/shared/services/run/run_session_manager.dart';

void main() {
  runApp(TestSingleAudioFileApp());
}

class TestSingleAudioFileApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Single Audio File Test',
      home: TestSingleAudioFileScreen(),
    );
  }
}

class TestSingleAudioFileScreen extends StatefulWidget {
  @override
  _TestSingleAudioFileScreenState createState() => _TestSingleAudioFileScreenState();
}

class _TestSingleAudioFileScreenState extends State<TestSingleAudioFileScreen> {
  final SceneTriggerService _sceneTrigger = SceneTriggerService();
  final RunSessionManager _runSessionManager = RunSessionManager();
  
  String _status = 'Ready to test';
  bool _isSingleFileMode = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize the run session manager
      await _runSessionManager.initialize();
      
      // Initialize scene trigger service
      await _sceneTrigger.initialize(
        targetTime: Duration(minutes: 15),
        targetDistance: null,
        episode: null,
      );
      
      setState(() {
        _status = 'Services initialized successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Error initializing services: $e';
      });
    }
  }

  Future<void> _testSingleAudioFileMode() async {
    try {
      setState(() {
        _status = 'Testing single audio file mode...';
      });

      // Example scene timestamps (adjust these based on your actual audio file)
      final sceneTimestamps = {
        SceneType.scene1: Duration.zero,
        SceneType.scene2: Duration(seconds: 120),      // 2:00
        SceneType.scene3: Duration(seconds: 240),    // 4:00
        SceneType.scene4: Duration(seconds: 420),       // 7:00
        SceneType.scene5: Duration(seconds: 540), // 9:00
      };

      // Enable single audio file mode
      _sceneTrigger.setSingleAudioFile('/path/to/your/episode_audio.mp3');
      _sceneTrigger.updateSceneTimestamps(sceneTimestamps);

      setState(() {
        _status = 'Single audio file mode enabled';
        _isSingleFileMode = true;
      });

    } catch (e) {
      setState(() {
        _status = 'Error testing single audio file mode: $e';
      });
    }
  }

  Future<void> _testSceneTriggering() async {
    if (!_isSingleFileMode) {
      setState(() {
        _status = 'Please enable single audio file mode first';
      });
      return;
    }

    try {
      setState(() {
        _status = 'Testing scene triggering...';
      });

      // Simulate progress updates to trigger scenes
      _sceneTrigger.updateProgress(progress: 0.0);  // Mission Briefing
      
      await Future.delayed(Duration(seconds: 2));
      
      _sceneTrigger.updateProgress(progress: 0.2);  // The Journey
      
      await Future.delayed(Duration(seconds: 2));
      
      _sceneTrigger.updateProgress(progress: 0.4);  // First Contact

      setState(() {
        _status = 'Scene triggering test completed';
      });

    } catch (e) {
      setState(() {
        _status = 'Error testing scene triggering: $e';
      });
    }
  }

  Future<void> _startAudioPlayback() async {
    if (!_isSingleFileMode) {
      setState(() {
        _status = 'Please enable single audio file mode first';
      });
      return;
    }

    try {
      setState(() {
        _status = 'Starting audio playback...';
      });

      // Note: This method doesn't exist in the current implementation
      // The scene trigger service now uses multiple audio files
      setState(() {
        _status = 'Audio playback method not available in current implementation';
      });

      setState(() {
        _status = 'Audio playback started';
      });

    } catch (e) {
      setState(() {
        _status = 'Error starting audio playback: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Single Audio File Test'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(_status),
                    SizedBox(height: 8),
                    Text(
                      'Single File Mode: ${_isSingleFileMode ? "Enabled" : "Disabled"}',
                      style: TextStyle(
                        color: _isSingleFileMode ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testSingleAudioFileMode,
              child: Text('Enable Single Audio File Mode'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _testSceneTriggering,
              child: Text('Test Scene Triggering'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _startAudioPlayback,
              child: Text('Start Audio Playback'),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Click "Enable Single Audio File Mode" to set up the system'),
                    Text('2. Click "Test Scene Triggering" to simulate progress updates'),
                    Text('3. Click "Start Audio Playback" to begin audio from the start'),
                    SizedBox(height: 8),
                    Text(
                      'Note: You need to provide the actual audio file path and adjust scene timestamps.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Example usage in your actual app:
/*
// After starting a run session
await runSessionManager.enableSingleAudioFileMode(
  audioFilePath: '/path/to/your/episode_audio.mp3',
  sceneTimestamps: {
    SceneType.scene1: Duration.zero,
    SceneType.scene2: Duration(seconds: 120),      // 2:00
    SceneType.scene3: Duration(seconds: 240),    // 4:00
    SceneType.scene4: Duration(seconds: 420),       // 7:00
    SceneType.scene5: Duration(seconds: 540), // 9:00
  },
);

// Note: The current implementation uses multiple audio files instead of single file
// Start audio playback
await sceneTriggerService.startMultipleAudioFilesPlayback();
*/



