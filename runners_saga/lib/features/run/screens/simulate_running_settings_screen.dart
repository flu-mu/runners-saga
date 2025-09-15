import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/run_config_providers.dart';

class SimulateRunningSettingsScreen extends ConsumerStatefulWidget {
  const SimulateRunningSettingsScreen({super.key});

  @override
  ConsumerState<SimulateRunningSettingsScreen> createState() => _SimulateRunningSettingsScreenState();
}

class _SimulateRunningSettingsScreenState extends ConsumerState<SimulateRunningSettingsScreen> {
  late int _minutes;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    final pace = ref.read(simulatePaceMinPerKmProvider);
    _minutes = pace.floor();
    _seconds = (((pace - _minutes) * 60) / 5).round() * 5; // nearest 5s
  }

  double get _paceMinPerKm => _minutes + (_seconds / 60.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Running Pace'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(simulatePaceMinPerKmProvider.notifier).setPace(_paceMinPerKm);
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'The app will assume you are running at a fixed pace. Use this for any exercise where GPS is unavailable.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('per kilometer', style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(initialItem: _minutes.clamp(3, 20) - 3),
                    onSelectedItemChanged: (index) {
                      setState(() => _minutes = index + 3);
                    },
                    children: List.generate(18, (i) => Center(child: Text('${i + 3} min'))),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(initialItem: (_seconds / 5).round()),
                    onSelectedItemChanged: (index) {
                      setState(() => _seconds = index * 5);
                    },
                    children: List.generate(12, (i) => Center(child: Text('${i * 5} sec'))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('Current: ${_minutes}m ${_seconds}s / km', style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

