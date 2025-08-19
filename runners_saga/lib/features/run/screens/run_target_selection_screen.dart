import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/run_target_model.dart';
import '../../../shared/providers/run_providers.dart';
import '../../../shared/providers/story_providers.dart';
import '../../../core/constants/app_theme.dart';

class RunTargetSelectionScreen extends ConsumerStatefulWidget {
  const RunTargetSelectionScreen({super.key});

  @override
  ConsumerState<RunTargetSelectionScreen> createState() => _RunTargetSelectionScreenState();
}

class _RunTargetSelectionScreenState extends ConsumerState<RunTargetSelectionScreen> {
  RunTarget? selectedTarget;
  RunTargetType selectedType = RunTargetType.time;
  final TextEditingController _customValueController = TextEditingController();
  bool _isCustomTarget = false;

  @override
  void initState() {
    super.initState();
    // Set default selection
    selectedTarget = RunTarget.predefinedTargets.first;
  }

  @override
  void dispose() {
    _customValueController.dispose();
    super.dispose();
  }

  void _createCustomTarget() {
    final value = double.tryParse(_customValueController.text);
    if (value != null && value > 0) {
      final customTarget = RunTarget(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        type: selectedType,
        value: value,
        displayName: '${value.toStringAsFixed(selectedType == RunTargetType.time ? 0 : 1)} ${selectedType == RunTargetType.time ? 'minutes' : 'km'}',
        description: 'Custom ${selectedType == RunTargetType.time ? 'time' : 'distance'} target',
        createdAt: DateTime.now(),
        isCustom: true,
      );
      selectedTarget = customTarget;
      setState(() {});
    }
  }

  void _startRun() {
    if (selectedTarget != null) {
      // Store the selected target in the provider
      ref.read(selectedRunTargetProvider.notifier).state = selectedTarget;
      
      // Navigate to the run screen
      context.go('/run');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMidnightNavy,
      appBar: AppBar(
        title: const Text('Choose Your Run Target', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: kMidnightNavy,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  'What\'s your goal today?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a target to help us pace your story adventure',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: kTextMid,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Target Type Selection
                Container(
                  padding: const EdgeInsets.all(16),
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
                      Text('Target Type', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTypeButton(
                              RunTargetType.time,
                              'Time',
                              Icons.timer,
                              selectedType == RunTargetType.time,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTypeButton(
                              RunTargetType.distance,
                              'Distance',
                              Icons.place,
                              selectedType == RunTargetType.distance,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Predefined Targets
                if (!_isCustomTarget) ...[
                  Text('Quick Select', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: RunTarget.predefinedTargets
                          .where((target) => target.type == selectedType)
                          .length,
                      itemBuilder: (context, index) {
                        final targets = RunTarget.predefinedTargets
                            .where((target) => target.type == selectedType)
                            .toList();
                        final target = targets[index];
                        final isSelected = selectedTarget?.id == target.id;

                        return _buildTargetCard(target, isSelected);
                      },
                    ),
                  ),
                ],

                // Custom Target Input
                if (_isCustomTarget) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Custom Target',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _customValueController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: selectedType == RunTargetType.time 
                                ? 'Enter minutes (e.g., 25)' 
                                : 'Enter miles (e.g., 4.5)',
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.blue, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _createCustomTarget,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Create Target',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _isCustomTarget = false;
                                    _customValueController.clear();
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Custom Target Button
                if (!_isCustomTarget) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isCustomTarget = true;
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Custom Target'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Start Run Button
                ElevatedButton(
                  onPressed: selectedTarget != null ? _startRun : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    selectedTarget != null 
                        ? 'Start ${selectedTarget!.displayName} Run'
                        : 'Select a Target',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeButton(RunTargetType type, String label, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedType = type;
          // Reset selection to first target of new type
          selectedTarget = RunTarget.predefinedTargets
              .where((target) => target.type == type)
              .first;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetCard(RunTarget target, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTarget = target;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                target.displayName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                target.description,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8) : Theme.of(context).textTheme.bodyMedium?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
