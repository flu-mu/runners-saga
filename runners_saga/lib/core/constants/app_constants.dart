class AppConstants {
  // App Information
  static const String appName = "The Runner's Saga";
  static const String appVersion = "1.0.0";
  static const String appDescription = "A story-driven running experience";
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String runsCollection = 'runs';
  static const String seasonsCollection = 'seasons';
  static const String progressCollection = 'progress';
  
  // Storage Paths
  static const String audioStoragePath = 'audio';
  static const String imagesStoragePath = 'images';
  static const String storiesStoragePath = 'stories';
  
  // Audio Settings
  static const double defaultVolume = 0.8;
  static const Duration fadeInDuration = Duration(milliseconds: 500);
  static const Duration fadeOutDuration = Duration(milliseconds: 500);
  
  // GPS Settings
  static const Duration gpsUpdateInterval = Duration(seconds: 1);
  static const double minDistanceForUpdate = 5.0; // meters
  static const int gpsAccuracy = 10; // meters
  
  // UI Constants
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration splashDuration = Duration(seconds: 3);
  
  // Story Constants
  static const String defaultSeasonId = 'fantasy_quest';
  static const String defaultSeasonTitle = 'The Fantasy Quest';
  
  // Permissions
  static const List<String> requiredPermissions = [
    'location',
    'microphone',
    'storage',
  ];
  
  // Error Messages
  static const String locationPermissionDenied = 'Location permission is required to track your runs';
  static const String audioPermissionDenied = 'Audio permission is required to play story segments';
  static const String networkError = 'Network error. Please check your connection';
  static const String unknownError = 'An unknown error occurred';
}
