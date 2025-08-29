import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    required String fullName,
    String? profileImageUrl,
    @Default(0) int totalRuns,
    @Default(0.0) double totalDistance,
    @Default(0) int totalTime,
    @Default(0) int currentLevel,
    @Default(0) int experiencePoints,
    @Default([]) List<String> completedSeasons,
    @Default([]) List<String> achievements,
    @Default({}) Map<String, dynamic> preferences,
    @Default('X01Y01') String lastEpisode,
    @JsonKey(fromJson: _timestampToDateTime, toJson: _dateTimeToTimestamp)
    required DateTime createdAt,
    @JsonKey(fromJson: _timestampToDateTime, toJson: _dateTimeToTimestamp)
    DateTime? lastActive,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
}

@freezed
class UserPreferences with _$UserPreferences {
  const factory UserPreferences({
    @Default(true) bool notificationsEnabled,
    @Default(true) bool locationTrackingEnabled,
    @Default('metric') String distanceUnit, // 'metric' or 'imperial'
    @Default('en') String language,
    @Default(true) bool autoPlayAudio,
    @Default(0.5) double audioVolume,
    @Default('system') String themeMode, // 'light', 'dark', 'system'
  }) = _UserPreferences;

  factory UserPreferences.fromJson(Map<String, dynamic> json) => _$UserPreferencesFromJson(json);
}

@freezed
class UserStats with _$UserStats {
  const factory UserStats({
    @Default(0) int totalRuns,
    @Default(0.0) double totalDistance,
    @Default(0) int totalTime,
    @Default(0.0) double averagePace,
    @Default(0.0) double bestPace,
    @Default(0.0) double longestRun,
    @Default(0) int currentStreak,
    @Default(0) int longestStreak,
    @Default(0) int currentLevel,
    @Default(0) int experiencePoints,
    @Default(0) int totalSeasonsCompleted,
    @Default(0) int totalAchievements,
  }) = _UserStats;

  factory UserStats.fromJson(Map<String, dynamic> json) => _$UserStatsFromJson(json);
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
