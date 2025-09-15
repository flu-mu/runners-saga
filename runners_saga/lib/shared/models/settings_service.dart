import 'package:shared_preferences/shared_preferences.dart';
import '../../models/run_enums.dart';

enum DistanceUnit { kilometers, miles }
enum EnergyUnit { kcal, kj }
enum Gender { female, male, nonBinary, preferNotToSay }

class SettingsService {
  static const String _distanceUnitKey = 'distance_unit';
  static const String _energyUnitKey = 'energy_unit';
  static const String _appVolumeKey = 'app_volume';
  static const String _musicVolumeKey = 'music_volume';
  static const String _userWeightKgKey = 'user_weight_kg';
  static const String _userHeightCmKey = 'user_height_cm';
  static const String _userAgeYearsKey = 'user_age_years';
  static const String _userGenderKey = 'user_gender';
  static const String _trackingModeKey = 'tracking_mode';
  static const String _trackingEnabledKey = 'tracking_enabled';
  static const String _strideLengthKey = 'stride_length';
  static const String _simulatePaceKey = 'simulate_pace';
  static const String _clipIntervalModeKey = 'clip_interval_mode';
  static const String _clipIntervalDistanceKey = 'clip_interval_distance';
  static const String _clipIntervalMinutesKey = 'clip_interval_minutes';

  // Coach settings keys
  static const String _coachEnabledKey = 'coach_enabled';
  static const String _coachFrequencyTypeKey = 'coach_frequency_type';
  static const String _coachTimeFrequencyKey = 'coach_time_frequency';
  static const String _coachDistanceFrequencyKey = 'coach_distance_frequency';
  static const String _coachStatsKey = 'coach_stats';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // --- Existing Methods (assumed) ---

  Future<DistanceUnit> getDistanceUnit() async {
    final prefs = await _prefs;
    final unit = prefs.getString(_distanceUnitKey);
    return unit == 'miles' ? DistanceUnit.miles : DistanceUnit.kilometers;
  }

  Future<void> setDistanceUnit(DistanceUnit unit) async {
    final prefs = await _prefs;
    await prefs.setString(_distanceUnitKey, unit == DistanceUnit.miles ? 'miles' : 'kilometers');
  }

  Future<EnergyUnit> getEnergyUnit() async {
    final prefs = await _prefs;
    final unit = prefs.getString(_energyUnitKey);
    return unit == 'kj' ? EnergyUnit.kj : EnergyUnit.kcal;
  }

  Future<void> setEnergyUnit(EnergyUnit unit) async {
    final prefs = await _prefs;
    await prefs.setString(_energyUnitKey, unit == EnergyUnit.kj ? 'kj' : 'kcal');
  }

  Future<double> getAppVolume() async => (await _prefs).getDouble(_appVolumeKey) ?? 1.0;
  Future<void> setAppVolume(double volume) async => (await _prefs).setDouble(_appVolumeKey, volume);

  Future<double> getMusicVolume() async => (await _prefs).getDouble(_musicVolumeKey) ?? 1.0;
  Future<void> setMusicVolume(double volume) async => (await _prefs).setDouble(_musicVolumeKey, volume);

  Future<double?> getUserWeightKg() async => (await _prefs).getDouble(_userWeightKgKey);
  Future<void> setUserWeightKg(double weight) async => (await _prefs).setDouble(_userWeightKgKey, weight);

  Future<int> getUserHeightCm() async => (await _prefs).getInt(_userHeightCmKey) ?? 170;
  Future<void> setUserHeightCm(int height) async => (await _prefs).setInt(_userHeightCmKey, height);

  Future<int> getUserAgeYears() async => (await _prefs).getInt(_userAgeYearsKey) ?? 30;
  Future<void> setUserAgeYears(int age) async => (await _prefs).setInt(_userAgeYearsKey, age);

  Future<Gender> getUserGender() async {
    final genderString = (await _prefs).getString(_userGenderKey);
    return Gender.values.firstWhere((g) => g.name == genderString, orElse: () => Gender.preferNotToSay);
  }

  Future<void> setUserGender(Gender gender) async => (await _prefs).setString(_userGenderKey, gender.name);

  Future<int?> getTrackingModeIndex() async => (await _prefs).getInt(_trackingModeKey);
  Future<void> setTrackingModeIndex(int index) async => (await _prefs).setInt(_trackingModeKey, index);

  Future<bool> getTrackingEnabled() async => (await _prefs).getBool(_trackingEnabledKey) ?? true;
  Future<void> setTrackingEnabled(bool enabled) async => (await _prefs).setBool(_trackingEnabledKey, enabled);

