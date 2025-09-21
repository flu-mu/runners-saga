import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings/settings_service.dart';
import 'settings_providers.dart';
import '../models/run_enums.dart';

// --- Coach Feature Providers ---

/// Provider for whether the Coach feature is enabled.
final coachEnabledProvider = StateNotifierProvider<CoachEnabledNotifier, bool>((ref) {
  return CoachEnabledNotifier(ref.watch(settingsServiceProvider));
});

class CoachEnabledNotifier extends StateNotifier<bool> {
  final SettingsService _settingsService;
  CoachEnabledNotifier(this._settingsService) : super(true) {
    _load();
  }
  Future<void> _load() async => state = await _settingsService.getCoachEnabled();
  Future<void> setEnabled(bool enabled) async {
    await _settingsService.setCoachEnabled(enabled);
    state = enabled;
  }
}

/// Provider for the Coach readout frequency type (time or distance).
final coachFrequencyTypeProvider = StateNotifierProvider<CoachFrequencyTypeNotifier, CoachFrequencyType>((ref) {
  return CoachFrequencyTypeNotifier(ref.watch(settingsServiceProvider));
});

class CoachFrequencyTypeNotifier extends StateNotifier<CoachFrequencyType> {
  final SettingsService _settingsService;
  CoachFrequencyTypeNotifier(this._settingsService) : super(CoachFrequencyType.time) {
    _load();
  }
  Future<void> _load() async => state = await _settingsService.getCoachFrequencyType();
  Future<void> setType(CoachFrequencyType type) async {
    await _settingsService.setCoachFrequencyType(type);
    state = type;
  }
}

/// Provider for the Coach time-based frequency (in minutes).
final coachTimeFrequencyProvider = StateNotifierProvider<CoachTimeFrequencyNotifier, double>((ref) {
  return CoachTimeFrequencyNotifier(ref.watch(settingsServiceProvider));
});

class CoachTimeFrequencyNotifier extends StateNotifier<double> {
  final SettingsService _settingsService;
  CoachTimeFrequencyNotifier(this._settingsService) : super(10.0) {
    _load();
  }
  Future<void> _load() async => state = await _settingsService.getCoachTimeFrequency();
  Future<void> setMinutes(double minutes) async {
    await _settingsService.setCoachTimeFrequency(minutes);
    state = minutes;
  }
}

/// Provider for the Coach distance-based frequency (in km/mi).
final coachDistanceFrequencyProvider = StateNotifierProvider<CoachDistanceFrequencyNotifier, double>((ref) {
  return CoachDistanceFrequencyNotifier(ref.watch(settingsServiceProvider));
});

class CoachDistanceFrequencyNotifier extends StateNotifier<double> {
  final SettingsService _settingsService;
  CoachDistanceFrequencyNotifier(this._settingsService) : super(1.0) {
    _load();
  }
  Future<void> _load() async => state = await _settingsService.getCoachDistanceFrequency();
  Future<void> setDistance(double distance) async {
    await _settingsService.setCoachDistanceFrequency(distance);
    state = distance;
  }
}

/// Provider for the set of stats the Coach will read out.
final coachStatsProvider = StateNotifierProvider<CoachStatsNotifier, Set<CoachStat>>((ref) {
  return CoachStatsNotifier(ref.watch(settingsServiceProvider));
});

class CoachStatsNotifier extends StateNotifier<Set<CoachStat>> {
  final SettingsService _settingsService;
  CoachStatsNotifier(this._settingsService) : super({CoachStat.pace, CoachStat.distance}) { // Default stats
    _load();
  }
  Future<void> _load() async => state = await _settingsService.getCoachStats();
  Future<void> toggleStat(CoachStat stat, bool enabled) async {
    final newState = Set<CoachStat>.from(state);
    if (enabled) {
      newState.add(stat);
    } else {
      newState.remove(stat);
    }
    await _settingsService.setCoachStats(newState);
    state = newState;
  }
}

/// Provider for coach voice language
final coachLanguageProvider = StateNotifierProvider<CoachLanguageNotifier, String>((ref) {
  return CoachLanguageNotifier(ref.watch(settingsServiceProvider));
});

class CoachLanguageNotifier extends StateNotifier<String> {
  final SettingsService _settingsService;
  CoachLanguageNotifier(this._settingsService) : super('en-US') {
    _load();
  }

  Future<void> _load() async => state = await _settingsService.getCoachLanguage();

  Future<void> setLanguage(String language) async {
    await _settingsService.setCoachLanguage(language);
    state = language;
  }
}
