import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/story_providers.dart';
import '../../../shared/providers/settings_providers.dart';
import '../../../shared/providers/run_providers.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/providers/run_session_providers.dart';
import '../../../shared/models/run_target_model.dart';
import '../../../shared/models/episode_model.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import '../../run/widgets/run_target_sheet.dart';
import '../../../shared/services/audio/download_service.dart';
import '../../../shared/services/firebase/firebase_storage_service.dart';
import '../../../core/constants/app_theme.dart';

class EpisodeDetailScreen extends ConsumerStatefulWidget {
  final String episodeId;
  const EpisodeDetailScreen({super.key, required this.episodeId});

  @override
  ConsumerState<EpisodeDetailScreen> createState() => _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends ConsumerState<EpisodeDetailScreen> {
  bool _downloading = false;
  double _progress = 0;
  bool _cached = false;

  @override
  void initState() {
    super.initState();
    // On web we stream assets; no on-device caching required
    if (kIsWeb) {
      _cached = true;
    }
    
    // Set sensible defaults for all options
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setDefaults();
      _checkDownloadStatus();
    });
  }
  
  Future<void> _checkDownloadStatus() async {
    if (kIsWeb) return;
    
    try {
      final service = DownloadService();
      
      // Get episode data to check what audio files are expected
      final episodeAsync = ref.read(episodeByIdProvider(widget.episodeId));
      await episodeAsync.when(
        data: (episode) async {
          if (episode == null) {
            // Episode not found, use original check
            final isDownloaded = await service.isEpisodeDownloaded(widget.episodeId);
            if (mounted) {
              setState(() {
                _cached = isDownloaded;
              });
            }
            return;
          }
          
          bool isDownloaded = false;
          
          // Check if episode uses multiple audio files
          if (episode.audioFiles.isNotEmpty) {
            isDownloaded = await service.isEpisodeProperlyDownloaded(widget.episodeId, episode.audioFiles);
          } else if (episode.audioFile != null && episode.audioFile!.isNotEmpty) {
            // For single file mode, use the original check
            isDownloaded = await service.isEpisodeDownloaded(widget.episodeId);
          }
          
          if (mounted) {
            setState(() {
              _cached = isDownloaded;
            });
          }
        },
        loading: () async {
          // While loading, use the original check
          final isDownloaded = await service.isEpisodeDownloaded(widget.episodeId);
          if (mounted) {
            setState(() {
              _cached = isDownloaded;
            });
          }
        },
        error: (error, stack) async {
          // On error, use the original check
          final isDownloaded = await service.isEpisodeDownloaded(widget.episodeId);
          if (mounted) {
            setState(() {
              _cached = isDownloaded;
            });
          }
        },
      );
    } catch (e) {
      print('Error checking download status: $e');
    }
  }

  void _setDefaults() {
    // Set default run target if none selected
    if (ref.read(selectedRunTargetProvider) == null) {
      ref.read(selectedRunTargetProvider.notifier).state = RunTarget.predefinedTargets.first;
    }
    
    // Set default tracking mode if none selected
    if (ref.read(trackingModeProvider) == null) {
      ref.read(trackingModeProvider.notifier).state = TrackingMode.gps;
    }
    
    // Set default sprint intensity if none selected
    if (ref.read(sprintIntensityProvider) == null) {
      ref.read(sprintIntensityProvider.notifier).state = SprintIntensity.off;
    }
    
    // Set default music source if none selected
    if (ref.read(musicSourceProvider) == null) {
      ref.read(musicSourceProvider.notifier).state = MusicSource.external;
    }
  }

  Future<void> _downloadEpisodeFromFirebase(EpisodeModel episode) async {
    setState(() { _downloading = true; _progress = 0; });
    
    try {
      final service = DownloadService();
      
      // Check if this episode uses single audio file mode
      if (episode.audioFile != null && episode.audioFile!.isNotEmpty) {
        // Single audio file mode - download the single file
        print('🎵 Downloading single audio file: ${episode.audioFile}');
        
        final result = await service.downloadSingleAudioFile(
          widget.episodeId,
          episode.audioFile!,
          onProgress: (progress) {
            if (mounted) {
              setState(() { _progress = progress; });
            }
          },
        );
        
        setState(() { 
          _downloading = false; 
          _cached = result.success; 
          _progress = result.success ? 1 : 0; 
        });
        
        if (!mounted) return;
        
        final snack = SnackBar(
          content: Text(
            result.success ? 'Episode downloaded successfully!' : 'Download failed: ${result.error}'
          ),
          backgroundColor: result.success ? kMeadowGreen : kEmberCoral,
          duration: const Duration(seconds: 5),
          action: result.success ? null : SnackBarAction(
            label: 'Help',
            textColor: Colors.white,
            onPressed: () {
              _showDownloadHelpDialog(context);
            },
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(snack);
        return;
      }
      
      // Multiple audio files mode (legacy) - download individual scene files
      print('🎵 Downloading multiple audio files: ${episode.audioFiles.length} files');
      
      // Extract file names from the audio file paths
      final fileNames = episode.audioFiles.map((path) {
        // Handle both asset paths and Firebase URLs
        if (path.startsWith('assets/')) {
          return path.split('/').last;
        } else {
          // Already a Firebase URL, extract filename
          return FirebaseStorageService.getFileNameFromUrl(path);
        }
      }).toList();
      
      // Use the database method to handle gs:// URLs
      final result = await service.downloadEpisodeFromDatabase(
        widget.episodeId, 
        episode.audioFiles,
        onProgress: (progress) {
          if (mounted) {
            setState(() { _progress = progress; });
          }
        },
      );
      
      setState(() { 
        _downloading = false; 
        _cached = result.success; 
        _progress = result.success ? 1 : 0; 
      });
      
      if (!mounted) return;
      
      final snack = SnackBar(
        content: Text(
          result.success ? 'Episode downloaded successfully!' : 'Download failed: ${result.error}'
        ),
        backgroundColor: result.success ? kMeadowGreen : kEmberCoral,
        duration: const Duration(seconds: 5),
        action: result.success ? null : SnackBarAction(
          label: 'Help',
          textColor: Colors.white,
          onPressed: () {
            _showDownloadHelpDialog(context);
          },
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(snack);
      
    } catch (e) {
      setState(() { _downloading = false; _progress = 0; });
      if (!mounted) return;
      
      final snack = SnackBar(
        content: Text('Download error: $e'),
        backgroundColor: kEmberCoral,
      );
      ScaffoldMessenger.of(context).showSnackBar(snack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final episodeAsync = ref.watch(episodeByIdProvider(widget.episodeId));
    final unit = ref.watch(unitSystemProvider);
    final sprint = ref.watch(sprintIntensityProvider);
    final tracking = ref.watch(trackingModeProvider);
    final music = ref.watch(musicSourceProvider);
    final weightKg = ref.watch(userWeightKgProvider);
    final selectedTarget = ref.watch(selectedRunTargetProvider);

    return Scaffold(
      backgroundColor: kMidnightNavy,
      appBar: AppBar(
        title: const Text('Episode', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: episodeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: kElectricAqua)),
        error: (e, st) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
        data: (episode) {
          if (episode == null) {
            return const Center(child: Text('Episode not found', style: TextStyle(color: Colors.white)));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Episode title and description
                Text(
                  episode.title, 
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  episode.description, 
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kTextMid,
                  ),
                ),
                const SizedBox(height: 24),

                // Listen Again section - show scenes based on episode type
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kSurfaceBase,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kElectricAqua.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Listen Again', style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (episode.audioFile != null && episode.audioFile!.isNotEmpty && episode.sceneTimestamps != null) ...[
                        // Single audio file mode - show scenes with timestamps
                        ...List.generate(episode.sceneTimestamps!.length, (i) {
                          final sceneData = episode.sceneTimestamps![i];
                          final sceneName = sceneData['scene'] ?? 'Scene ${i + 1}';
                          final startTime = sceneData['start'] ?? '0:00';
                          final endTime = sceneData['end'] ?? '0:00';
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: kElectricAqua.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: kElectricAqua.withOpacity(0.4)),
                                  ),
                                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    sceneName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('$startTime-$endTime', style: TextStyle(color: kTextMid, fontSize: 12)),
                              ],
                            ),
                          );
                        }),
                      ] else ...[
                        // Multiple audio files mode (legacy) - show individual file names
                        ...List.generate(episode.audioFiles.length, (i) {
                          final label = episode.audioFiles[i].split('/').last.replaceAll('_', ' ');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: kElectricAqua.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: kElectricAqua.withOpacity(0.4)),
                                  ),
                                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('—', style: TextStyle(color: kTextMid)),
                              ],
                            ),
                          );
                        }),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Start button first, options will be pinned at bottom
                
                // Download section (mobile only) - Firebase audio downloads
                if (!_cached && !kIsWeb) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kElectricAqua.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kElectricAqua.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.download, color: kElectricAqua, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Download Episode Audio',
                              style: TextStyle(
                                color: kElectricAqua,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Download audio files to listen offline during your run',
                          style: TextStyle(
                            color: kTextMid,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _downloading ? null : () => _downloadEpisodeFromFirebase(episode),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kElectricAqua,
                            foregroundColor: kMidnightNavy,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_downloading) ...[
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(kMidnightNavy),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('Downloading ${(_progress * 100).toInt()}%'),
                              ] else ...[
                                Icon(Icons.download, size: 18),
                                const SizedBox(width: 8),
                                Text('Download Episode'),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Web preview message
                if (kIsWeb) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kElectricAqua.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kElectricAqua.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Web preview: audio streams from assets; no download needed.',
                      style: TextStyle(color: kElectricAqua),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Start Workout button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (selectedTarget != null && (_cached || kIsWeb))
                      ? () {
                          final target = selectedTarget;
                          if (target != null) {
                            final selection = RunTargetSelection(
                              targetDistance: target.type == RunTargetType.distance ? target.value : 0.0,
                              targetTime: target.type == RunTargetType.time ? Duration(minutes: target.value.toInt()) : Duration.zero,
                            );
                            ref.read(userRunTargetProvider.notifier).setRunTarget(selection);
                            
                            // Navigate to run screen with episode ID as parameter
                            context.go('/run?episodeId=${widget.episodeId}');
                          }
                        }
                      : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kElectricAqua,
                      foregroundColor: kMidnightNavy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Start Workout',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: kMidnightNavy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quick weight setting (temporary inline control)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kSurfaceBase,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kElectricAqua.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monitor_weight, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Weight: ${weightKg.toStringAsFixed(0)} kg',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final newValue = await showDialog<double>(
                            context: context,
                            builder: (ctx) {
                              double temp = weightKg;
                              return AlertDialog(
                                backgroundColor: kSurfaceBase,
                                title: const Text('Set Weight (kg)', style: TextStyle(color: Colors.white)),
                                content: StatefulBuilder(
                                  builder: (ctx, setState) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Slider(
                                        min: 40,
                                        max: 130,
                                        divisions: 90,
                                        value: temp,
                                        onChanged: (v) => setState(() => temp = v),
                                      ),
                                      Text('${temp.toStringAsFixed(0)} kg', style: const TextStyle(color: Colors.white70)),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, temp), child: const Text('Save')),
                                ],
                              );
                            },
                          );
                          if (newValue != null) {
                            ref.read(userWeightKgProvider.notifier).state = newValue;
                            // Persist to Firestore (best-effort)
                            try {
                              final auth = ref.read(authServiceProvider);
                              await auth.setUserWeightKg(newValue);
                            } catch (_) {}
                          }
                        },
                        icon: const Icon(Icons.edit, color: Colors.white70),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Run parameter tiles at the bottom
                _tile(
                  context,
                  'Tracking',
                  subtitle: tracking == TrackingMode.gps ? 'GPS (default)' : tracking.name,
                  icon: Icons.explore,
                  onTap: _showTrackingSheet,
                ),
                const SizedBox(height: 12),
                _tile(context, 'Sprints', subtitle: sprint.name, icon: Icons.bolt, onTap: _showSprintsSheet),
                const SizedBox(height: 12),
                _tile(context, 'Music', subtitle: music.name, icon: Icons.music_note, onTap: _showMusicSheet),
                const SizedBox(height: 12),
                _tile(context, 'Duration', subtitle: selectedTarget?.displayName ?? 'Select duration', icon: Icons.timer, onTap: (){
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: kSurfaceBase,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => const RunTargetSheet(),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, String title, {required String subtitle, required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurfaceBase,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kElectricAqua.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: kElectricAqua, size: 24),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle, 
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kTextMid,
                  ),
                ),
              ],
            )),
            Icon(Icons.chevron_right, color: kElectricAqua),
          ],
        ),
      ),
    );
  }

  Widget _downloadPill(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kMeadowGreen.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kMeadowGreen.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.download_done, color: kMeadowGreen),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: _cached ? 1 : (_downloading ? _progress : 0),
              minHeight: 8,
              backgroundColor: kMeadowGreen.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(kMeadowGreen),
            ),
          ),
        ],
      ),
    );
  }

  // --- sheets ---
  void _showTrackingSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final current = ref.read(trackingModeProvider);
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kTextMid.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tracking Mode',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how to track your run',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kTextMid,
                ),
              ),
              const SizedBox(height: 16),
              for (final mode in TrackingMode.values)
                RadioListTile<TrackingMode>(
                  value: mode,
                  groupValue: current,
                  title: Text(
                    mode.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  activeColor: kElectricAqua,
                  onChanged: (v) { 
                    if (v!=null) { 
                      ref.read(trackingModeProvider.notifier).state = v; 
                      Navigator.pop(ctx); 
                    } 
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showSprintsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final current = ref.read(sprintIntensityProvider);
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kTextMid.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sprint Intensity',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set your sprint intensity level',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kTextMid,
                ),
              ),
              const SizedBox(height: 16),
              for (final s in SprintIntensity.values)
                RadioListTile<SprintIntensity>(
                  value: s,
                  groupValue: current,
                  title: Text(
                    s.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  activeColor: kElectricAqua,
                  onChanged: (v) { 
                    if (v!=null) { 
                      ref.read(sprintIntensityProvider.notifier).state = v; 
                      Navigator.pop(ctx); 
                    } 
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showMusicSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final current = ref.read(musicSourceProvider);
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kTextMid.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Music Source',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'External music will duck during scenes',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kTextMid,
                ),
              ),
              const SizedBox(height: 16),
              for (final m in MusicSource.values)
                RadioListTile<MusicSource>(
                  value: m,
                  groupValue: current,
                  title: Text(
                    m.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  activeColor: kElectricAqua,
                  onChanged: (v) { 
                    if (v!=null) { 
                      ref.read(musicSourceProvider.notifier).state = v; 
                      Navigator.pop(ctx); 
                    } 
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
  
  void _showDownloadHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceBase,
        title: const Text(
          'Download Help',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'The download failed because:\n\n'
          '1. Firebase Storage security rules are blocking access\n'
          '2. Audio files may not be uploaded yet\n'
          '3. Network connectivity issues\n\n'
          'Please check your Firebase Storage configuration.',
          style: TextStyle(color: kTextMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: kElectricAqua)),
          ),
        ],
      ),
    );
  }
}


