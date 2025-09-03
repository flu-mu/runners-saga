import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart';
import 'dart:io';
import 'dart:math';
import '../../../shared/providers/auth_providers.dart';
import '../../../shared/services/firebase/firestore_service.dart';
import '../../../shared/models/run_model.dart';
import '../../../shared/widgets/navigation/bottom_navigation_widget.dart';
import '../../../shared/providers/settings_providers.dart';
import '../../../shared/services/settings/settings_service.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/themes/theme_selector_widget.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isImporting = false;
  String? _selectedFileName;
  double? _importedDistance;
  Duration? _importedDuration;
  List<LocationPoint>? _importedGpsPoints;
  double? _importedAveragePace;
  DateTime? _importedStartTime;
  DateTime? _importedEndTime;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: kMidnightNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () => context.go('/'),
            tooltip: 'Go Home',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Account'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurfaceBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  authState == AuthState.authenticated ? Icons.verified_user : Icons.person_outline,
                  color: authState == AuthState.authenticated ? Colors.greenAccent : Colors.white70,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    authState == AuthState.authenticated ? (user?.email ?? 'Signed in') : 'Not signed in',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (authState == AuthState.authenticated) {
                      ref.read(authControllerProvider.notifier).signOut();
                    } else {
                      context.push('/login');
                    }
                  },
                  child: Text(
                    authState == AuthState.authenticated ? 'Sign out' : 'Sign in',
                  ),
                )
              ],
            ),
          ),
          
          _sectionTitle('DISTANCE UNITS'),
          _buildDistanceUnitsSection(),
          
          _sectionTitle('ENERGY UNITS'),
          _buildEnergyUnitsSection(),
          
          _sectionTitle('Audio & vibration notifications'),
          _buildAudioNotificationsSection(),
          
          _sectionTitle('EPISODE DOWNLOADS'),
          _buildEpisodeDownloadsSection(),
          
          _sectionTitle('APP THEME'),
          const ThemeSelectorWidget(),
          
          _sectionTitle('APP VOLUME'),
          _buildAppVolumeSection(),
          
          _sectionTitle('ZRX PLAYER MUSIC VOLUME'),
          _buildMusicVolumeSection(),
          
          _sectionTitle('Import Runs'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurfaceBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.upload_file, color: kElectricAqua),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Import GPX Run',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Import a GPX file to add a run to your workout history',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                
                // File selection button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isImporting ? null : _pickGpxFile,
                    icon: const Icon(Icons.file_open),
                    label: Text(_selectedFileName ?? 'Select GPX File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kElectricAqua,
                      foregroundColor: kMidnightNavy,
                    ),
                  ),
                ),
                
                // Show imported data preview
                if (_selectedFileName != null && _importedDistance != null && _importedDuration != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Run Preview:',
                          style: TextStyle(color: kElectricAqua, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPreviewItem(
                                'Distance',
                                '${_importedDistance!.toStringAsFixed(2)} km',
                                Icons.straighten,
                              ),
                            ),
                            Expanded(
                              child: _buildPreviewItem(
                                'Duration',
                                _formatDuration(_importedDuration!),
                                Icons.timer,
                              ),
                            ),
                          ],
                        ),
                        if (_importedAveragePace != null && _importedAveragePace! > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPreviewItem(
                                  'Avg Pace',
                                  '${_importedAveragePace!.toStringAsFixed(1)} min/km',
                                  Icons.speed,
                                ),
                              ),
                              Expanded(
                                child: _buildPreviewItem(
                                  'GPS Points',
                                  '${_importedGpsPoints?.length ?? 0}',
                                  Icons.location_on,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_importedStartTime != null && _importedEndTime != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPreviewItem(
                                  'Start Time',
                                  '${_importedStartTime!.hour.toString().padLeft(2, '0')}:${_importedStartTime!.minute.toString().padLeft(2, '0')}',
                                  Icons.play_arrow,
                                ),
                              ),
                              Expanded(
                                child: _buildPreviewItem(
                                  'End Time',
                                  '${_importedEndTime!.hour.toString().padLeft(2, '0')}:${_importedEndTime!.minute.toString().padLeft(2, '0')}',
                                  Icons.stop,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 12),
                
                // Import button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_selectedFileName != null && _importedDistance != null && _importedDuration != null && _importedGpsPoints != null && !_isImporting) 
                        ? _importGpxRun 
                        : null,
                    icon: _isImporting 
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(kMidnightNavy),
                            ),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(_isImporting ? 'Importing...' : 'Import Run'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kMeadowGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          _sectionTitle('Data & Cache'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurfaceBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cached, color: kElectricAqua),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Clear App Cache',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Clear cached data to get fresh information from the server',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final firestoreService = FirestoreService();
                    await firestoreService.clearCache();
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cache cleared successfully!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to clear cache: $e'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Clear Cache'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kElectricAqua,
                  foregroundColor: kMidnightNavy,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final firestoreService = FirestoreService();
                    final result = await firestoreService.fixTimestampFormats();
                    
                    if (context.mounted) {
                      final fixedCount = result['fixedCount'] as int;
                      final totalRuns = result['totalRuns'] as int;
                      final stringTimestamps = result['stringTimestamps'] as int;
                      
                      String message;
                      if (fixedCount > 0) {
                        message = 'Fixed $fixedCount timestamp formats! Your workouts should now display correctly.';
                      } else if (stringTimestamps > 0) {
                        message = 'Found $stringTimestamps runs with string dates, but they may not be ISO format. Check console for details.';
                      } else {
                        message = 'All $totalRuns runs already have valid timestamps!';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: fixedCount > 0 ? Colors.green : Colors.blue,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to fix timestamps: $e'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.schedule),
                label: const Text('Fix Run Timestamps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kElectricAqua,
                  foregroundColor: kMidnightNavy,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final firestoreService = FirestoreService();
                    final result = await firestoreService.forceUpdateAllTimestamps();
                    
                    if (context.mounted) {
                      final updatedCount = result['updatedCount'] as int;
                      final totalRuns = result['totalRuns'] as int;
                      
                      String message;
                      if (updatedCount > 0) {
                        message = 'Force updated $updatedCount timestamps! This should fix all workout display issues.';
                      } else {
                        message = 'All $totalRuns runs already have valid timestamps!';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: updatedCount > 0 ? Colors.green : Colors.blue,
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to force update timestamps: $e'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.update),
                label: const Text('Force Update All Timestamps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationWidget(
        currentIndex: BottomNavIndex.settings.value,
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(title, style: const TextStyle(color: Colors.white70)),
      );

  Widget _buildPreviewItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: kElectricAqua, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.white70, fontSize: 10),
            ),
            Text(
              value,
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDistanceUnitsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
      ),
      child: Consumer(
        builder: (context, ref, child) {
          final distanceUnit = ref.watch(distanceUnitProvider);
          
          return Column(
            children: [
              _buildUnitOption(
                'Kilometres',
                distanceUnit == DistanceUnit.kilometers,
                () => ref.read(distanceUnitProvider.notifier).setDistanceUnit(DistanceUnit.kilometers),
              ),
              const Divider(color: Colors.white24),
              _buildUnitOption(
                'Miles',
                distanceUnit == DistanceUnit.miles,
                () => ref.read(distanceUnitProvider.notifier).setDistanceUnit(DistanceUnit.miles),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEnergyUnitsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
      ),
      child: Consumer(
        builder: (context, ref, child) {
          final energyUnit = ref.watch(energyUnitProvider);
          
          return Column(
            children: [
              _buildUnitOption(
                'kCal',
                energyUnit == EnergyUnit.kcal,
                () => ref.read(energyUnitProvider.notifier).setEnergyUnit(EnergyUnit.kcal),
              ),
              const Divider(color: Colors.white24),
              _buildUnitOption(
                'kJ',
                energyUnit == EnergyUnit.kj,
                () => ref.read(energyUnitProvider.notifier).setEnergyUnit(EnergyUnit.kj),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUnitOption(String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: kElectricAqua,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioNotificationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active, color: kElectricAqua),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Audio & vibration notifications',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
        ],
      ),
    );
  }

  Widget _buildAppVolumeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
      ),
      child: Consumer(
        builder: (context, ref, child) {
          final appVolume = ref.watch(appVolumeProvider);
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set the volume of clips and notifications relative to music tracks',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.volume_down, color: Colors.white70),
                  Expanded(
                    child: Slider(
                      value: appVolume,
                      onChanged: (value) {
                        ref.read(appVolumeProvider.notifier).setAppVolume(value);
                      },
                      activeColor: kElectricAqua,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  Icon(Icons.volume_up, color: Colors.white70),
                ],
              ),
              Center(
                child: Text(
                  '${(appVolume * 100).round()}%',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMusicVolumeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
      ),
      child: Consumer(
        builder: (context, ref, child) {
          final musicVolume = ref.watch(musicVolumeProvider);
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Useful if you are having issues balancing music and story clips',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.volume_down, color: Colors.white70),
                  Expanded(
                    child: Slider(
                      value: musicVolume,
                      onChanged: (value) {
                        ref.read(musicVolumeProvider.notifier).setMusicVolume(value);
                      },
                      activeColor: kElectricAqua,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  Icon(Icons.volume_up, color: Colors.white70),
                ],
              ),
              Center(
                child: Text(
                  'Volume: ${(musicVolume * 100).round()}%',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEpisodeDownloadsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage your downloaded episodes',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kElectricAqua.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.download_done,
                color: kElectricAqua,
                size: 20,
              ),
            ),
            title: const Text(
              'Episode Downloads',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'View and delete downloaded episodes',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 16,
            ),
            onTap: () {
              context.push('/settings/episode-downloads');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickGpxFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx'],
      );

      if (result != null) {
        setState(() {
          _selectedFileName = result.files.first.name;
        });
        
        final file = File(result.files.first.path!);
        final gpxData = _parseGpxFile(file);
        
        setState(() {
          _importedDistance = gpxData['distance'];
          _importedDuration = gpxData['duration'];
          _importedGpsPoints = gpxData['gpsPoints'];
          _importedAveragePace = gpxData['averagePace'];
          _importedStartTime = gpxData['startTime'];
          _importedEndTime = gpxData['endTime'];
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import GPX file: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

    Map<String, dynamic> _parseGpxFile(File file) {
    try {
      final content = file.readAsStringSync();
      final document = XmlDocument.parse(content);
      
      // Find all track points
      final trackPoints = document.findAllElements('trkpt');
      
      if (trackPoints.isEmpty) {
        throw Exception('No track points found in GPX file');
      }
      
      double totalDistance = 0.0;
      DateTime? startTime;
      DateTime? endTime;
      List<Map<String, double>> coordinates = [];
      List<LocationPoint> gpsPoints = [];
      
            // Extract coordinates, timestamps, and create LocationPoint objects
      for (int i = 0; i < trackPoints.length; i++) {
        final point = trackPoints.elementAt(i);
        final lat = double.tryParse(point.getAttribute('lat') ?? '');
        final lon = double.tryParse(point.getAttribute('lon') ?? '');
        final timeElement = point.findElements('time').firstOrNull;
        final elevationElement = point.findElements('ele').firstOrNull;
        
        if (lat != null && lon != null) {
          coordinates.add({'lat': lat, 'lon': lon});
          
          // Parse elevation if available
          double altitude = 0.0;
          if (elevationElement != null && elevationElement.value != null) {
            altitude = double.tryParse(elevationElement.value!) ?? 0.0;
          }
          
          // Parse time if available
          DateTime? pointTime;
                      if (timeElement != null && timeElement.value != null) {
              try {
                pointTime = DateTime.parse(timeElement.value!);
                // Set start time from first valid track point
                startTime ??= pointTime;
                // Always update end time to the last valid track point
                endTime = pointTime;
              } catch (e) {
                // Skip invalid time formats
              }
            }
          
          // Calculate elapsed seconds from start time
          int elapsedSeconds = 0;
          if (startTime != null && pointTime != null) {
            elapsedSeconds = pointTime.difference(startTime).inSeconds;
          }
          
          // Create LocationPoint object
          final locationPoint = LocationPoint(
            latitude: lat,
            longitude: lon,
            accuracy: 5.0, // Default accuracy for imported GPX
            altitude: altitude,
            speed: 0.0, // Will be calculated if we have time data
            elapsedSeconds: elapsedSeconds,
            heading: -1, // Default heading for imported GPX
            elapsedTimeFormatted: _formatDuration(Duration(seconds: elapsedSeconds)),
          );
          
          gpsPoints.add(locationPoint);
        }
      }
      
      // Calculate total distance using Haversine formula
      for (int i = 0; i < coordinates.length - 1; i++) {
        final lat1 = coordinates[i]['lat']!;
        final lon1 = coordinates[i]['lon']!;
        final lat2 = coordinates[i + 1]['lat']!;
        final lon2 = coordinates[i + 1]['lon']!;
        
        totalDistance += _calculateDistance(lat1, lon1, lat2, lon2);
      }
      
      // Calculate duration
      Duration duration = Duration.zero;
      if (startTime != null && endTime != null) {
        duration = endTime.difference(startTime);
      }
      
      // Calculate average pace (minutes per kilometer)
      double averagePace = 0.0;
      if (totalDistance > 0 && duration.inSeconds > 0) {
        averagePace = duration.inMinutes / totalDistance;
      }
      
      // Ensure we have valid timing data
      if (startTime == null || endTime == null) {
        throw Exception('No valid timing data found in GPX file');
      }
      
      return {
        'distance': totalDistance,
        'duration': duration,
        'gpsPoints': gpsPoints,
        'averagePace': averagePace,
        'startTime': startTime,
        'endTime': endTime,
      };
    } catch (e) {
      throw Exception('Failed to parse GPX file: $e');
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _importGpxRun() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final firestoreService = FirestoreService();
      final newRun = RunModel(
        userId: ref.read(currentUserProvider).value!.uid,
        createdAt: _importedStartTime ?? DateTime.now(),
        completedAt: _importedEndTime ?? DateTime.now(),
        route: _importedGpsPoints ?? [], // This maps to 'gpsPoints' in Firestore
        totalDistance: _importedDistance!,
        totalTime: _importedDuration!,
        averagePace: _importedAveragePace ?? 0.0,
        status: RunStatus.completed,
        metadata: {
          'gpxFile': _selectedFileName!,
          'imported': true,
          'notes': 'Imported from GPX file',
          'gpsPointsCount': _importedGpsPoints?.length ?? 0,
        },
      );

      await firestoreService.saveRun(newRun);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Run imported successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import run: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isImporting = false;
        _selectedFileName = null;
        _importedDistance = null;
        _importedDuration = null;
        _importedGpsPoints = null;
        _importedAveragePace = null;
        _importedStartTime = null;
        _importedEndTime = null;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
