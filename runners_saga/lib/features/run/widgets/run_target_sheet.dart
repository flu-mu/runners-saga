import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/run_target_model.dart';
import '../../../shared/providers/run_providers.dart';
import '../../../core/constants/app_theme.dart';

class RunTargetSheet extends ConsumerStatefulWidget {
  const RunTargetSheet({super.key});

  @override
  ConsumerState<RunTargetSheet> createState() => _RunTargetSheetState();
}

class _RunTargetSheetState extends ConsumerState<RunTargetSheet> {
  RunTargetType _type = RunTargetType.time;
  RunTarget? _selected;

  @override
  void initState() {
    super.initState();
    _selected = RunTarget.predefinedTargets.first;
    _type = _selected!.type;
  }

  @override
  Widget build(BuildContext context) {
    final targets = RunTarget.predefinedTargets.where((t) => t.type == _type).toList();

    return Container(
      decoration: const BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kTextMid.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Set Duration', 
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: kTextMid), 
                    onPressed: () => Navigator.pop(context)
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Type toggle
              Container(
                decoration: BoxDecoration(
                  color: kMidnightNavy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ToggleButtons(
                  isSelected: [_type == RunTargetType.distance, _type == RunTargetType.time],
                  onPressed: (index) {
                    setState(() {
                      _type = index == 0 ? RunTargetType.distance : RunTargetType.time;
                      final list = RunTarget.predefinedTargets.where((t) => t.type == _type).toList();
                      _selected = list.first;
                    });
                  },
                  selectedColor: kMidnightNavy,
                  fillColor: kElectricAqua,
                  borderColor: kElectricAqua,
                  borderRadius: BorderRadius.circular(8),
                  children: const [
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Distance')),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Time')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Target options
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final t in targets)
                    ChoiceChip(
                      label: Text(
                        t.displayName,
                        style: TextStyle(
                          color: _selected?.id == t.id ? kMidnightNavy : Colors.white,
                        ),
                      ),
                      selected: _selected?.id == t.id,
                      selectedColor: kElectricAqua,
                      backgroundColor: kSurfaceElev,
                      side: BorderSide(
                        color: _selected?.id == t.id ? kElectricAqua : kTextMid.withValues(alpha: 0.3),
                      ),
                      onSelected: (_) => setState(() => _selected = t),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Apply button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () {
                          // Persist provider selection for the session
                          final selection = RunTargetSelection(
                            targetDistance: _selected!.type == RunTargetType.distance ? _selected!.value : 0.0,
                            targetTime: _selected!.type == RunTargetType.time ? Duration(minutes: _selected!.value.toInt()) : Duration.zero,
                          );
                          // selectedRunTargetProvider is typed as RunTarget? in run_providers.
                          // For our flow we just store a simple RunTarget that mirrors the selection for compatibility.
                          final compatible = RunTarget(
                            id: 'sheet_${_selected!.id}',
                            type: _selected!.type,
                            value: _selected!.value,
                            displayName: _selected!.displayName,
                            description: _selected!.description,
                            createdAt: DateTime.now(),
                            isCustom: _selected!.isCustom,
                          );
                          ref.read(selectedRunTargetProvider.notifier).state = compatible;
                          Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kElectricAqua,
                    foregroundColor: kMidnightNavy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Apply',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: kMidnightNavy,
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


