import 'package:shared_preferences/shared_preferences.dart';
import '../../models/run_enums.dart';

enum DistanceUnit {
  kilometers,
  miles,
}

enum EnergyUnit {
  kcal,
  kj,
}

/// Gender options for fitness statistics
enum Gender {
  female,
  male,
  nonBinary,
  preferNotToSay,
}

class SettingsService {
  static const String _distanceUnitKey = 'distance_unit';
  static const String _energyUnitKey = 'energy_unit';
  static const String _appVolumeKey = 'app_volume';
  static const String _musicVolumeKey = 'music_volume';
  static const String _userWeightKgKey = 'user_weight_kg';
  static const String _userHeightCmKey = 'user_height_cm';
  static const String _userAgeKey = 'user_age_years';
  static const String _userGenderKey = 'user_gender';
  // Tracking configuration keys
  static const String _trackStrideMetersKey = 'track_stride_meters';
  static const String _trackSimPaceMinPerKmKey = 'track_sim_pace_min_per_km';
  static const String _trackingModeKey = 'tracking_mode';
  static const String _trackingEnabledKey = 'tracking_enabled';
  // Coach settings keys
  static const String _coachEnabledKey = 'coach_enabled';
  static const String _coachFrequencyTypeKey = 'coach_frequency_type';
  static const String _coachTimeFrequencyKey = 'coach_time_frequency';
  static const String _coachDistanceFrequencyKey = 'coach_distance_frequency';
  static const String _coachStatsKey = 'coach_stats';
  static const String _coachLanguageKey = 'coach_language';

  // Clip interval (scene spacing) keys
  static const String _clipIntervalModeKey = 'clip_interval_mode'; // 0=distance,1=time
  static const String _clipIntervalDistanceKmKey = 'clip_interval_distance_km';
  static const String _clipIntervalMinutesKey = 'clip_interval_minutes';

  // Default values
  static const DistanceUnit _defaultDistanceUnit = DistanceUnit.kilometers;
  static const EnergyUnit _defaultEnergyUnit = EnergyUnit.kcal;
  static const double _defaultAppVolume = 1.0;
  static const double _defaultMusicVolume = 1.0;
  static const double _defaultUserWeightKg = 70.0;
  static const int _defaultUserHeightCm = 170;
  static const int _defaultUserAgeYears = 30;
  static const Gender _defaultUserGender = Gender.preferNotToSay;
  // Defaults for tracking configs
  static const double _defaultStrideMeters = 1.0; // 1 m default stride
  static const double _defaultSimPaceMinPerKm = 6.0; // 6:00 /km
  static const double _defaultClipIntervalDistanceKm = 0.4; // 400 m
  static const double _defaultClipIntervalMinutes = 3.0; // 3 minutes
  // Defaults for coach settings
  static const bool _defaultCoachEnabled = true;
  static const CoachFrequencyType _defaultCoachFrequencyType = CoachFrequencyType.time;
  static const double _defaultCoachTimeFrequency = 10.0;
  static const double _defaultCoachDistanceFrequency = 1.0;
  static const Set<CoachStat> _defaultCoachStats = {CoachStat.pace, CoachStat.distance};
  static const String _defaultCoachLanguage = 'en-US';

  // Distance unit conversion constants
  static const double _kmToMiles = 0.621371;
  static const double _milesToKm = 1.60934;

  // Energy unit conversion constants
  static const double _kcalToKj = 4.184;
  static const double _kjToKcal = 0.239006;

  /// Get current distance unit
  Future<DistanceUnit> getDistanceUnit() async {
    final prefs = await SharedPreferences.getInstance();
    final unitIndex = prefs.getInt(_distanceUnitKey) ?? _defaultDistanceUnit.index;
    return DistanceUnit.values[unitIndex];
  }

