import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../../shared/providers/run_session_providers.dart';
import '../../../shared/providers/story_providers.dart';
import '../../../shared/providers/run_providers.dart';
import '../../../shared/providers/run_config_providers.dart';
import '../../../shared/models/run_enums.dart';
import '../../../shared/models/run_target_model.dart';

import '../../../shared/providers/audio_providers.dart';
import '../../../shared/services/settings/settings_service.dart';
import '../../../shared/services/run/run_session_manager.dart';
import '../../../shared/services/background_service_manager.dart';


import '../../../shared/models/episode_model.dart';
import '../../../core/constants/app_theme.dart';
import 'dart:async';
import 'dart:io';
import '../widgets/run_map_panel.dart';
import '../../../shared/widgets/ui/skeleton_loader.dart';
import '../../../shared/services/run/run_completion_service.dart';
import '../../../shared/services/run/step_detection_service.dart';
import '../../../shared/providers/run_completion_providers.dart';
import '../../../shared/services/background_service_manager.dart';






class RunScreen extends ConsumerStatefulWidget {
  const RunScreen({super.key});

  @override
  ConsumerState<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends ConsumerState<RunScreen> with WidgetsBindingObserver {
  bool _isInitializing = true;
  bool _timerStopped = false; // Flag to prevent timer restart
  bool _disposed = false; 
  
  // Error handling and user feedback
  bool _isLoading = false;
  String? _currentErrorMessage;
  bool _showErrorToast = false;
  Timer? _errorToastTimer;
  
  @override
  void initState() {
    super.initState();
    _isInitializing = true;
    
    // Start the run session automatically when screen loads
    // User already selected "Start Run" on home screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRun();
    });
    
