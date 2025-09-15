import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/run_config_providers.dart';

class StepCountSettingsScreen extends ConsumerStatefulWidget {
  const StepCountSettingsScreen({super.key});

  @override
  ConsumerState<StepCountSettingsScreen> createState() => _StepCountSettingsScreenState();
}

class _StepCountSettingsScreenState extends ConsumerState<StepCountSettingsScreen> {
  late int _meters;
  late int _centimeters;

  @override
  void initState() {
    super.initState();
    final stride = ref.read(stepStrideMetersProvider);
    _meters = stride.floor();
    _centimeters = ((stride - _meters) * 100).round();
  }

  double get _strideMeters => _meters + (_centimeters / 100.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stride Length'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(stepStrideMetersProvider.notifier).setStride(_strideMeters);
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
              'The length of one step when you run. Set to estimate your run distance.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(initialItem: _meters.clamp(0, 3)),
                    onSelectedItemChanged: (index) {
                      setState(() => _meters = index);
                    },
                    children: List.generate(4, (i) => Center(child: Text('$i m'))),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(initialItem: (_centimeters / 5).round()),
                    onSelectedItemChanged: (index) {
                      setState(() => _centimeters = index * 5);
                    },
                    children: List.generate(21, (i) => Center(child: Text('${i * 5} cm'))),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('Current: ${_strideMeters.toStringAsFixed(2)} m', style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

