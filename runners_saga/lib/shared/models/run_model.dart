import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'run_target_model.dart';

part 'run_model.freezed.dart';
part 'run_model.g.dart';

@freezed
class RunModel with _$RunModel {
  @JsonSerializable(explicitToJson: true)
  const factory RunModel({
    String? id,
    required String userId,
    @JsonKey(fromJson: _timestampToDateTime, toJson: _dateTimeToTimestamp)
    required DateTime createdAt,
    @JsonKey(name: 'completedAt', fromJson: _timestampToDateTime, toJson: _dateTimeToTimestamp)
    DateTime? completedAt,
    @JsonKey(name: 'gpsPoints') // Map to the actual Firestore field name
    List<LocationPoint>? route, // Make optional since not every run has GPS
    @JsonKey(name: 'distance') // Map to the actual Firestore field name
    double? totalDistance, // in kilometers - can be null for incomplete runs
    @JsonKey(name: 'duration', fromJson: _intToDuration, toJson: _durationToInt) // Map to the actual Firestore field name
    Duration? totalTime, // can be null for incomplete runs
    double? averagePace, // minutes per kilometer - can be null for incomplete runs
    double? maxPace, // fastest pace achieved - can be null for incomplete runs
    double? minPace, // slowest pace achieved - can be null for incomplete runs
    @JsonKey(name: 'episodeId') // Map to the actual Firestore field name
    String? episodeId, // Make optional since it might not exist in old data
    @JsonKey(name: 'status', fromJson: _stringToRunStatus, toJson: _runStatusToString)
    RunStatus? status, // Make optional since it might not exist in old data
    RunTarget? runTarget, // Make optional since it might not exist in old data
    Map<String, dynamic>? metadata, // for additional data like calories, elevation, etc.
    double? elevationGain, // Total elevation gain in meters
    double? maxSpeed, // Maximum speed in km/h
    double? avgHeartRate, // Average heart rate in bpm
    double? caloriesBurned, // Calories burned
  }) = _RunModel;

  factory RunModel.fromJson(Map<String, dynamic> json) => _$RunModelFromJson(json);
}

// Extension to provide startTime/endTime as aliases for createdAt/completedAt
// These are used throughout the codebase but map to the actual Firebase fields
extension RunModelAliases on RunModel {
  /// Maps to createdAt for backward compatibility
  DateTime get startTime => createdAt;
  
  /// Maps to completedAt for backward compatibility
  DateTime? get endTime => completedAt;
}


@freezed
class LocationPoint with _$LocationPoint {
  const factory LocationPoint({
    required double latitude,
    required double longitude,
    required double accuracy,
    required double altitude,
    required double speed, // in meters per second
    @JsonKey(name: 'elapsedSeconds') // Map to actual Firestore field
    required int elapsedSeconds, // Use elapsed seconds instead of timestamp
    double? heading, // compass direction in degrees
    @JsonKey(name: 'elapsedTimeFormatted') // Additional field from Firestore
    String? elapsedTimeFormatted, // Formatted time string
  }) = _LocationPoint;

  factory LocationPoint.fromJson(Map<String, dynamic> json) => _$LocationPointFromJson(json);
}

enum RunStatus {
  notStarted,
  inProgress,
  paused,
  completed,
  cancelled,
}

// Extension to convert Position to LocationPoint
extension PositionExtension on Position {
  LocationPoint toLocationPoint() {
    return LocationPoint(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      speed: speed,
      elapsedSeconds: 0, // Will be calculated when saving
      heading: heading,
      elapsedTimeFormatted: '0:00', // Will be calculated when saving
    );
  }
}

// Extension to convert LatLng to LocationPoint
extension LatLngExtension on LatLng {
  LocationPoint toLocationPoint({double accuracy = 0.0, double altitude = 0.0, double speed = 0.0}) {
    return LocationPoint(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      speed: speed,
      elapsedSeconds: 0, // Will be calculated when saving
      heading: 0.0,
      elapsedTimeFormatted: '0:00', // Will be calculated when saving
    );
  }
}

