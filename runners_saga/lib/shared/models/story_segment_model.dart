import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'story_segment_model.freezed.dart';
part 'story_segment_model.g.dart';

@freezed
class StorySegmentModel with _$StorySegmentModel {
  const factory StorySegmentModel({
    required String id,
    required String episodeId,
    required String title,
    required String content,
    required int order,
    required String audioFile,
    required double triggerAt, // percentage of run completion (0.0 to 1.0)
    @JsonKey(fromJson: _timestampToDateTime, toJson: _dateTimeToTimestamp)
    required DateTime createdAt,
    Map<String, dynamic>? metadata,
  }) = _StorySegmentModel;

  factory StorySegmentModel.fromJson(Map<String, dynamic> json) =>
      _$StorySegmentModelFromJson(json);
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
