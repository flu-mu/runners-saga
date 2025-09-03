import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/run_enums.dart';

// Tracking mode provider
final trackingModeProvider = StateNotifierProvider<TrackingModeNotifier, TrackingMode?>((ref) {
  return TrackingModeNotifier();
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
  return UserWeightNotifier();
});

// Unit system provider (for backward compatibility)
final unitSystemProvider = StateNotifierProvider<UnitSystemNotifier, String>((ref) {
  return UnitSystemNotifier();
});

// Tracking mode notifier
class TrackingModeNotifier extends StateNotifier<TrackingMode?> {
  TrackingModeNotifier() : super(null);

  void setTrackingMode(TrackingMode mode) {
    state = mode;
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
  UserWeightNotifier() : super(null);

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

