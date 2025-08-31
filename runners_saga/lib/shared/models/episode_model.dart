import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'episode_model.freezed.dart';
part 'episode_model.g.dart';

@freezed
class EpisodeModel with _$EpisodeModel {
  const factory EpisodeModel({
    required String id,
    required String seasonId,
    required String title,
    required String description,
    required String status, // 'locked', 'unlocked', 'completed'
    required int order,
    @JsonKey(fromJson: _timestampToDateTime, toJson: _dateTimeToTimestamp)
    required DateTime createdAt,
    @JsonKey(fromJson: _timestampToDateTime, toJson: _dateTimeToTimestamp)
    required DateTime updatedAt,
    required String objective,
    required double targetDistance, // in kilometers
    required int targetTime, // in milliseconds
    @JsonKey(fromJson: _audioFilesFromJson) required List<String> audioFiles,
    // New single audio file support
    String? audioFile,
    @JsonKey(fromJson: _sceneTimestampsFromJson) List<Map<String, dynamic>>? sceneTimestamps,
    Map<String, dynamic>? requirements,
    Map<String, dynamic>? rewards,
    @JsonKey(fromJson: _timestampToDateTime, toJson: _dateTimeToTimestamp)
    DateTime? unlockedAt,
    @JsonKey(fromJson: _timestampToDateTime, toJson: _dateTimeToTimestamp)
    DateTime? completedAt,
    Map<String, dynamic>? metadata,
  }) = _EpisodeModel;

  factory EpisodeModel.fromJson(Map<String, dynamic> json) =>
      _$EpisodeModelFromJson(json);
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

// Helper method to safely parse audio files, filtering out null values
List<String> _audioFilesFromJson(dynamic audioFiles) {
  if (audioFiles == null) return [];
  if (audioFiles is List) {
    return audioFiles
        .where((item) => item != null && item is String)
        .cast<String>()
        .toList();
  }
  return [];
}

// Helper method to parse scene timestamps
List<Map<String, dynamic>> _sceneTimestampsFromJson(dynamic sceneTimestamps) {
  if (sceneTimestamps == null) return [];
  if (sceneTimestamps is List) {
    return sceneTimestamps
        .where((item) => item != null && item is Map<String, dynamic>)
        .cast<Map<String, dynamic>>()
        .toList();
  }
  return [];
}
