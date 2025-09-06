import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/run_model.dart';
import 'settings/settings_service.dart';

class RunConversionService {
  final SettingsService _settingsService = SettingsService();

  /// Convert all historical runs to use the current user's preferred units
  /// This should be called when the user changes their unit preferences
  Future<void> convertHistoricalRuns(String userId) async {
    try {
      print('🔄 RunConversionService: Starting conversion of historical runs for user: $userId');
      
      // Get all runs for the user
      final runsSnapshot = await FirebaseFirestore.instance
          .collection('runs')
          .where('userId', isEqualTo: userId)
          .get();

      print('🔄 RunConversionService: Found ${runsSnapshot.docs.length} runs to convert');

      // Get current user preferences
      final distanceUnit = await _settingsService.getDistanceUnit();
      final energyUnit = await _settingsService.getEnergyUnit();

      print('🔄 RunConversionService: Converting to distance unit: $distanceUnit, energy unit: $energyUnit');

      // Convert each run
      for (final doc in runsSnapshot.docs) {
        try {
          final runData = doc.data();
          final run = RunModel.fromJson(runData);
          
          // Convert the run data
          final convertedRun = await _convertRunToCurrentUnits(run);
          
          // Update the run in Firebase
          await doc.reference.update(convertedRun.toFirestore());
          
          print('✅ RunConversionService: Converted run ${doc.id}');
        } catch (e) {
          print('⚠️ RunConversionService: Failed to convert run ${doc.id}: $e');
          // Continue with other runs
        }
      }

      print('✅ RunConversionService: Historical run conversion completed');
    } catch (e) {
      print('❌ RunConversionService: Error converting historical runs: $e');
      throw Exception('Failed to convert historical runs: $e');
    }
  }

  /// Convert a single run to use the current user's preferred units
  Future<RunModel> _convertRunToCurrentUnits(RunModel run) async {
    final distanceUnit = await _settingsService.getDistanceUnit();
    final energyUnit = await _settingsService.getEnergyUnit();

    // Convert distance
    double? convertedDistance;
    if (run.totalDistance != null) {
      convertedDistance = await _settingsService.convertDistance(run.totalDistance!);
    }

    // Convert pace (this is more complex as it depends on distance unit)
    double? convertedPace;
    if (run.averagePace != null) {
      convertedPace = await _settingsService.convertPace(run.averagePace!);
    }

    double? convertedMaxPace;
    if (run.maxPace != null) {
      convertedMaxPace = await _settingsService.convertPace(run.maxPace!);
    }

    double? convertedMinPace;
    if (run.minPace != null) {
      convertedMinPace = await _settingsService.convertPace(run.minPace!);
    }

    // Convert speed
    double? convertedMaxSpeed;
    if (run.maxSpeed != null) {
      convertedMaxSpeed = await _settingsService.convertSpeed(run.maxSpeed!);
    }

    // Convert energy
    double? convertedCalories;
    if (run.caloriesBurned != null) {
      convertedCalories = await _settingsService.convertEnergy(run.caloriesBurned!);
    }

    // Return the converted run
    return run.copyWith(
      totalDistance: convertedDistance,
      averagePace: convertedPace,
      maxPace: convertedMaxPace,
      minPace: convertedMinPace,
      maxSpeed: convertedMaxSpeed,
      caloriesBurned: convertedCalories,
    );
  }

  /// Check if runs need conversion based on stored unit preferences
  Future<bool> needsConversion(String userId) async {
    try {
      // Get user's stored unit preferences
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        return false; // No user document, no conversion needed
      }

      final userData = userDoc.data();
      final storedDistanceUnit = userData?['distanceUnit'] as String?;
      final storedEnergyUnit = userData?['energyUnit'] as String?;

      // Get current preferences
      final currentDistanceUnit = await _settingsService.getDistanceUnit();
      final currentEnergyUnit = await _settingsService.getEnergyUnit();

      // Check if units have changed
      final distanceChanged = storedDistanceUnit != currentDistanceUnit.name;
      final energyChanged = storedEnergyUnit != currentEnergyUnit.name;

      return distanceChanged || energyChanged;
    } catch (e) {
      print('⚠️ RunConversionService: Error checking conversion needs: $e');
      return false;
    }
  }

  /// Save current unit preferences to user document
  Future<void> saveUnitPreferences(String userId) async {
    try {
      final distanceUnit = await _settingsService.getDistanceUnit();
      final energyUnit = await _settingsService.getEnergyUnit();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'distanceUnit': distanceUnit.name,
        'energyUnit': energyUnit.name,
        'lastUnitUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ RunConversionService: Saved unit preferences for user: $userId');
    } catch (e) {
      print('❌ RunConversionService: Error saving unit preferences: $e');
      throw Exception('Failed to save unit preferences: $e');
    }
  }
}











