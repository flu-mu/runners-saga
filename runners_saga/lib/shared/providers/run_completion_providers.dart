import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/run_completion_service.dart';

/// Provider for the run completion service
final runCompletionServiceProvider = Provider<RunCompletionService>((ref) {
  return RunCompletionService(ref.container);
});

/// Provider for the current run summary data
final currentRunSummaryProvider = StateProvider<RunSummaryData?>((ref) => null);

/// Provider for run completion state
final runCompletionStateProvider = StateProvider<RunCompletionState>((ref) => RunCompletionState.idle);

/// Provider for run completion actions
final runCompletionControllerProvider = StateNotifierProvider<RunCompletionController, RunCompletionState>((ref) {
  return RunCompletionController(ref);
});

/// Controller for run completion actions
class RunCompletionController extends StateNotifier<RunCompletionState> {
  final Ref _ref;
  
  RunCompletionController(this._ref) : super(RunCompletionState.idle);
  
  /// Complete the current run and prepare summary
  Future<RunSummaryData?> completeRun() async {
    try {
      state = RunCompletionState.completing;
      
      final service = _ref.read(runCompletionServiceProvider);
      final summaryData = await service.completeRun();
      
      // Update the summary provider
      _ref.read(currentRunSummaryProvider.notifier).state = summaryData;
      
      state = RunCompletionState.completed;
      return summaryData;
      
    } catch (e) {
      state = RunCompletionState.error;
      print('❌ RunCompletionController: Error completing run: $e');
      return null;
    }
  }
  
  /// Reset completion state
  void reset() {
    state = RunCompletionState.idle;
    _ref.read(currentRunSummaryProvider.notifier).state = null;
  }
  
  /// Get current summary data
  RunSummaryData? get currentSummary => _ref.read(currentRunSummaryProvider);
}

/// States for run completion process
enum RunCompletionState {
  idle,        // No completion in progress
  completing,  // Run completion in progress
  completed,   // Run successfully completed
  error,       // Error during completion
}