    // Listen for app lifecycle changes to handle background processing
    WidgetsBinding.instance.addObserver(this);
  }
  
  /// Get episode ID from query parameters
  String? _getEpisodeIdFromQuery() {
    final uri = Uri.parse(GoRouterState.of(context).uri.toString());
    return uri.queryParameters['episodeId'];
  }
  

  
  @override
  void dispose() {
    try {
      _clearServiceCallbacks();
      _disposed = true;
      _errorToastTimer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
      
    } catch (e) {
      // Log error but don't let it prevent disposal
    } finally {
      super.dispose();
    }
  }
  
  // App lifecycle management for background processing
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.inactive:
        _onAppInactive();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.hidden:
        _onAppHidden();
        break;
    }
  }
  
  /// Handle app resumed (brought to foreground)
  void _onAppResumed() {
    if (_disposed) return;
    // The RunSessionManager handles its own lifecycle on resume.
    // We just need to ensure the UI reflects the current state.
    ref.read(runSessionControllerProvider.notifier).resumeSession();
    
    // Update UI to reflect current state
    if (mounted) {
      setState(() {});
    }
  }
  
  /// Handle app inactive (transitioning between states)
  void _onAppInactive() {
    if (_disposed) return;
    
    // Keep everything running during transitions
  }
  
  /// Handle app paused (minimized/background)
  void _onAppPaused() {
    if (_disposed) return;
    // The RunSessionManager will handle backgrounding logic, including
    // starting background services if needed.
    ref.read(runSessionControllerProvider.notifier).pauseSession();
  }
  
  /// Handle app detached (about to be terminated)
  void _onAppDetached() {
    if (_disposed) return;
    
    
    // The RunSessionManager should handle persisting state if necessary.
    ref.read(runSessionControllerProvider.notifier).pauseSession();
  }
  
  /// Handle app hidden (Android specific)
  void _onAppHidden() {
    if (_disposed) return;
    
    // Similar to paused - keep everything running
  }
  
  /// Get pace zone based on current pace
  String _getPaceZone(double pace) {
    if (pace <= 4.0) return 'very_hard';
    if (pace <= 5.0) return 'hard';
    if (pace <= 6.0) return 'moderate';
    if (pace <= 7.0) return 'easy';
    return 'very_easy';
  }
  
  /// Get pace zone color
  Color _getPaceZoneColor(String zone) {
    switch (zone) {
      case 'very_hard':
        return Colors.red;
      case 'hard':
        return Colors.orange;
      case 'moderate':
        return Colors.yellow.shade700;
      case 'easy':
        return Colors.green;
      case 'very_easy':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  /// Get pace zone description
  String _getPaceZoneDescription(String zone) {
    switch (zone) {
      case 'very_hard':
        return 'Very Hard';
      case 'hard':
        return 'Hard';
      case 'moderate':
        return 'Moderate';
      case 'easy':
        return 'Easy';
      case 'very_easy':
        return 'Very Easy';
      default:
        return 'Unknown';
    }
  }
  
  /// Get pace zone icon
  IconData _getPaceZoneIcon(String zone) {
    switch (zone) {
      case 'very_hard':
        return Icons.fitness_center;
      case 'hard':
        return Icons.directions_run;
      case 'moderate':
        return Icons.directions_walk;
      case 'easy':
        return Icons.emoji_emotions;
      case 'very_easy':
        return Icons.airline_seat_flat;
      default:
        return Icons.help_outline;
    }
  }
  
  /// Show toast notification
  void _showToast(String message, {bool isError = false, Duration duration = const Duration(seconds: 3)}) {
    _currentErrorMessage = message;
    _showErrorToast = true;
    
    // Auto-hide toast after duration
    _errorToastTimer?.cancel();
    _errorToastTimer = Timer(duration, () {
      if (mounted && !_disposed) {
        setState(() {
          _showErrorToast = false;
          _currentErrorMessage = null;
        });
      }
    });
    
    // Update UI immediately
    if (mounted && !_disposed) {
      setState(() {});
    }
    
  }
  
  /// Start listening to updates from ProgressMonitorService
  void _startListeningToServiceUpdates() {
    // Get the run session manager to access ProgressMonitorService
    final runSessionManager = ref.read(runSessionControllerProvider.notifier);
    
    // Listen for time updates from the service
    // This will be called every second by ProgressMonitorService
    runSessionManager.onTimeUpdated = (Duration elapsedTime) {
      if (_disposed || !mounted) return;

      // Update UI if mounted
      if (mounted) {
        // This setState is an anti-pattern. The UI should rebuild based on watching providers.
        // However, we'll keep it for now to ensure UI updates, and remove it in a future pass.
        setState(() {});
      }
    };
    
  }
  
  /// Stop ALL timers and services - comprehensive cleanup for hot reload
  void _stopAllTimersAndServices() {
    print('🛑 RunScreen: Starting comprehensive timer cleanup...');
    
    // Set all flags to stop state IMMEDIATELY
    _disposed = true;
    _timerStopped = true;
    
    if (_errorToastTimer != null) {
      _errorToastTimer!.cancel();
      _errorToastTimer = null;
      print('🛑 RunScreen: _errorToastTimer stopped');
    }
    
    // Clear service callbacks
    _clearServiceCallbacks();
    
    print('🛑 RunScreen: All timers and services stopped successfully');
  }

  /// Clear all callbacks to prevent further updates from services
  void _clearServiceCallbacks() {
    try {
      // Check if widget is disposed or not mounted before accessing ref
      if (_disposed || !mounted) {
        return;
      }
      
      final runSessionController = ref.read(runSessionControllerProvider.notifier);
      
      // Clear the onTimeUpdated callback through the controller's setter
      runSessionController.onTimeUpdated = null;
      
      // Force stop all services to prevent them from continuing to run
      runSessionController.nuclearStop();
      
    } catch (e) {
    }
  }
  
  // Note: _saveRunCompletion method removed to prevent duplicate run saving
  // Run completion is now handled by RunCompletionService
  
  /// Build the control buttons based on timer state
  Widget _buildControlButtons() {
    final sessionState = ref.watch(currentRunSessionProvider);
    final bool isPaused = sessionState == RunSessionState.paused;

    final Color primaryColor = isPaused ? Colors.green : Colors.orange;
    final IconData primaryIcon = isPaused ? Icons.play_arrow : Icons.pause;
    final String primaryLabel = isPaused ? 'Resume' : 'Pause';
    final VoidCallback primaryAction = isPaused ? _resumeTimer : _pauseTimer;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: primaryAction,
            icon: Icon(primaryIcon),
            label: Text(primaryLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              print('🚨 BUTTON CLICKED: Finish Run button pressed!');
              _finishRun();
            },
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
  
  Future<bool> _ensureLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
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
      return false;
    }
  }

  void _startRun() async {
    // Read tracking mode to decide if GPS permission is needed
    final selectedMode = ref.read(trackingModeProvider) ?? TrackingMode.gps;
    if (selectedMode == TrackingMode.gps) {
      // Ensure GPS permission and service availability
      final permitted = await _ensureLocationPermission();
      if (!permitted) {
        setState(() {
          _isInitializing = false;
        });
        return;
      }
    }
    
    // Don't start if timer was explicitly stopped
    if (_timerStopped) {
      setState(() {
        _isInitializing = false;
      });
      return;
    }
    
    // Don't start if there's already an active session
    final isSessionActive = ref.read(runSessionControllerProvider.notifier).isSessionActive;
    if (isSessionActive) {
      setState(() {
        _isInitializing = false;
      });
      return;
    }
    
    // Debug: Check what target data is available
    final userRunTarget = ref.read(userRunTargetProvider);
    
    if (userRunTarget != null) {
      if (userRunTarget.targetDistance > 0) {
      } else if (userRunTarget.targetTime.inMinutes > 0) {
      }
    } else {
    }
    
    // Get episode ID from query parameters and load episode data
    final episodeId = _getEpisodeIdFromQuery();
    
    EpisodeModel? currentEpisode;
    if (episodeId != null) {
      // Load episode data directly from the story service
      try {
        final episodeAsync = ref.read(episodeByIdProvider(episodeId));
        episodeAsync.whenData((episode) {
          if (episode != null) {
            currentEpisode = episode;
          }
        });
      } catch (e) {
      }
    }
    
    // If no episode loaded, create a fallback episode with audio files
    if (currentEpisode == null) {
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
          // Audio files should come from episode data, not hardcoded
        ],
        requirements: {},
        rewards: {},
      );
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
        } else if (userRunTarget.targetTime.inMinutes > 0) {
          // User selected time target
          targetTime = userRunTarget.targetTime;
          targetDistance = null; // No distance target - user only selected time
        } else {
        }
      }
      // No fallback to database - only show user selection
      
      
      // Only start if user has selected a target AND timer wasn't stopped
      if ((targetTime != null || targetDistance != null) && !_timerStopped) {
        // Check if the run session manager can start a session
        final canStart = ref.read(runSessionControllerProvider.notifier).canStartSession();
        if (canStart) {
          final trackingMode = selectedMode;
          // Force debug logging for testing
          
          
          // Set up time update callback BEFORE starting the session
          // This ensures we don't miss any time updates
          _startListeningToServiceUpdates();
          
          await ref.read(runSessionControllerProvider.notifier).startSession(
            currentEpisode!,
            userTargetTime: targetTime ?? const Duration(minutes: 30),
            userTargetDistance: targetDistance ?? 5.0,
            trackingMode: trackingMode,
          );
          
          // Hook route updates to force map refresh via provider changes
          ref.read(runSessionControllerProvider.notifier).state.onRouteUpdated = (route) {
            setState(() {});
          };
        } else {
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
      } else {
      }
      
      setState(() {
        _isInitializing = false;
      });
      
      // Note: Timer callback is now set up before starting the session
      // No need to call _startSimpleTimer() here
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting run: $e')),
        );
      }
    }
  }
  

  
  void _pauseTimer() {
    
    try {
      // Also pause the background session
      ref.read(runSessionControllerProvider.notifier).pauseSession();
      
      // Update UI to show timer is paused
      if (mounted) setState(() {});
      
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
    
    // Resume the background session and audio
    try {
      // Resume the background session (this will resume the scene trigger audio)
      ref.read(runSessionControllerProvider.notifier).resumeSession();
      
      // Also directly resume all audio from our audio manager
      final audioManager = ref.read(audioManagerProvider);
      await audioManager.resumeAll();
      
    } catch (e) {
    }
    
    // The UI will update automatically by watching the providers.
    // We might call setState just to be sure if parts of the UI are not consumers.
    if (mounted && !_disposed) {
      setState(() {
        _isInitializing = false;
      });
    }
    
  }
  
  // _resetTimer method removed - unnecessary complexity

  @override
  Widget build(BuildContext context) {
    final currentEpisode = ref.watch(currentEpisodeProvider);
    final stats = ref.watch(currentRunStatsProvider);

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

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Compact metrics header (ZRX-style)
            _buildCompactHeader(currentEpisode),

            // Expanded map fills the remaining space
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: RunMapPanel(expanded: true),
              ),
            ),

            // Bottom controls bar
            _buildBottomControlsBar(),
          ],
        ),
      ),
    );
  }

  /// Compact top header with distance/time/pace and subtle progress
  Widget _buildCompactHeader(EpisodeModel? episode) {
    final theme = Theme.of(context);
    final elapsedTime = ref.watch(currentRunStatsProvider)?.elapsedTime ?? Duration.zero;
    final stats = ref.watch(currentRunStatsProvider);
    final progress = ref.watch(currentRunProgressProvider);

    final title = episode?.title ?? 'Your Run';
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;

    return Container(
      padding: const EdgeInsets.only(top: 44, left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primary.withOpacity(0.22),
            surface.withOpacity(0.10),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top row: title + close
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                color: theme.colorScheme.onSurface,
                onPressed: () => context.pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Thin progress bar under title
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.dividerColor.withOpacity(0.4),
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
          const SizedBox(height: 12),
          // Big distance centered
          FutureBuilder<String>(
            future: _formatDistanceWithUnits(stats?.distance ?? 0.0),
            builder: (context, snapshot) {
              return Column(
                children: [
                  Text(
                    snapshot.data ?? (stats?.distance ?? 0.0).toStringAsFixed(2),
                    style: theme.textTheme.headlineLarge?.copyWith(fontSize: 44),
                  ),
                  Text('Distance', style: theme.textTheme.labelMedium),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // Time and pace row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text(
                    '${(stats?.elapsedTime ?? Duration.zero).inMinutes}:${((stats?.elapsedTime ?? Duration.zero).inSeconds % 60).toString().padLeft(2, '0')}',
                    style: theme.textTheme.headlineSmall,
                  ),
                  Text('Time', style: theme.textTheme.labelMedium),
                ],
              ),
              Column(
                children: [
                  FutureBuilder<String>(
                    future: _formatPaceWithUnits(stats?.averagePace ?? 0.0),
                    builder: (context, snapshot) => Text(
                      snapshot.data ?? _formatPace(stats?.averagePace, stats?.distance),
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  Text('Pace', style: theme.textTheme.labelMedium),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bottom controls styled as a compact sticky bar
  Widget _buildBottomControlsBar() {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.9),
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: _buildControlButtons(),
      ),
    );
  }

  Widget _buildStatCard(String title, dynamic value, IconData icon, Color color) {
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
          if (value is String)
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            )
          else if (value is Widget)
            value
          else
            Text(
              value.toString(),
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





  // Format pace defensively when distance is zero to avoid NaN/inf
  String _formatPace(double? paceMinPerKm, double? distanceKm) {
    if ((distanceKm ?? 0) <= 0 || paceMinPerKm == null || paceMinPerKm.isNaN || paceMinPerKm.isInfinite) {
      return '0.0';
    }
    return paceMinPerKm.toStringAsFixed(1);
  }

  // Format speed in km/h based on distance and time
  String _formatSpeed(double? distanceKm, Duration? elapsedTime) {
    if ((distanceKm ?? 0) <= 0 || elapsedTime == null || elapsedTime.inSeconds <= 0) {
      return '0.0';
    }
    final hours = elapsedTime.inSeconds / 3600.0;
    final speedKmh = distanceKm! / hours;
    return speedKmh.toStringAsFixed(1);
  }

  // Format distance with units using settings service
  Future<String> _formatDistanceWithUnits(double distanceInKm) async {
    final settingsService = SettingsService();
    return await settingsService.formatDistance(distanceInKm);
  }

  // Format speed with units using settings service
  Future<String> _formatSpeedWithUnits(double speedInKmh) async {
    final settingsService = SettingsService();
    return await settingsService.formatSpeed(speedInKmh);
  }

  // Format pace with units using settings service
  Future<String> _formatPaceWithUnits(double paceInMinPerKm) async {
    final settingsService = SettingsService();
    return await settingsService.formatPace(paceInMinPerKm);
  }

  // Format energy with units using settings service
  Future<String> _formatEnergyWithUnits(double energyInKcal) async {
    final settingsService = SettingsService();
    return await settingsService.formatEnergy(energyInKcal);
  }

  void _finishRun() async {
  print('🚨 RunScreen: _finishRun() method called!');

  // Set up loading state for UI
  setState(() {
    _isLoading = true; // You can add a loading indicator to the UI
  });

  try {
    // 1. Get the final, complete GPS data and stats from the session manager BEFORE stopping it.
    final runSessionManager = ref.read(runSessionControllerProvider);
    final gpsPositions = runSessionManager.progressMonitor.route;
    final managerStats = ref.read(runSessionControllerProvider.notifier).getCurrentStats();
    
    // 2. Now that we have the data, stop all services.
    try {
      _stopAllTimersAndServices();
      ref.read(runSessionControllerProvider.notifier).nuclearStop();
      _clearServiceCallbacks();
    } catch (e) {
      print('❌ RunScreen: Error stopping services during finish flow: $e');
    }

    // Check if there is any data to save
    if (gpsPositions.isEmpty) {
      print('⚠️ RunScreen: No GPS data to save. Navigating to summary.');
      _showToast('No run data to save.', isError: true);
      if (mounted) {
        context.go('/run/summary');
      }
      return;
    }
    
    print('📍 RunScreen: Finalizing run with ${gpsPositions.length} GPS points');
    
    // 3. Use the dedicated RunCompletionService to handle all saving logic
    final runCompletionService = RunCompletionService(ProviderScope.containerOf(context));
    
    // Pass the captured data to the service
    final summaryData = await runCompletionService.completeRunWithData(
      gpsPositions,
      duration: managerStats?.elapsedTime ?? Duration.zero, // No fallback to local state
      distance: managerStats?.distance ?? 0.0, // No fallback to local state
      episodeId: _getEpisodeIdFromQuery() ?? 'unknown',
    );

    // 4. Wait for the service to complete successfully
    if (summaryData != null) {
      print('✅ RunScreen: Run completed successfully and saved!');
      _showToast('Run saved successfully!', isError: false);
      
      // 4. Navigate to the summary screen with the summary data
      if (mounted) {
        // You might want to pass the summary data to the next screen for display
        context.go('/run/summary', extra: summaryData);
      }
    } else {
      // Handle the case where the service returns null, indicating a failure
      print('❌ RunScreen: Run completion failed. Summary data is null.');
      _showToast('Error saving run data. Try again later.', isError: true);
      
      // Navigate to summary anyway, but let the user know something went wrong
      if (mounted) {
        context.go('/run/summary');
      }
    }
    
  } catch (e) {
    print('❌ RunScreen: Unhandled error in _finishRun: $e');
    _showToast('An unexpected error occurred. Data might not be saved.', isError: true);
    
    if (mounted) {
      context.go('/run/summary');
    }
  } finally {
    // Hide the loading indicator
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
}