// Helper methods for Firestore Timestamp conversion
DateTime _timestampToDateTime(dynamic timestamp) {
  if (timestamp == null) return DateTime.now();
  if (timestamp is Timestamp) {
    return timestamp.toDate();
  }
  if (timestamp is String) {
    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      print('⚠️ RunModel: Failed to parse timestamp string: $timestamp');
      return DateTime.now();
    }
  }
  if (timestamp is int) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
  print('⚠️ RunModel: Unknown timestamp type: ${timestamp.runtimeType}');
  return DateTime.now();
}

Timestamp _dateTimeToTimestamp(DateTime? dateTime) {
  if (dateTime == null) return Timestamp.now();
  return Timestamp.fromDate(dateTime);
}

// Helper methods for Duration conversion
Duration? _intToDuration(dynamic value) {
  if (value == null) return null;
  if (value is int) return Duration(seconds: value);
  if (value is String) {
    try {
      return Duration(seconds: int.parse(value));
    } catch (e) {
      print('⚠️ RunModel: Failed to parse duration string: $value');
      return null;
    }
  }
  print('⚠️ RunModel: Unknown duration type: ${value.runtimeType}');
  return null;
}

int? _durationToInt(Duration? duration) {
  if (duration == null) return null;
  return duration.inSeconds;
}

// Helper methods for RunStatus conversion
RunStatus? _stringToRunStatus(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    switch (value.toLowerCase()) {
      case 'notstarted':
        return RunStatus.notStarted;
      case 'inprogress':
        return RunStatus.inProgress;
      case 'paused':
        return RunStatus.paused;
      case 'completed':
        return RunStatus.completed;
      case 'cancelled':
        return RunStatus.cancelled;
      default:
        print('⚠️ RunModel: Unknown RunStatus string: $value');
        return RunStatus.notStarted;
    }
  }
  print('⚠️ RunModel: Unknown RunStatus type: ${value.runtimeType}');
  return RunStatus.notStarted;
}

String _runStatusToString(RunStatus? status) {
  if (status == null) return 'notstarted';
  switch (status) {
    case RunStatus.notStarted:
      return 'notstarted';
    case RunStatus.inProgress:
      return 'inprogress';
    case RunStatus.paused:
      return 'paused';
    case RunStatus.completed:
      return 'completed';
    case RunStatus.cancelled:
      return 'cancelled';
  }
}

// Extension to add Firestore serialization method
extension RunModelFirestore on RunModel {
  Map<String, dynamic> toFirestore() {
    print('🔧 RunModel.toFirestore() called');
    final json = toJson();
    print('🔧 RunModel.toFirestore() - createdAt type: ${json['createdAt']?.runtimeType}');
    print('🔧 RunModel.toFirestore() - createdAt value: ${json['createdAt']}');
    
    // Explicitly convert dates to Timestamps for Firestore
    if (json['createdAt'] is DateTime) {
      final timestamp = Timestamp.fromDate(json['createdAt'] as DateTime);
      json['createdAt'] = timestamp;
      print('🔧 RunModel.toFirestore() - Converted createdAt to Timestamp: $timestamp');
    } else {
      print('⚠️ RunModel.toFirestore() - createdAt is not DateTime: ${json['createdAt']?.runtimeType}');
    }
    
    // completedAt is the Firestore field for completedAt
    if (json['completedAt'] is DateTime) {
      final timestamp = Timestamp.fromDate(json['completedAt'] as DateTime);
      json['completedAt'] = timestamp;
      print('🔧 RunModel.toFirestore() - Converted completedAt to Timestamp: $timestamp');
    }
    
    print('🔧 RunModel.toFirestore() - Final createdAt type: ${json['createdAt']?.runtimeType}');
    return json;
  }
}
