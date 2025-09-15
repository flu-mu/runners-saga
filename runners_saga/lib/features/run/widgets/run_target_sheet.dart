import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/run_target_model.dart';
import '../../../shared/providers/run_providers.dart';
import '../../../shared/providers/run_config_providers.dart';
import '../../../shared/models/run_enums.dart';
import '../../../shared/services/settings/settings_service.dart';
import '../../../shared/providers/run_session_providers.dart';
import '../../../core/constants/app_theme.dart';

class RunTargetSheet extends ConsumerStatefulWidget {
  const RunTargetSheet({super.key});

  @override
  ConsumerState<RunTargetSheet> createState() => _RunTargetSheetState();
}

class _RunTargetSheetState extends ConsumerState<RunTargetSheet> {
  RunTargetType _type = RunTargetType.distance;
  // Which row is active under the tab
  bool _isGoalSlider = true; // true: goal slider, false: clip-interval slider

  // Slider values
  double _goalDistanceKm = 5.0;
  double _goalMinutes = 30.0;
  double _intervalKm = 0.4; // distance between clips
  double _intervalMinutes = 3.0; // time between clips

  // Distance unit handling
  bool _isImperial = false; // miles when true
  String _distanceUnitSymbol = 'km';

  // Helpers for fast sync conversions without async calls in build
  static const double _kmToMiles = 0.621371;
  double _toDisplayDistance(double km) => _isImperial ? (km * _kmToMiles) : km;
  double _toKm(double display) => _isImperial ? (display / _kmToMiles) : display;

