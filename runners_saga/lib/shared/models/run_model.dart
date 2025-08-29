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
    required DateTime startTime,
    @JsonKey(fromJson: _timestampToDateTime, toJson: _dateTimeToTimestamp)
    DateTime? endTime,
    @JsonKey(name: 'gpsPoints') // Map to the actual Firestore field name
    List<LocationPoint>? route, // Make optional since not every run has GPS
    required double totalDistance, // in kilometers
    required Duration totalTime,
    required double averagePace, // minutes per kilometer
    required double maxPace, // fastest pace achieved
    required double minPace, // slowest pace achieved
    required String seasonId,
    required String missionId,
    required RunStatus status,
    required RunTarget runTarget, // user's selected time or distance target
    Map<String, dynamic>? metadata, // for additional data like calories, elevation, etc.
  }) = _RunModel;

  factory RunModel.fromJson(Map<String, dynamic> json) => _$RunModelFromJson(json);
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

// Extension to add Firestore serialization method
extension RunModelFirestore on RunModel {
  Map<String, dynamic> toFirestore() {
    final json = toJson();
    // Explicitly convert dates to Timestamps for Firestore
    if (json['startTime'] is DateTime) {
      json['startTime'] = Timestamp.fromDate(json['startTime'] as DateTime);
    }
    if (json['endTime'] is DateTime) {
      json['endTime'] = Timestamp.fromDate(json['endTime'] as DateTime);
    }
    return json;
  }
}
