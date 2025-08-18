import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'run_target_model.freezed.dart';
part 'run_target_model.g.dart';

enum RunTargetType {
  time,
  distance,
}

@freezed
class RunTarget with _$RunTarget {
  @JsonSerializable(explicitToJson: true)
  const factory RunTarget({
    required String id,
    required RunTargetType type,
    required double value, // minutes for time, kilometers for distance
    required String displayName, // e.g., "20 minutes", "5 km"
    required String description, // e.g., "Quick morning run", "5K training"
    @JsonKey(fromJson: _timestampToDateTime, toJson: _dateTimeToTimestamp)
    required DateTime createdAt,
    required bool isCustom,
    Map<String, dynamic>? metadata,
  }) = _RunTarget;

  const RunTarget._();

  factory RunTarget.fromJson(Map<String, dynamic> json) => _$RunTargetFromJson(json);

  // Predefined run targets
  static final List<RunTarget> predefinedTargets = [
    RunTarget(
      id: 'quick_15',
      type: RunTargetType.time,
      value: 15.0,
      displayName: '15 minutes',
      description: 'Quick morning run',
      createdAt: DateTime(2025, 1, 1),
      isCustom: false,
    ),
    RunTarget(
      id: 'standard_30',
      type: RunTargetType.time,
      value: 30.0,
      displayName: '30 minutes',
      description: 'Standard workout',
      createdAt: DateTime(2025, 1, 1),
      isCustom: false,
    ),
    RunTarget(
      id: 'endurance_60',
      type: RunTargetType.time,
      value: 60.0,
      displayName: '1 hour',
      description: 'Endurance training',
      createdAt: DateTime(2025, 1, 1),
      isCustom: false,
    ),
    RunTarget(
      id: 'km_5',
      type: RunTargetType.distance,
      value: 5.0,
      displayName: '5 km',
      description: 'Quick sprint',
      createdAt: DateTime(2025, 1, 1),
      isCustom: false,
    ),
    RunTarget(
      id: 'km_10',
      type: RunTargetType.distance,
      value: 10.0,
      displayName: '10 km',
      description: 'Race preparation',
      createdAt: DateTime(2025, 1, 1),
      isCustom: false,
    ),
    RunTarget(
      id: 'km_15',
      type: RunTargetType.distance,
      value: 15.0,
      displayName: '15 km',
      description: 'Long distance training',
      createdAt: DateTime(2025, 1, 1),
      isCustom: false,
    ),
  ];

  // Helper methods
  Duration get duration {
    if (type == RunTargetType.time) {
      return Duration(minutes: value.toInt());
    }
    // Default to 30 minutes for distance-based targets
    return const Duration(minutes: 30);
  }

  double get distanceInKm {
    if (type == RunTargetType.distance) {
      return value;
    }
    // Estimate distance based on time (assuming 6 min/km pace)
    return value / 6.0;
  }

  double get distanceInMiles {
    if (type == RunTargetType.distance) {
      return value * 0.621371; // Convert km to miles
    }
    // Estimate distance based on time (assuming 10 min/mile pace)
    return value / 10.0;
  }

  String get typeLabel {
    return type == RunTargetType.time ? 'Time' : 'Distance';
  }

  String get unitLabel {
    return type == RunTargetType.time ? 'minutes' : 'km';
  }
}

/// User's selected run target parameters
@freezed
class RunTargetSelection with _$RunTargetSelection {
  const factory RunTargetSelection({
    required double targetDistance, // in kilometers
    required Duration targetTime, // in milliseconds
  }) = _RunTargetSelection;

  factory RunTargetSelection.fromJson(Map<String, dynamic> json) =>
      _$RunTargetSelectionFromJson(json);
}

// Helper methods for Firestore Timestamp conversion
DateTime _timestampToDateTime(dynamic timestamp) {
  if (timestamp == null) return DateTime.now();
  if (timestamp is Timestamp) {
    return timestamp.toDate();
  }
  if (timestamp is String) {
    return DateTime.parse(timestamp);
  }
  if (timestamp is int) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
  return DateTime.now();
}

Timestamp _dateTimeToTimestamp(DateTime? dateTime) {
  if (dateTime == null) return Timestamp.now();
  return Timestamp.fromDate(dateTime);
}
