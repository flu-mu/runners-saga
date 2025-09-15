import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import '../../../shared/providers/run_config_providers.dart';
import '../../models/coach_providers.dart';
import '../../../shared/models/run_enums.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/themes/theme_selector_widget.dart';
import '../../../shared/widgets/ui/seasonal_background.dart';
import '../../../core/themes/theme_factory.dart';

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
    final theme = ThemeFactory.getCurrentTheme();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onBackground,
        title: Text(
          'Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onBackground,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: theme.colorScheme.onBackground,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.home,
              color: theme.colorScheme.onBackground,
            ),
            onPressed: () => context.go('/'),
            tooltip: 'Go Home',
          ),
        ],
      ),
      body: SeasonalBackground(
        showHeaderPattern: true,
        headerHeight: 100,
        child: ListView(
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
                  color: authState == AuthState.authenticated ? kElectricAqua : Colors.white70,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    authState == AuthState.authenticated ? (user?.email ?? 'Signed in') : 'Not signed in',
                    style: TextStyle(color: Colors.white),
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

          _sectionTitle('FITNESS PROFILE'),
          _buildFitnessProfileSection(),
          
          _sectionTitle('Audio & vibration notifications'),
          _buildAudioNotificationsSection(),
          
          _sectionTitle('EPISODE DOWNLOADS'),
          _buildEpisodeDownloadsSection(),
          
          _sectionTitle('APP THEME'),
          const ThemeSelectorWidget(),
          
          // Background Test Link
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => context.go('/test/background'),
              icon: const Icon(Icons.palette),
              label: const Text('Test Background Patterns'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          // Landscape Design Link
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => context.go('/test/landscape'),
              icon: const Icon(Icons.landscape),
              label: const Text('Sunset Landscape Design'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          _sectionTitle('APP VOLUME'),
          _buildAppVolumeSection(),
          
          _sectionTitle('SAGA VOLUME'),
          _buildMusicVolumeSection(),

          _sectionTitle('COACH'),
          _buildCoachSettingsSection(),
          
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
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
                          backgroundColor: kElectricAqua,
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
                          backgroundColor: fixedCount > 0 ? kElectricAqua : Colors.blue,
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
                          backgroundColor: updatedCount > 0 ? kElectricAqua : Colors.blue,
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
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
              ],
            ),
          ),
        ],
        ),
      ),
      bottomNavigationBar: BottomNavigationWidget(
        currentIndex: BottomNavIndex.settings.value,
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
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
              Divider(color: Colors.white24),
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
              Divider(color: Colors.white24),
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

  Widget _buildFitnessProfileSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
      ),
      child: Consumer(
        builder: (context, ref, child) {
          final weight = ref.watch(userWeightKgProvider) ?? 70.0;
          final height = ref.watch(heightCmProvider);
          final age = ref.watch(ageYearsProvider);
          final gender = ref.watch(genderProvider);

          String genderLabel(Gender g) {
            switch (g) {
              case Gender.female:
                return 'Female';
              case Gender.male:
                return 'Male';
              case Gender.nonBinary:
                return 'Non-binary';
              case Gender.preferNotToSay:
                return 'Prefer not to say';
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weight
              Row(
                children: [
                  Icon(Icons.monitor_weight, color: kElectricAqua),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weight (kg)', style: TextStyle(color: Colors.white)),
                        Slider(
                          min: 40,
                          max: 130,
                          divisions: 90,
                          value: weight,
                          label: weight.toStringAsFixed(0),
                          onChanged: (v) async {
                            ref.read(userWeightKgProvider.notifier).state = v;
                            // Persist locally
                            await ref.read(settingsServiceProvider).setUserWeightKg(v);
                            // Best-effort sync to Firestore
                            try {
                              final auth = ref.read(authServiceProvider);
                              await auth.setUserWeightKg(v);
                            } catch (_) {}
                          },
                        ),
                        Text('${weight.toStringAsFixed(0)} kg', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Height
              Row(
                children: [
                  Icon(Icons.height, color: kElectricAqua),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Height (cm)', style: TextStyle(color: Colors.white)),
                        Slider(
                          min: 120,
                          max: 220,
                          divisions: 100,
                          value: height.toDouble(),
                          label: height.toString(),
                          onChanged: (v) async {
                            final val = v.round();
                            ref.read(heightCmProvider.notifier).setHeight(val);
                            await ref.read(settingsServiceProvider).setUserHeightCm(val);
                            try {
                              final auth = ref.read(authServiceProvider);
                              await auth.setUserHeightCm(val);
                            } catch (_) {}
                          },
                        ),
                        Text('$height cm', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Age
              Row(
                children: [
                  Icon(Icons.cake, color: kElectricAqua),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Age (years)', style: TextStyle(color: Colors.white)),
                        Slider(
                          min: 10,
                          max: 100,
                          divisions: 90,
                          value: age.toDouble(),
                          label: age.toString(),
                          onChanged: (v) async {
                            final val = v.round();
                            ref.read(ageYearsProvider.notifier).setAge(val);
                            await ref.read(settingsServiceProvider).setUserAgeYears(val);
                            try {
                              final auth = ref.read(authServiceProvider);
                              await auth.setUserAgeYears(val);
                            } catch (_) {}
                          },
                        ),
                        Text('$age years', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Gender
              Row(
                children: [
                  Icon(Icons.person, color: kElectricAqua),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gender', style: TextStyle(color: Colors.white)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: kElectricAqua.withValues(alpha: 0.3)),
                          ),
                          child: DropdownButton<Gender>(
                            value: gender,
                            dropdownColor: kSurfaceBase,
                            underline: SizedBox.shrink(),
                            isExpanded: true,
                            iconEnabledColor: Colors.white70,
                            items: Gender.values
                                .map((g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(genderLabel(g), style: const TextStyle(color: Colors.white)),
                                    ))
                                .toList(),
                            onChanged: (g) async {
                              if (g != null) {
                                ref.read(genderProvider.notifier).setGender(g);
                                await ref.read(settingsServiceProvider).setUserGender(g);
                                try {
                                  final auth = ref.read(authServiceProvider);
                                  // Persist as string token
                                  String token;
                                  switch (g) {
                                    case Gender.female:
                                      token = 'female';
                                      break;
                                    case Gender.male:
                                      token = 'male';
                                      break;
                                    case Gender.nonBinary:
                                      token = 'nonBinary';
                                      break;
                                    case Gender.preferNotToSay:
                                      token = 'preferNotToSay';
                                      break;
                                  }
                                  await auth.setUserGender(token);
                                } catch (_) {}
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontSize: 16),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.primary,
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
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Audio & vibration notifications',
              style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontSize: 16),
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7), size: 16),
        ],
      ),
    );
  }

  Widget _buildAppVolumeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Consumer(
        builder: (context, ref, child) {
          final appVolume = ref.watch(appVolumeProvider);
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set the volume of clips and notifications relative to music tracks',
                style: TextStyle(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7), fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.volume_down, color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7)),
                  Expanded(
                    child: Slider(
                      value: appVolume,
                      onChanged: (value) {
                        ref.read(appVolumeProvider.notifier).setAppVolume(value);
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Theme.of(context).colorScheme.onBackground.withOpacity(0.2),
                    ),
                  ),
                  Icon(Icons.volume_up, color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7)),
                ],
              ),
              Center(
                child: Text(
                  '${(appVolume * 100).round()}%',
                  style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontSize: 16, fontWeight: FontWeight.w600),
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
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Consumer(
        builder: (context, ref, child) {
          final musicVolume = ref.watch(musicVolumeProvider);
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Useful if you are having issues balancing music and story clips',
                style: TextStyle(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7), fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.volume_down, color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7)),
                  Expanded(
                    child: Slider(
                      value: musicVolume,
                      onChanged: (value) {
                        ref.read(musicVolumeProvider.notifier).setMusicVolume(value);
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Theme.of(context).colorScheme.onBackground.withOpacity(0.2),
                    ),
                  ),
                  Icon(Icons.volume_up, color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7)),
                ],
              ),
              Center(
                child: Text(
                  'Volume: ${(musicVolume * 100).round()}%',
                  style: TextStyle(color: Theme.of(context).colorScheme.onBackground, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCoachSettingsSection() {
    final coachEnabled = ref.watch(coachEnabledProvider);
    final frequencyType = ref.watch(coachFrequencyTypeProvider);
    final timeFrequency = ref.watch(coachTimeFrequencyProvider);
    final distanceFrequency = ref.watch(coachDistanceFrequencyProvider);
    final statsToRead = ref.watch(coachStatsProvider);
    final distanceUnit = ref.watch(distanceUnitProvider);

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
          SwitchListTile(
            title: Text('Enable Coach', style: TextStyle(color: Colors.white)),
            value: coachEnabled,
            onChanged: (value) => ref.read(coachEnabledProvider.notifier).setEnabled(value),
            activeColor: kElectricAqua,
          ),
          Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Text('Frequency', style: TextStyle(color: Colors.white70)),
          if (coachEnabled) ...[
            ToggleButtons(
              children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('By Time')),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('By Distance')),
              ],
              isSelected: [frequencyType == CoachFrequencyType.time, frequencyType == CoachFrequencyType.distance],
              onPressed: (index) {
                final newType = index == 0 ? CoachFrequencyType.time : CoachFrequencyType.distance;
                ref.read(coachFrequencyTypeProvider.notifier).setType(newType);
              },
              color: Colors.white,
              selectedColor: kMidnightNavy,
              fillColor: kElectricAqua,
              borderRadius: BorderRadius.circular(8),
            ),
          ],
          if (coachEnabled && frequencyType == CoachFrequencyType.time) ...[
            Slider(
              value: timeFrequency,
              min: 5,
              max: 15,
              divisions: 10,
              label: '${timeFrequency.round()} min',
              onChanged: (value) => ref.read(coachTimeFrequencyProvider.notifier).setMinutes(value),
            ),
            Center(child: Text('Every ${timeFrequency.round()} minutes', style: TextStyle(color: Colors.white70))),
          ] else if (coachEnabled && frequencyType == CoachFrequencyType.distance) ...[
            Slider(
              value: distanceFrequency,
              min: 0.5,
              max: 5.0,
              divisions: 9,
              label: '${distanceFrequency.toStringAsFixed(1)} ${distanceUnit == DistanceUnit.kilometers ? 'km' : 'mi'}',
              onChanged: (value) => ref.read(coachDistanceFrequencyProvider.notifier).setDistance(value),
            ),
            Center(child: Text('Every ${distanceFrequency.toStringAsFixed(1)} ${distanceUnit == DistanceUnit.kilometers ? 'km' : 'mi'}', style: TextStyle(color: Colors.white70))),
          ],
          const SizedBox(height: 16),
          Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Text('Stats to Read Out', style: TextStyle(color: Colors.white70)),
          if (coachEnabled)
            ...CoachStat.values.map((stat) {
              return CheckboxListTile(
                title: Text(stat.name[0].toUpperCase() + stat.name.substring(1), style: TextStyle(color: Colors.white)),
                value: statsToRead.contains(stat),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(coachStatsProvider.notifier).toggleStat(stat, value);
                  }
                },
                activeColor: kElectricAqua,
                checkColor: kMidnightNavy,
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildEpisodeDownloadsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manage your downloaded episodes',
            style: TextStyle(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.download_done,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              'Episode Downloads',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'View and delete downloaded episodes',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
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
        final content = await file.readAsString();
        // Parse in a background isolate to avoid jank
        final gpxData = await compute(_parseGpxContentIsolate, content);
        
        setState(() {
          _importedDistance = (gpxData['distance'] as num?)?.toDouble();
          _importedDuration = Duration(seconds: (gpxData['durationSeconds'] as int? ?? 0));
          _importedGpsPoints = ((gpxData['gpsPoints'] as List<dynamic>? ?? const []))
              .map((p) => LocationPoint(
                    latitude: (p['latitude'] as num).toDouble(),
                    longitude: (p['longitude'] as num).toDouble(),
                    accuracy: (p['accuracy'] as num).toDouble(),
                    altitude: (p['altitude'] as num).toDouble(),
                    speed: (p['speed'] as num).toDouble(),
                    elapsedSeconds: (p['elapsedSeconds'] as int),
                    heading: (p['heading'] as num?)?.toDouble() ?? -1,
                    elapsedTimeFormatted: p['elapsedTimeFormatted'] as String?,
                  ))
              .toList();
          _importedAveragePace = (gpxData['averagePace'] as num?)?.toDouble();
          final startIso = gpxData['startTime'] as String?;
          final endIso = gpxData['endTime'] as String?;
          _importedStartTime = startIso != null ? DateTime.tryParse(startIso) : null;
          _importedEndTime = endIso != null ? DateTime.tryParse(endIso) : null;
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

    // Parsing now handled in background isolate via _parseGpxContentIsolate
    Future<Map<String, dynamic>> _parseGpxFile(File file) async {
      final content = await file.readAsString();
      return compute(_parseGpxContentIsolate, content);
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
        achievements: [], // Add empty achievements list
        metadata: {
          'gpxFile': _selectedFileName!,
          'imported': true,
          'notes': 'Imported from GPX file',
          'gpsPointsCount': _importedGpsPoints?.length ?? 0,
          'anomalySlowPace': (_importedAveragePace != null && _importedAveragePace! > 0)
              ? (_importedAveragePace! >= 20.0)
              : false,
          'avgSpeedKmh': (_importedAveragePace != null && _importedAveragePace! > 0)
              ? (60.0 / _importedAveragePace!)
              : 0.0,
        },
      );

      await firestoreService.saveRun(newRun);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Run imported successfully!'),
            backgroundColor: kElectricAqua,
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

// Top-level isolate function to parse GPX without blocking UI
Map<String, dynamic> _parseGpxContentIsolate(String content) {
  try {
    final document = XmlDocument.parse(content);

    // Find all track points
    final trackPoints = document.findAllElements('trkpt');
    if (trackPoints.isEmpty) {
      throw Exception('No track points found in GPX file');
    }

    double totalDistance = 0.0;
    DateTime? startTime;
    DateTime? endTime;
    final List<Map<String, double>> coordinates = [];
    final List<double> altitudes = [];
    final List<Map<String, dynamic>> rawPoints = [];

    // Extract coordinates and timestamps
    for (final point in trackPoints) {
      final lat = double.tryParse(point.getAttribute('lat') ?? '');
      final lon = double.tryParse(point.getAttribute('lon') ?? '');
      if (lat == null || lon == null) continue;

      coordinates.add({'lat': lat, 'lon': lon});

      final elevationElement = point.findElements('ele').firstOrNull;
      double altitude = 0.0;
      if (elevationElement != null) {
        altitude = double.tryParse(elevationElement.text.trim()) ?? 0.0;
      }
      altitudes.add(altitude);

      // Parse time if available
      DateTime? pointTime;
      final timeElement = point.findElements('time').firstOrNull;
      if (timeElement != null) {
        final t = timeElement.text.trim();
        pointTime = DateTime.tryParse(t);
        if (pointTime != null) {
          startTime ??= pointTime;
          endTime = pointTime;
        }
      }

      int elapsedSeconds = 0;
      if (startTime != null && pointTime != null) {
        elapsedSeconds = pointTime.difference(startTime!).inSeconds;
      }

      rawPoints.add({
        'latitude': lat,
        'longitude': lon,
        'accuracy': 5.0,
        'altitude': altitude,
        'speed': 0.0,
        'elapsedSeconds': elapsedSeconds,
        'heading': -1,
        'elapsedTimeFormatted': _formatDurationIsolate(Duration(seconds: elapsedSeconds)),
      });
    }

    // Compute distance
    for (int i = 0; i < coordinates.length - 1; i++) {
      totalDistance += _calculateDistanceKmIsolate(
        coordinates[i]['lat']!,
        coordinates[i]['lon']!,
        coordinates[i + 1]['lat']!,
        coordinates[i + 1]['lon']!,
      );
    }

    Duration duration = Duration.zero;
    if (startTime == null || endTime == null) {
      // Fallback timing
      final pointsCount = coordinates.length;
      if (pointsCount < 2) {
        throw Exception('Not enough points to infer timing');
      }

      double totalSeconds = (pointsCount - 1).toDouble();
      double inferredPaceMinPerKm = 6.0;
      if (totalDistance > 0) {
        inferredPaceMinPerKm = (totalSeconds / 60.0) / totalDistance;
      }

      DateTime? metadataTime;
      final metaTimeElement = document
          .findAllElements('metadata')
          .firstOrNull
          ?.findElements('time')
          .firstOrNull;
      if (metaTimeElement != null) {
        metadataTime = DateTime.tryParse(metaTimeElement.text.trim());
      }

      List<Map<String, dynamic>> rebuilt = [];
      double cumulative = 0.0;
      for (int i = 0; i < pointsCount; i++) {
        if (i > 0) {
          final segKm = _calculateDistanceKmIsolate(
            coordinates[i - 1]['lat']!,
            coordinates[i - 1]['lon']!,
            coordinates[i]['lat']!,
            coordinates[i]['lon']!,
          );
          double segSeconds;
          if (totalDistance > 0) {
            segSeconds = segKm * inferredPaceMinPerKm * 60.0;
          } else {
            segSeconds = 1.0;
          }
          cumulative += segSeconds;
        }

        final elapsed = cumulative.round();
        rebuilt.add({
          'latitude': coordinates[i]['lat']!,
          'longitude': coordinates[i]['lon']!,
          'accuracy': 5.0,
          'altitude': altitudes.length == pointsCount ? altitudes[i] : 0.0,
          'speed': 0.0,
          'elapsedSeconds': elapsed,
          'heading': -1,
          'elapsedTimeFormatted': _formatDurationIsolate(Duration(seconds: elapsed)),
        });
      }

      rawPoints
        ..clear()
        ..addAll(rebuilt);

      duration = Duration(seconds: cumulative.round());
      if (metadataTime != null) {
        startTime = metadataTime;
        endTime = metadataTime.add(duration);
      } else {
        endTime = DateTime.now();
        startTime = endTime!.subtract(duration);
      }
    } else {
      duration = endTime!.difference(startTime!);
    }

    double averagePace = 0.0;
    if (totalDistance > 0 && duration.inSeconds > 0) {
      averagePace = (duration.inSeconds / 60.0) / totalDistance;
    }

    if (startTime == null || endTime == null) {
      throw Exception('No valid timing data found in GPX file');
    }

    return {
      'distance': totalDistance,
      'durationSeconds': duration.inSeconds,
      'gpsPoints': rawPoints,
      'averagePace': averagePace,
      'startTime': startTime!.toIso8601String(),
      'endTime': endTime!.toIso8601String(),
    };
  } catch (e) {
    throw Exception('Failed to parse GPX file: $e');
  }
}

double _calculateDistanceKmIsolate(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371; // km
  final dLat = _degreesToRadiansIsolate(lat2 - lat1);
  final dLon = _degreesToRadiansIsolate(lon2 - lon1);
  final a =
      (sin(dLat / 2) * sin(dLat / 2)) + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * (sin(dLon / 2) * sin(dLon / 2));
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

double _degreesToRadiansIsolate(double degrees) => degrees * pi / 180;

String _formatDurationIsolate(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
