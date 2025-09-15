enum TrackingMode {
  gps,
  steps,
  simulate,
}

enum SprintIntensity {
  off,
  light,
  moderate,
  hard,
}

enum MusicSource {
  external,
  internal,
}

// How to space story clips during a workout
enum ClipIntervalMode {
  distance, // play clips every X km/mi
  time,     // play clips every X minutes
}

// --- Coach Feature Enums ---

enum CoachFrequencyType {
  time,
  distance,
}

enum CoachStat {
  pace,
  distance,
  time,
  splitPace,
  heartRate,
}

extension TrackingModeExtension on TrackingMode {
  String get name {
    switch (this) {
      case TrackingMode.gps:
        return 'GPS';
      case TrackingMode.steps:
        return 'Step Counting';
      case TrackingMode.simulate:
        return 'Simulate';
    }
  }
}

extension SprintIntensityExtension on SprintIntensity {
  String get name {
    switch (this) {
      case SprintIntensity.off:
        return 'Off';
      case SprintIntensity.light:
        return 'Light';
      case SprintIntensity.moderate:
        return 'Moderate';
      case SprintIntensity.hard:
        return 'Hard';
    }
  }
}

extension MusicSourceExtension on MusicSource {
  String get name {
    switch (this) {
      case MusicSource.external:
        return 'External Player';
      case MusicSource.internal:
        return 'Internal Player';
    }
  }
}
