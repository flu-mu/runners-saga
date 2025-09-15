import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings/settings_service.dart';
import 'settings_providers.dart';
import '../models/run_enums.dart';
import '../services/settings/settings_service.dart';

// Tracking mode provider
final trackingModeProvider = StateNotifierProvider<TrackingModeNotifier, TrackingMode?>((ref) {
  final settingsService = ref.read(settingsServiceProvider);
  return TrackingModeNotifier(settingsService);
});

// Sprint intensity provider
final sprintIntensityProvider = StateNotifierProvider<SprintIntensityNotifier, SprintIntensity?>((ref) {
  return SprintIntensityNotifier();
});

// Music source provider
final musicSourceProvider = StateNotifierProvider<MusicSourceNotifier, MusicSource?>((ref) {
  return MusicSourceNotifier();
});

// User weight provider
final userWeightKgProvider = StateNotifierProvider<UserWeightNotifier, double?>((ref) {
  final settingsService = ref.read(settingsServiceProvider);
  return UserWeightNotifier(settingsService);
});

// Step stride length provider (meters per step)
final stepStrideMetersProvider = StateNotifierProvider<StepStrideNotifier, double>((ref) {
  final settingsService = ref.read(settingsServiceProvider);
  return StepStrideNotifier(settingsService);
});

// Simulate running pace provider (minutes per kilometer)
final simulatePaceMinPerKmProvider = StateNotifierProvider<SimulatePaceNotifier, double>((ref) {
  final settingsService = ref.read(settingsServiceProvider);
  return SimulatePaceNotifier(settingsService);
});

// Unit system provider (for backward compatibility)
final unitSystemProvider = StateNotifierProvider<UnitSystemNotifier, String>((ref) {
  return UnitSystemNotifier();
});

// Clip interval mode (distance or time)
final clipIntervalModeProvider = StateNotifierProvider<ClipIntervalModeNotifier, ClipIntervalMode>((ref) {
  final settings = ref.read(settingsServiceProvider);
  return ClipIntervalModeNotifier(settings);
});

// Clip interval distance (km)
final clipIntervalDistanceKmProvider = StateNotifierProvider<ClipIntervalDistanceNotifier, double>((ref) {
  final settings = ref.read(settingsServiceProvider);
  return ClipIntervalDistanceNotifier(settings);
});

// Clip interval time (minutes)
final clipIntervalMinutesProvider = StateNotifierProvider<ClipIntervalMinutesNotifier, double>((ref) {
  final settings = ref.read(settingsServiceProvider);
  return ClipIntervalMinutesNotifier(settings);
});

// Tracking mode notifier
class TrackingModeNotifier extends StateNotifier<TrackingMode?> {
  final SettingsService _settingsService;
  TrackingModeNotifier(this._settingsService) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final idx = await _settingsService.getTrackingModeIndex();
    if (idx != null && idx >= 0 && idx < TrackingMode.values.length) {
      state = TrackingMode.values[idx];
    } else {
      state = TrackingMode.gps; // default
    }
  }

  Future<void> setTrackingMode(TrackingMode mode) async {
    state = mode;
    await _settingsService.setTrackingModeIndex(mode.index);
  }
}

// Sprint intensity notifier
class SprintIntensityNotifier extends StateNotifier<SprintIntensity?> {
  SprintIntensityNotifier() : super(null);

  void setSprintIntensity(SprintIntensity intensity) {
    state = intensity;
  }
}

// Music source notifier
class MusicSourceNotifier extends StateNotifier<MusicSource?> {
  MusicSourceNotifier() : super(null);

  void setMusicSource(MusicSource source) {
    state = source;
  }
}

// User weight notifier
class UserWeightNotifier extends StateNotifier<double?> {
  final SettingsService _settingsService;

  UserWeightNotifier(this._settingsService) : super(null) {
    _load();
  }

  Future<void> _load() async {
    // Load stored weight if available
    final stored = await _settingsService.getUserWeightKg();
    state = stored;
  }

  void setUserWeight(double weight) {
    state = weight;
  }
}

// Unit system notifier
class UnitSystemNotifier extends StateNotifier<String> {
  UnitSystemNotifier() : super('metric');

  void setUnitSystem(String unit) {
    state = unit;
  }
}

// Master tracking enabled toggle
final trackingEnabledProvider = StateNotifierProvider<TrackingEnabledNotifier, bool>((ref) {
  final settingsService = ref.read(settingsServiceProvider);
  return TrackingEnabledNotifier(settingsService);
});

class TrackingEnabledNotifier extends StateNotifier<bool> {
  final SettingsService _settingsService;
  TrackingEnabledNotifier(this._settingsService) : super(true) {
    _load();
  }

  Future<void> _load() async {
    state = await _settingsService.getTrackingEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _settingsService.setTrackingEnabled(enabled);
  }
}

// --- Tracking configuration notifiers ---

class StepStrideNotifier extends StateNotifier<double> {
  final SettingsService _settingsService;
  StepStrideNotifier(this._settingsService) : super(1.0) {
    _load();
  }

  Future<void> _load() async {
    final value = await _settingsService.getStrideLengthMeters();
    state = value;
  }

  Future<void> setStride(double meters) async {
    state = meters;
    await _settingsService.setStrideLengthMeters(meters);
  }
}

class SimulatePaceNotifier extends StateNotifier<double> {
  final SettingsService _settingsService;
  SimulatePaceNotifier(this._settingsService) : super(6.0) {
    _load();
  }

  Future<void> _load() async {
    final value = await _settingsService.getSimulatePaceMinPerKm();
    state = value;
  }

  Future<void> setPace(double minPerKm) async {
    state = minPerKm;
    await _settingsService.setSimulatePaceMinPerKm(minPerKm);
  }
}

// --- Clip interval configuration notifiers ---

class ClipIntervalModeNotifier extends StateNotifier<ClipIntervalMode> {
  final SettingsService _settingsService;
  ClipIntervalModeNotifier(this._settingsService) : super(ClipIntervalMode.distance) {
    _load();
  }
  Future<void> _load() async {
    final index = await _settingsService.getClipIntervalModeIndex();
    state = index == 1 ? ClipIntervalMode.time : ClipIntervalMode.distance;
  }
  Future<void> setMode(ClipIntervalMode mode) async {
    state = mode;
    await _settingsService.setClipIntervalModeIndex(mode == ClipIntervalMode.time ? 1 : 0);
  }
}

class ClipIntervalDistanceNotifier extends StateNotifier<double> {
  final SettingsService _settingsService;
  ClipIntervalDistanceNotifier(this._settingsService) : super(0.4) {
    _load();
  }
  Future<void> _load() async {
    state = await _settingsService.getClipIntervalDistanceKm();
  }
  Future<void> setKm(double km) async {
    state = km;
    await _settingsService.setClipIntervalDistanceKm(km);
  }
}

class ClipIntervalMinutesNotifier extends StateNotifier<double> {
  final SettingsService _settingsService;
  ClipIntervalMinutesNotifier(this._settingsService) : super(3.0) {
    _load();
  }
  Future<void> _load() async {
    state = await _settingsService.getClipIntervalMinutes();
  }
  Future<void> setMinutes(double minutes) async {
    state = minutes;
    await _settingsService.setClipIntervalMinutes(minutes);
  }
}