  Future<double> getStrideLengthMeters() async => (await _prefs).getDouble(_strideLengthKey) ?? 1.0;
  Future<void> setStrideLengthMeters(double meters) async => (await _prefs).setDouble(_strideLengthKey, meters);

  Future<double> getSimulatePaceMinPerKm() async => (await _prefs).getDouble(_simulatePaceKey) ?? 6.0;
  Future<void> setSimulatePaceMinPerKm(double pace) async => (await _prefs).setDouble(_simulatePaceKey, pace);

  Future<int> getClipIntervalModeIndex() async => (await _prefs).getInt(_clipIntervalModeKey) ?? 0;
  Future<void> setClipIntervalModeIndex(int index) async => (await _prefs).setInt(_clipIntervalModeKey, index);

  Future<double> getClipIntervalDistanceKm() async => (await _prefs).getDouble(_clipIntervalDistanceKey) ?? 0.4;
  Future<void> setClipIntervalDistanceKm(double km) async => (await _prefs).setDouble(_clipIntervalDistanceKey, km);

  Future<double> getClipIntervalMinutes() async => (await _prefs).getDouble(_clipIntervalMinutesKey) ?? 3.0;
  Future<void> setClipIntervalMinutes(double minutes) async => (await _prefs).setDouble(_clipIntervalMinutesKey, minutes);

  Future<String> formatDistance(double distanceInKm) async {
    final unit = await getDistanceUnit();
    if (unit == DistanceUnit.miles) {
      return '${(distanceInKm * 0.621371).toStringAsFixed(2)} mi';
    }
    return '${distanceInKm.toStringAsFixed(2)} km';
  }

  Future<String> formatPace(double paceInMinPerKm) async {
    final unit = await getDistanceUnit();
    double pace = paceInMinPerKm;
    String unitSymbol = 'min/km';
    if (unit == DistanceUnit.miles) {
      pace /= 0.621371;
      unitSymbol = 'min/mi';
    }
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} $unitSymbol';
  }

  Future<String> formatSpeed(double speedInKmh) async {
    final unit = await getDistanceUnit();
    if (unit == DistanceUnit.miles) {
      return '${(speedInKmh * 0.621371).toStringAsFixed(1)} mph';
    }
    return '${speedInKmh.toStringAsFixed(1)} km/h';
  }

  Future<String> formatEnergy(double energyInKcal) async {
    final unit = await getEnergyUnit();
    if (unit == EnergyUnit.kj) {
      return '${(energyInKcal * 4.184).toStringAsFixed(0)} kJ';
    }
    return '${energyInKcal.toStringAsFixed(0)} kcal';
  }

  // --- New Coach Methods ---

  Future<bool> getCoachEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_coachEnabledKey) ?? true;
  }

  Future<void> setCoachEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_coachEnabledKey, enabled);
  }

  Future<CoachFrequencyType> getCoachFrequencyType() async {
    final prefs = await _prefs;
    final typeString = prefs.getString(_coachFrequencyTypeKey);
    return typeString == 'distance' ? CoachFrequencyType.distance : CoachFrequencyType.time;
  }

  Future<void> setCoachFrequencyType(CoachFrequencyType type) async {
    final prefs = await _prefs;
    await prefs.setString(_coachFrequencyTypeKey, type.name);
  }

  Future<double> getCoachTimeFrequency() async {
    final prefs = await _prefs;
    return prefs.getDouble(_coachTimeFrequencyKey) ?? 10.0;
  }

  Future<void> setCoachTimeFrequency(double minutes) async {
    final prefs = await _prefs;
    await prefs.setDouble(_coachTimeFrequencyKey, minutes);
  }

  Future<double> getCoachDistanceFrequency() async {
    final prefs = await _prefs;
    return prefs.getDouble(_coachDistanceFrequencyKey) ?? 1.0;
  }

  Future<void> setCoachDistanceFrequency(double distance) async {
    final prefs = await _prefs;
    await prefs.setDouble(_coachDistanceFrequencyKey, distance);
  }

  Future<Set<CoachStat>> getCoachStats() async {
    final prefs = await _prefs;
    final statsList = prefs.getStringList(_coachStatsKey);
    if (statsList == null) {
      // Default stats
      return {CoachStat.pace, CoachStat.distance};
    }
    return statsList.map((s) => CoachStat.values.firstWhere((e) => e.name == s)).toSet();
  }

  Future<void> setCoachStats(Set<CoachStat> stats) async {
    final prefs = await _prefs;
    final statsList = stats.map((s) => s.name).toList();
    await prefs.setStringList(_coachStatsKey, statsList);
  }
}