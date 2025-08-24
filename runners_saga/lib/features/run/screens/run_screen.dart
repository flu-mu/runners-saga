import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../main.dart'; // Import to access isFirebaseReady
import '../../../shared/providers/run_session_providers.dart';
import '../../../shared/providers/story_providers.dart';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/providers/run_providers.dart';
import '../../../shared/providers/run_completion_providers.dart';
import '../../../shared/providers/audio_providers.dart';
import '../../../shared/providers/settings_providers.dart';
import '../../../shared/services/scene_trigger_service.dart';
import '../../../shared/services/run_session_manager.dart';
import '../../../shared/services/audio_manager.dart';
import '../../../shared/services/download_service.dart';
import '../../../shared/models/episode_model.dart';
import '../../../core/constants/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../widgets/run_map_panel.dart';
import '../widgets/scene_hud.dart';
import '../widgets/scene_progress_indicator.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/run_completion_service.dart';
import '../../../shared/models/run_model.dart';
import '../../../shared/models/run_target_model.dart';
import '../screens/run_summary_screen.dart';


class RunScreen extends ConsumerStatefulWidget {
  const RunScreen({super.key});

  @override
  ConsumerState<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends ConsumerState<RunScreen> {
  bool _isInitializing = true;
  bool _timerStopped = false; // Flag to prevent timer restart
  bool _disposed = false; // Flag to prevent state updates after disposal
  
  // Simple, controllable timer
  Timer? _simpleTimer;
  bool _isTimerRunning = false;
  bool _isPaused = false;
  Duration _elapsedTime = Duration.zero;
  Duration _pausedTime = Duration.zero; // Time when paused
  
  // GPS tracking for real runs
  
  @override
  void initState() {
    super.initState();
    _isInitializing = true;
    
    // Start the run session automatically when screen loads
    // User already selected "Start Run" on home screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRun();
    });
  }
  
  /// Get episode ID from query parameters
  String? _getEpisodeIdFromQuery() {
    final uri = Uri.parse(GoRouterState.of(context).uri.toString());
    return uri.queryParameters['episodeId'];
  }
  

  
  @override
  void dispose() {
    try {
      _disposed = true;
      _stopSimpleTimer();
    } catch (e) {
      // Log error but don't let it prevent disposal
      print('⚠️ RunScreen: Error during dispose: $e');
    } finally {
      super.dispose();
    }
  }
  
  /// Start a simple, controllable timer
  void _startSimpleTimer() async {
    if (_simpleTimer != null) {
      _simpleTimer!.cancel();
    }
    
    _isTimerRunning = true;
    _isPaused = false;
    
    // If resuming from pause, use the paused time, otherwise start from 0
    if (_pausedTime > Duration.zero) {
      _elapsedTime = _pausedTime;
      print('🔄 Simple timer resumed from: ${_elapsedTime.inSeconds}s');
    } else {
      _elapsedTime = Duration.zero;
      print('🚀 Simple timer started from 0');
      
      // Audio will be handled by the background session (SceneTriggerService)
      print('🎵 Audio will be managed by background session');
    }
    
    _simpleTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isTimerRunning || _timerStopped || _isPaused || _disposed) {
        timer.cancel();
        _simpleTimer = null;
        return;
      }
      
      if (mounted && !_disposed) {
        setState(() {
          _elapsedTime += const Duration(seconds: 1);
        });
      }
      
      print('⏱️ Simple timer tick: ${_elapsedTime.inSeconds}s');
    });
    
    print('🚀 Simple timer started');
  }
  
  /// Pause the simple timer
  void _pauseSimpleTimer() async {
    if (_isTimerRunning && !_isPaused) {
      _isPaused = true;
      _pausedTime = _elapsedTime; // Store current time
      
      if (_simpleTimer != null) {
        _simpleTimer!.cancel();
        _simpleTimer = null;
      }
      
      // Pause audio when pausing timer
      try {
        // Pause the background session (this will pause the scene trigger audio)
        ref.read(runSessionControllerProvider.notifier).pauseSession();
        
        // Also directly pause all audio from our audio manager
        final audioManager = ref.read(audioManagerProvider);
        await audioManager.pauseAll();
        
        print('🎵 Audio paused when timer paused (session + audio manager)');
      } catch (e) {
        print('❌ Error pausing audio: $e');
      }
      
      print('⏸️ Simple timer paused at: ${_elapsedTime.inSeconds}s');
      if (mounted && !_disposed) {
        setState(() {});
      }
    }
  }
  
  /// Stop the simple timer completely
  void _stopSimpleTimer() {
    _isTimerRunning = false;
    _isPaused = false;
    _pausedTime = Duration.zero; // Reset paused time
    
    if (_simpleTimer != null) {
      _simpleTimer!.cancel();
      _simpleTimer = null;
      print('🛑 Simple timer stopped completely');
    }
    
    // Only call setState if the widget is still mounted and not disposed
    if (mounted && !_disposed) {
      setState(() {});
    }
  }
  
  // Note: _saveRunCompletion method removed to prevent duplicate run saving
  // Run completion is now handled by RunCompletionService
  
  /// Mark episode as completed for the user
  Future<void> _markEpisodeCompleted(String episodeId) async {
    try {
      // Check if Firebase is ready
      if (!isFirebaseReady) {
        print('⚠️ RunScreen: Firebase not ready, skipping episode completion');
        return;
      }
      
      print('🏆 RunScreen: Marking episode $episodeId as completed');
      
      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.value;
      if (user == null) return;
      
      final firestore = FirebaseFirestore.instance;
      
      // Check if user already has progress for this episode
      final existingProgressQuery = await firestore
          .collection('user_progress')
          .where('userId', isEqualTo: user.uid)
          .where('episodeId', isEqualTo: episodeId)
          .limit(1)
          .get();
      
      if (existingProgressQuery.docs.isNotEmpty) {
        // Update existing progress
        final docId = existingProgressQuery.docs.first.id;
        await firestore.collection('user_progress').doc(docId).update({
          'status': 'completed',
          'completedAt': DateTime.now().toIso8601String(),
          'elapsedTime': _elapsedTime.inSeconds,
        });
      } else {
        // Create new progress entry
        await firestore.collection('user_progress').add({
          'userId': user.uid,
          'episodeId': episodeId,
          'status': 'completed',
          'completedAt': DateTime.now().toIso8601String(),
          'elapsedTime': _elapsedTime.inSeconds,
        });
      }
      
      print('✅ RunScreen: Episode marked as completed');
      
    } catch (e) {
      print('❌ RunScreen: Error marking episode as completed: $e');
      // Don't rethrow - this is not critical
    }
  }
  
  // Helper methods for timer display
  Color _getTimerDisplayColor() {
    if (_timerStopped) return Colors.grey.shade200;
    if (_isPaused) return Colors.orange.shade100;
    return Colors.green.shade100;
  }
  
  Color _getTimerDisplayBorderColor() {
    if (_timerStopped) return Colors.grey.shade400;
    if (_isPaused) return Colors.orange.shade300;
    return Colors.green.shade300;
  }
  
  IconData _getTimerDisplayIcon() {
    if (_timerStopped) return Icons.timer_off;
    if (_isPaused) return Icons.pause_circle;
    return Icons.timer;
  }
  
  Color _getTimerDisplayIconColor() {
    if (_timerStopped) return Colors.grey.shade600;
    if (_isPaused) return Colors.orange.shade600;
    return Colors.green.shade600;
  }
  
  String _getTimerDisplayText() {
    if (_isPaused) return 'Timer Paused';
    return 'Simple Timer';
  }
  
  /// Build the control buttons based on timer state
  Widget _buildControlButtons() {
    if (_isPaused) {
      // Timer paused - show resume and finish buttons
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: _resumeTimer,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _directSaveRun,
            icon: const Icon(Icons.flag),
            label: const Text('Finish Run'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kElectricAqua,
              foregroundColor: kMidnightNavy,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      );
    } else {
      // Timer running - show pause and finish buttons
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _pauseTimer,
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _directSaveRun,
              icon: const Icon(Icons.flag),
              label: const Text('Finish Run'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kElectricAqua,
                foregroundColor: kMidnightNavy,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ),
        ],
      );
    }
  }
  
  /// Direct save method that captures GPS data while session is still active
  Future<void> _directSaveRun() async {
    try {
      print('💾 RunScreen: Direct save method called - capturing GPS data BEFORE stopping session');
      
      // STEP 1: Get the RunSessionManager instance from the provider
      final runSessionManagerState = ref.read(runSessionControllerProvider);
      
      // STEP 2: Capture GPS data while session is still active using public methods
      final route = runSessionManagerState.getCurrentRoute();
      final stats = runSessionManagerState.getCurrentStats();
      
      print('💾 RunScreen: Captured ${route.length} GPS points while session active');
      print('💾 RunScreen: Stats - Distance: ${stats.distance}, Time: ${stats.elapsedTime}');
      
      if (route.isEmpty) {
        print('❌ RunScreen: No GPS data captured - cannot save run');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No GPS data to save'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // STEP 3: Get current episode and user data
      final currentEpisode = ref.read(currentEpisodeProvider);
      final currentUser = ref.read(currentUserProvider).value;
      
      if (currentUser == null || currentEpisode == null) {
        print('❌ RunScreen: Missing user or episode data');
        return;
      }
      
      // STEP 4: Create run model directly with captured data
      final runModel = RunModel(
        userId: currentUser.uid,
        startTime: DateTime.now().subtract(stats.elapsedTime),
        endTime: DateTime.now(),
        totalTime: stats.elapsedTime,
        totalDistance: stats.distance,
        averagePace: stats.averagePace,
        maxPace: stats.maxPace,
        minPace: stats.minPace,
        route: route, // Already converted to LocationPoint list
        seasonId: currentEpisode.seasonId,
        missionId: currentEpisode.id, // Using episode ID as mission ID for now
        status: RunStatus.completed,
        runTarget: RunTarget(
          id: 'quick_15',
          type: RunTargetType.time,
          value: 15.0, // We'll improve this later
          displayName: '15 minutes',
          description: 'Quick run',
          createdAt: DateTime.now(),
          isCustom: false,
        ),
      );
      
      print('💾 RunScreen: Created run model with ${runModel.route.length} GPS points');
      
      // STEP 5: Save to database using FirestoreService directly
      final firestoreService = FirestoreService();
      final runId = await firestoreService.saveRun(runModel);
      
      print('✅ RunScreen: Run saved successfully with ID: $runId');
      
      // STEP 6: Manually complete the session AFTER saving (preserves GPS data)
      final runSessionController = ref.read(runSessionControllerProvider.notifier);
      await runSessionController.manuallyCompleteSession();
      
      // STEP 7: Navigate back instead of using pushReplacement to avoid routing issues
      if (mounted) {
        Navigator.of(context).pop(); // Go back to previous screen
      }
      
    } catch (e) {
      print('❌ RunScreen: Error in direct save: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving run: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<bool> _ensureLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ RunScreen: GPS service is disabled');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable Location Services (GPS)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        await Geolocator.openLocationSettings();
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ RunScreen: Location permission permanently denied');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Open Settings to grant access.'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 3),
            ),
          );
        }
        await Geolocator.openAppSettings();
        return false;
      }

      final hasPermission =
          permission == LocationPermission.always || permission == LocationPermission.whileInUse;
      return hasPermission;
    } catch (e) {
      print('❌ RunScreen: ensureLocationPermission error: $e');
      return false;
    }
  }

  void _startRun() async {
    // Ensure GPS permission and service availability
    final permitted = await _ensureLocationPermission();
    if (!permitted) {
      setState(() {
        _isInitializing = false;
      });
      return;
    }
    print('✅ RunScreen: GPS permissions and services OK');
    
    // Don't start if timer was explicitly stopped
    if (_timerStopped) {
      print('🎯 RunScreen: Timer was stopped - not starting session');
      setState(() {
        _isInitializing = false;
      });
      return;
    }
    
    // Don't start if there's already an active session
    final isSessionActive = ref.read(runSessionControllerProvider.notifier).isSessionActive;
    if (isSessionActive) {
      print('🎯 RunScreen: Session already active - not starting new session');
      setState(() {
        _isInitializing = false;
      });
      return;
    }
    
    // Debug: Check what target data is available
    final userRunTarget = ref.read(userRunTargetProvider);
    print('🎯 RunScreen: _startRun called');
    print('🎯 RunScreen: userRunTarget from provider: $userRunTarget');
    print('🎯 RunScreen: Provider hash: ${userRunTarget.hashCode}');
    
    if (userRunTarget != null) {
      if (userRunTarget.targetDistance > 0) {
        print('🎯 RunScreen: User selected DISTANCE target: ${userRunTarget.targetDistance} km');
      } else if (userRunTarget.targetTime.inMinutes > 0) {
        print('🎯 RunScreen: User selected TIME target: ${userRunTarget.targetTime.inMinutes} min');
      }
    } else {
      print('🎯 RunScreen: No user target, using episode defaults');
    }
    
    // Get episode ID from query parameters and load episode data
    final episodeId = _getEpisodeIdFromQuery();
    print('🎯 RunScreen: Episode ID from query: $episodeId');
    
    EpisodeModel? currentEpisode;
    if (episodeId != null) {
      // Load episode data directly from the story service
      try {
        final episodeAsync = ref.read(episodeByIdProvider(episodeId));
        episodeAsync.whenData((episode) {
          if (episode != null) {
            currentEpisode = episode;
            print('🎯 RunScreen: Episode loaded: ${episode.title}');
            print('🎯 RunScreen: Episode audio files: ${episode.audioFiles.length}');
          }
        });
      } catch (e) {
        print('🎯 RunScreen: Error loading episode: $e');
      }
    }
    
    // If no episode loaded, create a fallback episode with audio files
    if (currentEpisode == null) {
      print('🎯 RunScreen: No episode loaded, creating fallback with audio');
      currentEpisode = EpisodeModel(
        id: 'S01E01',
        seasonId: 'S01',
        title: 'Fallback Episode',
        description: 'Fallback episode for testing',
        status: 'unlocked',
        order: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        objective: 'Complete your run',
        targetDistance: 5.0,
        targetTime: 1800000, // 30 minutes
        audioFiles: [
          'assets/audio/episodes/S01E01/scene_1_quick.mp3',
          'assets/audio/episodes/S01E01/scene_2_mission_briefing.mp3',
          'assets/audio/episodes/S01E01/scene_3_the_journey.mp3',
          'assets/audio/episodes/S01E01/scene_4_first_contact.mp3',
          'assets/audio/episodes/S01E01/scene_5_the_crisis.mp3'
        ],
        requirements: {},
        rewards: {},
      );
      print('🎯 RunScreen: Fallback episode created with ${currentEpisode!.audioFiles.length} audio files');
    }
    
    try {
      // Get the user's selected run target from the provider
      // User selects either distance OR time, not both
      Duration? targetTime;
      double? targetDistance;
      
      if (userRunTarget != null) {
        // User selected a target - use their selection
        if (userRunTarget.targetDistance > 0) {
          // User selected distance target
          targetDistance = userRunTarget.targetDistance;
          targetTime = null; // No time target - user only selected distance
          print('🎯 RunScreen: User selected DISTANCE target: ${userRunTarget.targetDistance} km');
        } else if (userRunTarget.targetTime.inMinutes > 0) {
          // User selected time target
          targetTime = userRunTarget.targetTime;
          targetDistance = null; // No distance target - user only selected time
          print('🎯 RunScreen: User selected TIME target: ${userRunTarget.targetTime.inMinutes} min');
        } else {
          print('🎯 RunScreen: Invalid target - both distance and time are zero');
        }
      }
      // No fallback to database - only show user selection
      
      print('🎯 RunScreen: Using targetTime: $targetTime');
      print('🎯 RunScreen: Using targetDistance: $targetDistance');
      
      // Only start if user has selected a target AND timer wasn't stopped
      print('🎯 RunScreen: Target check: targetTime=$targetTime, targetDistance=$targetDistance, _timerStopped=$_timerStopped');
      if ((targetTime != null || targetDistance != null) && !_timerStopped) {
        // Check if the run session manager can start a session
        print('🎯 RunScreen: Checking if session can start...');
        final canStart = ref.read(runSessionControllerProvider.notifier).canStartSession();
        print('🎯 RunScreen: canStartSession() returned: $canStart');
        if (canStart) {
          final trackingMode = ref.read(trackingModeProvider);
          // Force debug logging for testing
          print('🎯 RunScreen: Starting session with episode: ${currentEpisode!.id}');
          print('🎯 RunScreen: Episode audio files: ${currentEpisode!.audioFiles}');
          print('🎯 RunScreen: Audio files count: ${currentEpisode!.audioFiles.length}');
          
          print('🎯 RunScreen: About to start session...');
          await ref.read(runSessionControllerProvider.notifier).startSession(
            currentEpisode!,
            userTargetTime: targetTime ?? const Duration(minutes: 30),
            userTargetDistance: targetDistance ?? 5.0,
            trackingMode: trackingMode,
          );
          print('🎯 RunScreen: Session start completed');
          print('🎯 RunScreen: Session active: ${ref.read(runSessionControllerProvider.notifier).isSessionActive}');
          
          // Hook route updates to force map refresh via provider changes
          ref.read(runSessionControllerProvider.notifier).state.onRouteUpdated = (route) {
            setState(() {});
          };
          print('🎯 RunScreen: Background session started for audio and scene management');
        } else {
          print('🎯 RunScreen: Cannot start session - run session manager is not ready');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cannot start session - please try again'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else if (_timerStopped) {
        print('🎯 RunScreen: Timer was stopped - not starting session');
      } else {
        print('🎯 RunScreen: No user target selected, cannot start session');
      }
      
      setState(() {
        _isInitializing = false;
      });
      
      // Start our simple timer
      _startSimpleTimer();
      
    } catch (e) {
      print('Error starting run: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting run: $e')),
        );
      }
    }
  }
  

  
  // Simple function to toggle pause state
  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused; // Toggle pause state
    });
    
    if (_isPaused) {
      print('⏸️ RunScreen: Timer PAUSED at ${_elapsedTime.inSeconds} seconds');
    } else {
      print('▶️ RunScreen: Timer RESUMED from ${_elapsedTime.inSeconds} seconds');
    }
  }

    // Function to pause the timer
  void _pauseTimer() {
    print('⏸️ RunScreen: Pausing timer');
    
    try {
      // Pause our simple timer first (this we can control)
      _pauseSimpleTimer();
      
      // Also pause the background session
      ref.read(runSessionControllerProvider.notifier).pauseSession();
      print('⏸️ RunScreen: Session paused successfully');
      
      // Update UI to show timer is paused
      setState(() {});
      
      // Show confirmation to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timer paused'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('⏸️ RunScreen: Error pausing session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error pausing timer: $e'),
          ),
        );
      }
    }
  }
  
  // Method to resume timer from pause
  void _resumeTimer() async {
    print('🔄 RunScreen: Resuming timer from pause');
    
        // Resume the background session and audio
    try {
      // Resume the background session (this will resume the scene trigger audio)
      ref.read(runSessionControllerProvider.notifier).resumeSession();
      
      // Also directly resume all audio from our audio manager
      final audioManager = ref.read(audioManagerProvider);
      await audioManager.resumeAll();
      
      print('🎵 Audio resumed when timer resumed (session + audio manager)');
    } catch (e) {
      print('❌ Error resuming audio: $e');
    }
    
    // Start our simple timer (it will resume from paused time)
    _startSimpleTimer();
    
    setState(() {
      _isInitializing = false;
    });
    
    print('🔄 RunScreen: Timer resumed from pause');
  }
  
  // _resetTimer method removed - unnecessary complexity

  @override
  Widget build(BuildContext context) {
    final currentEpisode = ref.watch(currentEpisodeProvider);

    // Show loading screen while initializing
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: kMidnightNavy,
        appBar: AppBar(
          title: const Text('Starting Run', style: TextStyle(color: Colors.white)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header skeleton
                SkeletonLoader(height: 32, width: 200, margin: const EdgeInsets.only(bottom: 16)),
                SkeletonLoader(height: 16, width: 150, margin: const EdgeInsets.only(bottom: 32)),
                
                // Stats skeleton
                Row(
                  children: [
                    Expanded(
                      child: SkeletonCard(
                        height: 100,
                        children: [
                          SkeletonLoader(height: 24, width: 60, margin: const EdgeInsets.only(bottom: 8)),
                          SkeletonLoader(height: 32, width: 80, margin: const EdgeInsets.only(bottom: 4)),
                          SkeletonLoader(height: 14, width: 100),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SkeletonCard(
                        height: 100,
                        children: [
                          SkeletonLoader(height: 24, width: 60, margin: const EdgeInsets.only(bottom: 8)),
                          SkeletonLoader(height: 32, width: 80, margin: const EdgeInsets.only(bottom: 4)),
                          SkeletonLoader(height: 14, width: 100),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Map skeleton
                SkeletonCard(
                  height: 200,
                  children: [
                    SkeletonLoader(height: 20, width: 120, margin: const EdgeInsets.only(bottom: 16)),
                    SkeletonLoader(height: 140, width: double.infinity),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Scene skeleton
                SkeletonCard(
                  height: 80,
                  children: [
                    SkeletonLoader(height: 16, width: 100, margin: const EdgeInsets.only(bottom: 8)),
                    SkeletonLoader(height: 20, width: 150, margin: const EdgeInsets.only(bottom: 8)),
                    Row(
                      children: [
                        SkeletonLoader(height: 6, width: 6, margin: const EdgeInsets.only(right: 4)),
                        SkeletonLoader(height: 6, width: 6, margin: const EdgeInsets.only(right: 4)),
                        SkeletonLoader(height: 6, width: 6),
                      ],
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Loading indicator
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(kElectricAqua),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Preparing your adventure...',
                        style: TextStyle(
                          color: kTextHigh,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kMidnightNavy,
      appBar: AppBar(
        title: const Text('Your Run', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      // Scene Notification Overlay removed - no currentSceneProvider available
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Episode Info Card
            if (currentEpisode != null)
              Container(
                margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kSurfaceBase,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.play_circle,
                        color: kElectricAqua,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Current Episode',
                        style: TextStyle(
                          color: kElectricAqua,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentEpisode.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentEpisode.objective,
                    style: TextStyle(
                      fontSize: 14,
                      color: kTextMid,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentEpisode.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Consumer(
                    builder: (context, ref, child) {
                      final userRunTarget = ref.watch(userRunTargetProvider);
                      
                      // Debug logging
                      print('🎯 RunScreen UI: userRunTarget: $userRunTarget');
                      if (userRunTarget != null) {
                        print('🎯 RunScreen UI: Target distance: ${userRunTarget.targetDistance} km');
                        print('🎯 RunScreen UI: Target time: ${userRunTarget.targetTime.inMinutes} min');
                      } else {
                        print('🎯 RunScreen UI: No user target, using episode defaults');
                        print('🎯 RunScreen UI: Episode distance: ${currentEpisode.targetDistance} km');
                        print('🎯 RunScreen UI: Episode time: ${(currentEpisode.targetTime / 60000).toInt()} min');
                      }
                      
                      return Row(
                        children: [
                          // Show distance target only if user selected distance
                          if (userRunTarget != null && userRunTarget.targetDistance > 0)
                            Expanded(
                              child: _buildEpisodeStat(
                                'Target',
                                '${userRunTarget.targetDistance} km',
                                Icons.flag,
                                Colors.orange,
                              ),
                            ),
                          // Show time target only if user selected time
                          if (userRunTarget != null && userRunTarget.targetTime.inMinutes > 0)
                            Expanded(
                              child: _buildEpisodeStat(
                                'Time',
                                '${userRunTarget.targetTime.inMinutes} min',
                                Icons.timer,
                                Colors.blue,
                              ),
                            ),
                          // No fallback to episode defaults - only show user selection
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.audio_file,
                        color: Colors.purple.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Audio Files: ${currentEpisode.audioFiles.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Simple Timer Display
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                       _getTimerDisplayIcon(),
                       color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getTimerDisplayText(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${_elapsedTime.inMinutes}:${(_elapsedTime.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    _isPaused ? 'Paused Time' : 'Elapsed Time',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

          // Run Stats - Now in a scrollable column
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Map panel (Phase C basic) - Fixed height
                const SizedBox(
                  height: 200,
                  child: RunMapPanel(),
                ),
                const SizedBox(height: 16),
                const SceneProgressIndicator(),
                const SizedBox(height: 8),
                const SceneHud(),
                const SizedBox(height: 16),
                  // Scene Progress Indicator
                  Consumer(
                    builder: (context, ref, child) {
                      final currentScene = ref.watch(currentSceneProvider);
                      final playedScenes = ref.watch(playedScenesProvider);
                      final currentProgress = ref.watch(currentRunProgressProvider);
                      
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade50,
                              Colors.blue.shade50,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.theater_comedy,
                                  color: Colors.purple.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Story Progress',
                                  style: TextStyle(
                                    color: Colors.purple.shade600,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Scene Progress Bar
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: currentProgress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.purple.shade400,
                                        Colors.blue.shade400,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Scene Markers
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: SceneType.values.map((scene) {
                                final isPlayed = playedScenes.contains(scene);
                                final isCurrent = currentScene == scene;
                                final triggerPercentage = SceneTriggerService.getSceneTriggerPercentage(scene);
                                
                                return Column(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isPlayed 
                                          ? Colors.green 
                                          : isCurrent 
                                            ? Colors.orange 
                                            : Colors.grey.shade300,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isCurrent ? Colors.orange.shade600 : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: isPlayed 
                                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                                        : isCurrent 
                                          ? const Icon(Icons.play_arrow, color: Colors.white, size: 16)
                                          : null,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(triggerPercentage * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      SceneTriggerService.getSceneTitle(scene).split(' ').first,
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Current Scene Info
                            if (currentScene != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.volume_up,
                                      color: Colors.orange.shade600,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Playing: ${SceneTriggerService.getSceneTitle(currentScene!)}',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),

                  // Stats Grid
                  Consumer(
                    builder: (context, ref, child) {
                      final currentStats = ref.watch(currentRunStatsProvider);
                      final sessionState = ref.watch(currentRunSessionProvider);
                      
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Distance',
                                   '${(currentStats?.distance ?? 0.0).toStringAsFixed(2)} km',
                                  Icons.straighten,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  'Pace',
                                   '${_formatPace(currentStats?.currentPace, currentStats?.distance)} min/km',
                                  Icons.speed,
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Avg Pace',
                                   '${_formatPace(currentStats?.averagePace, currentStats?.distance)} min/km',
                                  Icons.trending_up,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  'Calories',
                                  '${_calculateCalories(currentStats?.distance ?? 0.0).toStringAsFixed(0)} kcal',
                                  Icons.local_fire_department,
                                  Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Control Buttons
                  Center(
                    child: _buildControlButtons(),
                  ),
                  
                  const SizedBox(height: 24), // Bottom padding for safe area
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: color.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getStatusText(RunSessionState state) {
    switch (state) {
      case RunSessionState.inactive:
        return 'Not Started';
      case RunSessionState.running:
        return 'Running';
      case RunSessionState.playingScene:
        return 'Story Playing';
      case RunSessionState.paused:
        return 'Paused';
    }
  }

  Color _getStatusColor(RunSessionState state) {
    switch (state) {
      case RunSessionState.inactive:
        return Colors.grey;
      case RunSessionState.running:
        return Colors.green;
      case RunSessionState.playingScene:
        return Colors.orange;
      case RunSessionState.paused:
        return Colors.orange;
    }
  }

  // Format pace defensively when distance is zero to avoid NaN/inf
  String _formatPace(double? paceMinPerKm, double? distanceKm) {
    if ((distanceKm ?? 0) <= 0 || paceMinPerKm == null || paceMinPerKm.isNaN || paceMinPerKm.isInfinite) {
      return '0.0';
    }
    return paceMinPerKm.toStringAsFixed(1);
  }

  // Estimate calories: MET running 9 km/h ~ 9.8. kcal = MET * 3.5 * weight(kg)/200 * minutes
  // If no user weight, assume 70kg.
  double _calculateCalories(double distanceKm) {
    // Use average pace if available to infer speed; default 9 km/h
    final stats = ref.read(currentRunStatsProvider);
    final minutes = (stats?.elapsedTime.inSeconds ?? 0) / 60.0;
    if (minutes <= 0) return 0;

    final avgPace = stats?.averagePace; // min/km
    double speedKmh;
    if (avgPace != null && avgPace > 0 && avgPace.isFinite) {
      speedKmh = 60.0 / avgPace;
    } else if (distanceKm > 0) {
      speedKmh = distanceKm / (minutes / 60.0);
    } else {
      speedKmh = 9.0;
    }

    // Approximate MET from speed
    double met;
    if (speedKmh < 6) met = 6.0;
    else if (speedKmh < 8) met = 8.3;
    else if (speedKmh < 9.7) met = 9.8;
    else if (speedKmh < 11.3) met = 11.0;
    else met = 12.8;

    // Read user-set weight from settings provider (persisted at sign-in)
    double weightKg = 70.0;
    try {
      weightKg = ref.read(userWeightKgProvider);
    } catch (_) {}

    final kcal = met * 3.5 * weightKg / 200.0 * minutes;
    return kcal;
  }

  void _finishRun() async {
    try {
      print('🎯 RunScreen: Starting run completion process...');
      
      // Get the current run data directly from the run session manager
      final runSessionManager = ref.read(runSessionControllerProvider.notifier);
      
      // USE THE BUILT-IN createRunModel() METHOD INSTEAD OF MANUAL DATA EXTRACTION
      print('💾 RunScreen: Using createRunModel() method for data capture...');
      
      // Create the run model using the service's built-in method
      // Access the underlying RunSessionManager through the controller's state
      final runModel = runSessionManager.state.createRunModel();
      
      print('💾 RunScreen: Run model created with ${runModel.route.length} GPS points');
      print('💾 RunScreen: Distance: ${runModel.totalDistance}km, Time: ${runModel.totalTime}');
      
      // SAVE THE RUN TO DATABASE FIRST - SIMPLE AND DIRECT
      if (runModel.route.isNotEmpty) {
        print('💾 RunScreen: Saving run to database...');
        try {
          // Save to database directly
          final firestore = FirestoreService();
          final runId = await firestore.saveRun(runModel);
          await firestore.completeRun(runId, runModel);
          print('✅ RunScreen: Run saved to database with ID: $runId');
          print('✅ RunScreen: ${runModel.route.length} GPS points saved');
        } catch (e) {
          print('❌ RunScreen: Error saving run to database: $e');
        }
      } else {
        print('⚠️ RunScreen: No GPS route data to save');
      }
      
      // NOW stop everything AFTER saving the data
      print('🛑 RunScreen: Stopping session and cleanup...');
      
      // Stop the simple timer
      _timerStopped = true;
      _stopSimpleTimer();
      print('🛑 Simple timer stopped completely');
      
      // Stop audio
      final audioManager = ref.read(audioManagerProvider);
      audioManager.stopAll();
      print('🎵 Audio stopped when run finished');
      
      // Stop the run session
      try {
        await runSessionManager.stopSession();
        print('🛑 RunSessionManager: Session stopped');
      } catch (e) {
        print('⚠️ RunScreen: Error stopping session: $e');
      }
      
      // Navigate to summary screen
      if (mounted) {
        context.go('/run/summary');
      }
      
    } catch (e) {
      print('❌ RunScreen: Error in _finishRun: $e');
      // Navigate to summary anyway
      if (mounted) {
        context.go('/run/summary');
      }
    }
  }
  
  /// Show user-friendly error dialog
  void _showErrorDialog(String title, String message, {bool showRetry = false, VoidCallback? onRetry}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceBase,
        title: Text(
          title,
          style: TextStyle(
            color: kTextHigh,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(color: kTextMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: kElectricAqua),
            ),
          ),
          if (showRetry && onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text(
                'Retry',
                style: TextStyle(color: kMeadowGreen),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Convert technical error messages to user-friendly ones
  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Please check your internet connection and try again.';
    } else if (errorString.contains('permission') || errorString.contains('access')) {
      return 'Please check your app permissions.';
    } else if (errorString.contains('not found') || errorString.contains('missing')) {
      return 'The requested content could not be found. Please try again.';
    } else if (errorString.contains('timeout')) {
      return 'The operation took too long. Please try again.';
    } else if (errorString.contains('invalid') || errorString.contains('malformed')) {
      return 'Invalid data received. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
}