  /// Set distance unit
  Future<void> setDistanceUnit(DistanceUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_distanceUnitKey, unit.index);
  }

  /// Get current energy unit
  Future<EnergyUnit> getEnergyUnit() async {
    final prefs = await SharedPreferences.getInstance();
    final unitIndex = prefs.getInt(_energyUnitKey) ?? _defaultEnergyUnit.index;
    return EnergyUnit.values[unitIndex];
  }

  /// Set energy unit
  Future<void> setEnergyUnit(EnergyUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_energyUnitKey, unit.index);
  }

  /// Get app volume (0.0 to 1.0)
  Future<double> getAppVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_appVolumeKey) ?? _defaultAppVolume;
  }

  /// Set app volume (0.0 to 1.0)
  Future<void> setAppVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_appVolumeKey, volume.clamp(0.0, 1.0));
  }

  /// Get music volume (0.0 to 1.0)
  Future<double> getMusicVolume() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_musicVolumeKey) ?? _defaultMusicVolume;
  }

  /// Set music volume (0.0 to 1.0)
  Future<void> setMusicVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_musicVolumeKey, volume.clamp(0.0, 1.0));
  }

  // -------- Fitness profile (weight, height, age, gender) --------

  /// Get user weight in kg
  Future<double> getUserWeightKg() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_userWeightKgKey) ?? _defaultUserWeightKg;
  }

  /// Set user weight in kg
  Future<void> setUserWeightKg(double weightKg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_userWeightKgKey, weightKg.clamp(30.0, 250.0));
  }

  /// Get user height in cm
  Future<int> getUserHeightCm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userHeightCmKey) ?? _defaultUserHeightCm;
  }

  /// Set user height in cm
  Future<void> setUserHeightCm(int heightCm) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = heightCm.clamp(100, 230);
    await prefs.setInt(_userHeightCmKey, clamped);
  }

  /// Get user age in years
  Future<int> getUserAgeYears() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userAgeKey) ?? _defaultUserAgeYears;
  }

  /// Set user age in years
  Future<void> setUserAgeYears(int ageYears) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = ageYears.clamp(10, 100);
    await prefs.setInt(_userAgeKey, clamped);
  }

  /// Get user gender
  Future<Gender> getUserGender() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_userGenderKey) ?? _defaultUserGender.index;
    return Gender.values[idx];
  }

  /// Set user gender
  Future<void> setUserGender(Gender gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userGenderKey, gender.index);
  }

  // Distance conversion methods
  /// Convert distance to current unit
  Future<double> convertDistance(double distanceInKm) async {
    final unit = await getDistanceUnit();
    return unit == DistanceUnit.miles ? distanceInKm * _kmToMiles : distanceInKm;
  }

  /// Convert distance from current unit to km
  Future<double> convertDistanceToKm(double distance) async {
    final unit = await getDistanceUnit();
    return unit == DistanceUnit.miles ? distance * _milesToKm : distance;
  }

  /// Get distance unit symbol
  Future<String> getDistanceUnitSymbol() async {
    final unit = await getDistanceUnit();
    return unit == DistanceUnit.miles ? 'mi' : 'km';
  }

  /// Get distance unit name
  Future<String> getDistanceUnitName() async {
    final unit = await getDistanceUnit();
    return unit == DistanceUnit.miles ? 'Miles' : 'Kilometres';
  }

  // Energy conversion methods
  /// Convert energy to current unit
  Future<double> convertEnergy(double energyInKcal) async {
    final unit = await getEnergyUnit();
    return unit == EnergyUnit.kj ? energyInKcal * _kcalToKj : energyInKcal;
  }

  /// Convert energy from current unit to kcal
  Future<double> convertEnergyToKcal(double energy) async {
    final unit = await getEnergyUnit();
    return unit == EnergyUnit.kj ? energy * _kjToKcal : energy;
  }

  /// Get energy unit symbol
  Future<String> getEnergyUnitSymbol() async {
    final unit = await getEnergyUnit();
    return unit == EnergyUnit.kj ? 'kJ' : 'kcal';
  }

  /// Get energy unit name
  Future<String> getEnergyUnitName() async {
    final unit = await getEnergyUnit();
    return unit == EnergyUnit.kj ? 'kJ' : 'kCal';
  }

  // Speed conversion methods
  /// Convert speed to current unit
  Future<double> convertSpeed(double speedInKmh) async {
    final unit = await getDistanceUnit();
    return unit == DistanceUnit.miles ? speedInKmh * _kmToMiles : speedInKmh;
  }

  /// Convert speed from current unit to km/h
  Future<double> convertSpeedToKmh(double speed) async {
    final unit = await getDistanceUnit();
    return unit == DistanceUnit.miles ? speed * _milesToKm : speed;
  }

  /// Get speed unit symbol
  Future<String> getSpeedUnitSymbol() async {
    final unit = await getDistanceUnit();
    return unit == DistanceUnit.miles ? 'mph' : 'km/h';
  }

  // Pace conversion methods
  /// Convert pace to current unit (minutes per distance unit)
  Future<double> convertPace(double paceInMinPerKm) async {
    final unit = await getDistanceUnit();
    return unit == DistanceUnit.miles ? paceInMinPerKm / _kmToMiles : paceInMinPerKm;
  }

  /// Convert pace from current unit to min/km
  Future<double> convertPaceToMinPerKm(double pace) async {
    final unit = await getDistanceUnit();
    return unit == DistanceUnit.miles ? pace * _kmToMiles : pace;
  }

  /// Get pace unit symbol
  Future<String> getPaceUnitSymbol() async {
    final unit = await getDistanceUnit();
    return unit == DistanceUnit.miles ? 'min/mi' : 'min/km';
  }

  /// Format distance with unit
  Future<String> formatDistance(double distanceInKm) async {
    final convertedDistance = await convertDistance(distanceInKm);
    final unit = await getDistanceUnitSymbol();
    return '${convertedDistance.toStringAsFixed(2)} $unit';
  }

  /// Format energy with unit
  Future<String> formatEnergy(double energyInKcal) async {
    final convertedEnergy = await convertEnergy(energyInKcal);
    final unit = await getEnergyUnitSymbol();
    return '${convertedEnergy.toStringAsFixed(0)} $unit';
  }

  /// Format speed with unit
  Future<String> formatSpeed(double speedInKmh) async {
    final convertedSpeed = await convertSpeed(speedInKmh);
    final unit = await getSpeedUnitSymbol();
    return '${convertedSpeed.toStringAsFixed(1)} $unit';
  }

  /// Format pace with unit
  Future<String> formatPace(double paceInMinPerKm) async {
    final convertedPace = await convertPace(paceInMinPerKm);
    final unit = await getPaceUnitSymbol();
    return '${convertedPace.toStringAsFixed(1)} $unit';
  }

  // ---------- Tracking configuration: Step stride + Simulate pace ----------

  /// Get saved stride length (meters per step)
  Future<double> getStrideLengthMeters() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_trackStrideMetersKey) ?? _defaultStrideMeters;
  }

  /// Set stride length (meters per step)
  Future<void> setStrideLengthMeters(double meters) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_trackStrideMetersKey, meters.clamp(0.3, 2.5));
  }

  /// Get saved simulate running pace (minutes per kilometer)
  Future<double> getSimulatePaceMinPerKm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_trackSimPaceMinPerKmKey) ?? _defaultSimPaceMinPerKm;
  }

  /// Set simulate running pace (minutes per kilometer)
  Future<void> setSimulatePaceMinPerKm(double minPerKm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_trackSimPaceMinPerKmKey, minPerKm.clamp(3.0, 20.0));
  }

  /// Persist tracking mode (enum index)
  Future<void> setTrackingModeIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_trackingModeKey, index);
  }

  /// Get stored tracking mode index (or null if not set)
  Future<int?> getTrackingModeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_trackingModeKey);
  }

  /// Tracking enabled on/off
  Future<void> setTrackingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_trackingEnabledKey, enabled);
  }

  Future<bool> getTrackingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_trackingEnabledKey) ?? true;
  }

  // ---------- Scene clip interval preferences ----------
  Future<int> getClipIntervalModeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_clipIntervalModeKey) ?? 0;
  }
  Future<void> setClipIntervalModeIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_clipIntervalModeKey, index.clamp(0, 1));
  }
  Future<double> getClipIntervalDistanceKm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_clipIntervalDistanceKmKey) ?? _defaultClipIntervalDistanceKm;
  }
  Future<void> setClipIntervalDistanceKm(double km) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_clipIntervalDistanceKmKey, km.clamp(0.1, 10.0));
  }
  Future<double> getClipIntervalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_clipIntervalMinutesKey) ?? _defaultClipIntervalMinutes;
  }
  Future<void> setClipIntervalMinutes(double minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_clipIntervalMinutesKey, minutes.clamp(0.5, 30.0));
  }

  // ---------- Coach Settings ----------

  Future<bool> getCoachEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_coachEnabledKey) ?? _defaultCoachEnabled;
  }

  Future<void> setCoachEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_coachEnabledKey, enabled);
  }

  Future<CoachFrequencyType> getCoachFrequencyType() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_coachFrequencyTypeKey) ?? _defaultCoachFrequencyType.index;
    return CoachFrequencyType.values[index];
  }

  Future<void> setCoachFrequencyType(CoachFrequencyType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_coachFrequencyTypeKey, type.index);
  }

  Future<double> getCoachTimeFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_coachTimeFrequencyKey) ?? _defaultCoachTimeFrequency;
  }

  Future<void> setCoachTimeFrequency(double minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_coachTimeFrequencyKey, minutes);
  }

  Future<double> getCoachDistanceFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_coachDistanceFrequencyKey) ?? _defaultCoachDistanceFrequency;
  }

  Future<void> setCoachDistanceFrequency(double distance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_coachDistanceFrequencyKey, distance);
  }

  Future<Set<CoachStat>> getCoachStats() async {
    final prefs = await SharedPreferences.getInstance();
    final statsStringList = prefs.getStringList(_coachStatsKey);
    if (statsStringList == null) return _defaultCoachStats;
    return statsStringList.map((s) => CoachStat.values.firstWhere((e) => e.name == s)).toSet();
  }

  Future<void> setCoachStats(Set<CoachStat> stats) async {
    final prefs = await SharedPreferences.getInstance();
    final statsStringList = stats.map((s) => s.name).toList();
    await prefs.setStringList(_coachStatsKey, statsStringList);
  }

  Future<String> getCoachLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_coachLanguageKey) ?? _defaultCoachLanguage;
  }

  Future<void> setCoachLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_coachLanguageKey, language);
  }
}
