import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings/settings_service.dart';
import '../services/run_conversion_service.dart';
import 'auth_providers.dart';

// Settings service provider
final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService();
});

// Distance unit provider
final distanceUnitProvider = StateNotifierProvider<DistanceUnitNotifier, DistanceUnit>((ref) {
  final settingsService = ref.read(settingsServiceProvider);
  return DistanceUnitNotifier(settingsService);
});

// Energy unit provider
final energyUnitProvider = StateNotifierProvider<EnergyUnitNotifier, EnergyUnit>((ref) {
  final settingsService = ref.read(settingsServiceProvider);
  return EnergyUnitNotifier(settingsService);
});

// App volume provider
final appVolumeProvider = StateNotifierProvider<AppVolumeNotifier, double>((ref) {
  final settingsService = ref.read(settingsServiceProvider);
  return AppVolumeNotifier(settingsService);
});

// Music volume provider
final musicVolumeProvider = StateNotifierProvider<MusicVolumeNotifier, double>((ref) {
  final settingsService = ref.read(settingsServiceProvider);
  return MusicVolumeNotifier(settingsService);
});

// Distance unit notifier
class DistanceUnitNotifier extends StateNotifier<DistanceUnit> {
  final SettingsService _settingsService;
  final RunConversionService _conversionService = RunConversionService();

  DistanceUnitNotifier(this._settingsService) : super(DistanceUnit.kilometers) {
    _loadDistanceUnit();
  }

  Future<void> _loadDistanceUnit() async {
    state = await _settingsService.getDistanceUnit();
  }

  Future<void> setDistanceUnit(DistanceUnit unit) async {
    await _settingsService.setDistanceUnit(unit);
    state = unit;
    
    // Trigger conversion of historical runs if needed
    _triggerHistoricalRunConversion();
  }

  Future<void> _triggerHistoricalRunConversion() async {
    try {
      // This would need to be called with the current user ID
      // For now, we'll handle this in the UI when settings change
      print('🔄 DistanceUnitNotifier: Unit changed, historical run conversion may be needed');
    } catch (e) {
      print('⚠️ DistanceUnitNotifier: Error triggering conversion: $e');
    }
  }
}

// Energy unit notifier
class EnergyUnitNotifier extends StateNotifier<EnergyUnit> {
  final SettingsService _settingsService;
  final RunConversionService _conversionService = RunConversionService();

  EnergyUnitNotifier(this._settingsService) : super(EnergyUnit.kcal) {
    _loadEnergyUnit();
  }

  Future<void> _loadEnergyUnit() async {
    state = await _settingsService.getEnergyUnit();
  }

  Future<void> setEnergyUnit(EnergyUnit unit) async {
    await _settingsService.setEnergyUnit(unit);
    state = unit;
    
    // Trigger conversion of historical runs if needed
    _triggerHistoricalRunConversion();
  }

  Future<void> _triggerHistoricalRunConversion() async {
    try {
      // This would need to be called with the current user ID
      // For now, we'll handle this in the UI when settings change
      print('🔄 EnergyUnitNotifier: Unit changed, historical run conversion may be needed');
    } catch (e) {
      print('⚠️ EnergyUnitNotifier: Error triggering conversion: $e');
    }
  }
}

// App volume notifier
class AppVolumeNotifier extends StateNotifier<double> {
  final SettingsService _settingsService;

  AppVolumeNotifier(this._settingsService) : super(1.0) {
    _loadAppVolume();
  }

  Future<void> _loadAppVolume() async {
    state = await _settingsService.getAppVolume();
  }

  Future<void> setAppVolume(double volume) async {
    await _settingsService.setAppVolume(volume);
    state = volume;
  }
}

// Music volume notifier
class MusicVolumeNotifier extends StateNotifier<double> {
  final SettingsService _settingsService;

  MusicVolumeNotifier(this._settingsService) : super(1.0) {
    _loadMusicVolume();
  }

  Future<void> _loadMusicVolume() async {
    state = await _settingsService.getMusicVolume();
  }

  Future<void> setMusicVolume(double volume) async {
    await _settingsService.setMusicVolume(volume);
    state = volume;
  }
}