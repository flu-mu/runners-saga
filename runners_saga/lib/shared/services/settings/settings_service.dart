import 'package:shared_preferences/shared_preferences.dart';

enum DistanceUnit {
  kilometers,
  miles,
}

enum EnergyUnit {
  kcal,
  kj,
}

class SettingsService {
  static const String _distanceUnitKey = 'distance_unit';
  static const String _energyUnitKey = 'energy_unit';
  static const String _appVolumeKey = 'app_volume';
  static const String _musicVolumeKey = 'music_volume';

  // Default values
  static const DistanceUnit _defaultDistanceUnit = DistanceUnit.kilometers;
  static const EnergyUnit _defaultEnergyUnit = EnergyUnit.kcal;
  static const double _defaultAppVolume = 1.0;
  static const double _defaultMusicVolume = 1.0;

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
}