  @override
  void initState() {
    super.initState();
    // Seed from settings/providers if available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = SettingsService();
      final modeIndex = await settings.getClipIntervalModeIndex();
      final dist = await settings.getClipIntervalDistanceKm();
      final mins = await settings.getClipIntervalMinutes();
      final unit = await settings.getDistanceUnit();
      final symbol = await settings.getDistanceUnitSymbol();
      if (!mounted) return;
      setState(() {
        _intervalKm = dist;
        _intervalMinutes = mins;
        _type = modeIndex == 1 ? RunTargetType.time : RunTargetType.distance;
        _isImperial = unit.toString().contains('miles');
        _distanceUnitSymbol = symbol;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onBackground.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Duration', 
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6)), 
                    onPressed: () => Navigator.pop(context)
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Type toggle
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ToggleButtons(
                  isSelected: [_type == RunTargetType.distance, _type == RunTargetType.time],
                  onPressed: (index) {
                    setState(() {
                      _type = index == 0 ? RunTargetType.distance : RunTargetType.time;
                      _isGoalSlider = true; // reset to first row on tab change
                    });
                  },
                  selectedColor: Theme.of(context).colorScheme.onPrimary,
                  fillColor: Theme.of(context).colorScheme.primary,
                  borderColor: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                  children: [
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Distance', style: TextStyle(color: Theme.of(context).colorScheme.onBackground))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Time', style: TextStyle(color: Theme.of(context).colorScheme.onBackground))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Options list (radio-style)
              _OptionRow(
                title: _type == RunTargetType.distance ? 'Set how far to run' : 'Set how long to run',
                selected: _isGoalSlider,
                onTap: () => setState(() => _isGoalSlider = true),
              ),
              const SizedBox(height: 8),
              _OptionRow(
                title: _type == RunTargetType.distance ? 'Set distance between clips' : 'Set time between clips',
                selected: !_isGoalSlider,
                onTap: () => setState(() => _isGoalSlider = false),
              ),
              const SizedBox(height: 12),
              Divider(color: Theme.of(context).dividerColor.withOpacity(0.7), thickness: 1),
              const SizedBox(height: 12),

              // Slider area
              if (_type == RunTargetType.distance && _isGoalSlider) ...[
                Builder(builder: (context) {
                  final displayVal = _toDisplayDistance(_goalDistanceKm);
                  final minDisplay = _toDisplayDistance(1.0);
                  final maxDisplay = _toDisplayDistance(42.0);
                  final divisions = ((maxDisplay - minDisplay) / 0.1).round();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Run for ${displayVal.toStringAsFixed(1)} $_distanceUnitSymbol', style: Theme.of(context).textTheme.titleMedium),
                      Slider(
                        value: displayVal,
                        min: minDisplay,
                        max: maxDisplay,
                        divisions: divisions,
                        label: '${displayVal.toStringAsFixed(1)} $_distanceUnitSymbol',
                        onChanged: (v) => setState(() => _goalDistanceKm = double.parse(_toKm(v).toStringAsFixed(1))),
                      ),
                    ],
                  );
                }),
              ] else if (_type == RunTargetType.distance && !_isGoalSlider) ...[
                Builder(builder: (context) {
                  final displayVal = _toDisplayDistance(_intervalKm);
                  final minDisplay = _toDisplayDistance(0.1);
                  final maxDisplay = _toDisplayDistance(2.0);
                  int divisions = ((maxDisplay - minDisplay) / 0.1).round();
                  if (divisions < 1) divisions = 1;
                  if (divisions > 1000) divisions = 1000;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('On average, clips play every ${displayVal.toStringAsFixed(1)} $_distanceUnitSymbol', style: Theme.of(context).textTheme.titleMedium),
                      Slider(
                        value: displayVal,
                        min: minDisplay,
                        max: maxDisplay,
                        divisions: divisions,
                        label: '${displayVal.toStringAsFixed(1)} $_distanceUnitSymbol',
                        onChanged: (v) => setState(() => _intervalKm = double.parse(_toKm(v).toStringAsFixed(1))),
                      ),
                    ],
                  );
                }),
              ] else if (_type == RunTargetType.time && _isGoalSlider) ...[
                Text('Run for ${_goalMinutes.toStringAsFixed(0)} min', style: Theme.of(context).textTheme.titleMedium),
                Slider(
                  value: _goalMinutes,
                  min: 15,
                  max: 120,
                  divisions: 105,
                  label: '${_goalMinutes.toStringAsFixed(0)} min',
                  onChanged: (v) => setState(() => _goalMinutes = v.roundToDouble()),
                ),
                Text('15 min minimum workout duration', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6))),
              ] else ...[
                Text('On average, clips play every ${_intervalMinutes.toStringAsFixed(1)} min', style: Theme.of(context).textTheme.titleMedium),
                Slider(
                  value: _intervalMinutes,
                  min: 1,
                  max: 10,
                  divisions: 90,
                  label: '${_intervalMinutes.toStringAsFixed(1)} min',
                  onChanged: (v) => setState(() => _intervalMinutes = double.parse(v.toStringAsFixed(1))),
                ),
                // Very rough estimate using 5 story beats
                Text('${(_intervalMinutes * 5).round()} min estimated workout duration', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6))),
              ],
              const SizedBox(height: 8),
              
              // Apply button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Save goal selection to selectedRunTargetProvider
                    if (_isGoalSlider) {
                      if (_type == RunTargetType.distance) {
                        final displayVal = _toDisplayDistance(_goalDistanceKm);
                        final displayLabel = '${displayVal.toStringAsFixed(1)} ${_distanceUnitSymbol}';
                        final target = RunTarget(
                          id: 'goal_distance_${_goalDistanceKm.toStringAsFixed(1)}',
                          type: RunTargetType.distance,
                          value: _goalDistanceKm,
                          displayName: displayLabel,
                          description: 'Custom distance goal',
                          createdAt: DateTime.now(),
                          isCustom: true,
                        );
                        ref.read(selectedRunTargetProvider.notifier).state = target;
                      } else {
                        final target = RunTarget(
                          id: 'goal_time_${_goalMinutes.round()}',
                          type: RunTargetType.time,
                          value: _goalMinutes,
                          displayName: '${_goalMinutes.round()} minutes',
                          description: 'Custom time goal',
                          createdAt: DateTime.now(),
                          isCustom: true,
                        );
                        ref.read(selectedRunTargetProvider.notifier).state = target;
                      }
                    }

                    // Persist clip interval configuration regardless of which slider was shown
                    if (_type == RunTargetType.distance) {
                      ref.read(clipIntervalModeProvider.notifier).setMode(ClipIntervalMode.distance);
                      ref.read(clipIntervalDistanceKmProvider.notifier).setKm(_intervalKm);
                    } else {
                      ref.read(clipIntervalModeProvider.notifier).setMode(ClipIntervalMode.time);
                      ref.read(clipIntervalMinutesProvider.notifier).setMinutes(_intervalMinutes);
                    }

                    // Live update running session if active
                    try {
                      final controller = ref.read(runSessionControllerProvider.notifier);
                      if (controller.isSessionActive) {
                        if (_type == RunTargetType.distance) {
                          controller.updateClipInterval(ClipIntervalMode.distance, distanceKm: _intervalKm);
                        } else {
                          controller.updateClipInterval(ClipIntervalMode.time, minutes: _intervalMinutes);
                        }
                      }
                    } catch (_) {}

                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Apply',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  const _OptionRow({required this.title, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
