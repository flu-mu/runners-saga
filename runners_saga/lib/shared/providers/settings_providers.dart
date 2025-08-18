import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

enum UnitSystem { km, mi }
enum TrackingMode { gps, steps, simulate }
enum SprintIntensity { off, light, moderate, hard }
enum MusicSource { external, app, none }

final unitSystemProvider = StateProvider<UnitSystem>((ref) => UnitSystem.km);
final trackingModeProvider = StateProvider<TrackingMode>((ref) => TrackingMode.gps);
final sprintIntensityProvider = StateProvider<SprintIntensity>((ref) => SprintIntensity.off);
final musicSourceProvider = StateProvider<MusicSource>((ref) => MusicSource.external);

/// User weight (kg). Fallback used by calorie calculations.
final userWeightKgProvider = StateProvider<double>((ref) => 70.0);


