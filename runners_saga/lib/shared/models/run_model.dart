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
    required List<LocationPoint> route,
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
    @JsonKey(fromJson: _timestampToDateTime, toJson: _dateTimeToTimestamp)
    required DateTime timestamp,
    double? heading, // compass direction in degrees
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
      timestamp: timestamp,
      heading: heading,
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
      timestamp: DateTime.now(),
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
