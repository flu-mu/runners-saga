import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/season_model.dart';
import '../../models/episode_model.dart';
import '../../models/story_segment_model.dart';
import '../../models/user_model.dart';

/// Data class representing episode progression requirements and next episodes
class EpisodeProgression {
  final String episodeId;
  final List<String> prerequisites; // Episode IDs that must be completed first
  final List<String> nextEpisodes; // Episode IDs that become available after this one
  final Map<String, dynamic> unlockRequirements; // Additional requirements (distance, level, etc.)

  const EpisodeProgression({
    required this.episodeId,
    required this.prerequisites,
    required this.nextEpisodes,
    required this.unlockRequirements,
  });
}

/// Data class representing the status of an episode for a user
class EpisodeStatus {
  final String episodeId;
  final bool isCompleted;
  final bool canUnlock;
  final bool isLocked;
  final int order;

  const EpisodeStatus({
    required this.episodeId,
    required this.isCompleted,
    required this.canUnlock,
    required this.isLocked,
    required this.order,
  });
}



/// Data class representing the overall progression status of a user across all episodes
class UserProgressionStatus {
  final String userId;
  final int totalEpisodes;
  final int completedEpisodes;
  final int unlockableEpisodes;
  final int lockedEpisodes;
  final double overallProgressPercentage;

  const UserProgressionStatus({
    required this.userId,
    required this.totalEpisodes,
    required this.completedEpisodes,
    required this.unlockableEpisodes,
    required this.lockedEpisodes,
    required this.overallProgressPercentage,
  });
}

class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection names
  static const String _episodesCollection = 'episodes';
  static const String _storySegmentsCollection = 'story_segments';
  static const String _userProgressCollection = 'user_progress';

  // Episode progression lookup table
  // This maps episode IDs to their prerequisites and next episodes
  // Only tracks episode completion - no distance or level requirements
  static const Map<String, EpisodeProgression> _episodeProgressionTable = {
    // Season 1 progression
    'S01E01': EpisodeProgression(
      episodeId: 'S01E01',
      prerequisites: [], // First episode has no prerequisites
      nextEpisodes: ['S01E02'],
      unlockRequirements: {},
    ),
    'S01E02': EpisodeProgression(
      episodeId: 'S01E02',
      prerequisites: ['S01E01'], // Must have listened to S01E01
      nextEpisodes: ['S01E03'],
      unlockRequirements: {
        'completedEpisodes': ['S01E01'],
      },
    ),
    'S01E03': EpisodeProgression(
      episodeId: 'S01E03',
      prerequisites: ['S01E02'], // Must have listened to S01E02
      nextEpisodes: ['S01E04'],
      unlockRequirements: {
        'completedEpisodes': ['S01E02'],
      },
    ),
    'S01E04': EpisodeProgression(
      episodeId: 'S01E04',
      prerequisites: ['S01E03'], // Must have listened to S01E03
      nextEpisodes: ['S01E05'],
      unlockRequirements: {
        'completedEpisodes': ['S01E03'],
      },
    ),
    'S01E05': EpisodeProgression(
      episodeId: 'S01E05',
      prerequisites: ['S01E04'], // Must have listened to S01E04
      nextEpisodes: [], // Season finale
      unlockRequirements: {
        'completedEpisodes': ['S01E04'],
      },
    ),
    
    // Season 2 progression (example)
    'S02E01': EpisodeProgression(
      episodeId: 'S02E01',
      prerequisites: ['S01E05'], // Must have listened to S01E05
      nextEpisodes: ['S02E02'],
      unlockRequirements: {
        'completedEpisodes': ['S01E05'],
      },
    ),
  };

  /// Gets the episode progression data for a specific episode
  EpisodeProgression? getEpisodeProgression(String episodeId) {
    return _episodeProgressionTable[episodeId];
  }

  /// Gets all available episode progressions
  Map<String, EpisodeProgression> getAllEpisodeProgressions() {
    return Map.unmodifiable(_episodeProgressionTable);
  }

  /// Adds a new episode to the progression table
  /// This method allows dynamic addition of episodes to the progression system
  static void addEpisodeToProgressionTable(String episodeId, EpisodeProgression progression) {
    // Note: This is a static method that would need to be called during app initialization
    // In a real implementation, you might want to store this in a database or config file
    print('📝 Adding episode $episodeId to progression table');
    // _episodeProgressionTable[episodeId] = progression; // This would work if the map was non-const
  }

  /// Gets the user's current progress summary
  Future<Map<String, dynamic>> getUserProgressSummary(String userId) async {
    try {
      final userProgressRef = _firestore
          .collection(_userProgressCollection)
          .doc('${userId}_S01');
      
      final userProgressDoc = await userProgressRef.get();
      
      // Get total episode count from the episodes collection
      final episodesSnapshot = await _firestore
          .collection(_episodesCollection)
          .get();
      final totalEpisodes = episodesSnapshot.docs.length;
      
      if (userProgressDoc.exists) {
        final userProgress = userProgressDoc.data()!;
        final completedEpisodes = List<String>.from(userProgress['completedEpisodes'] ?? []);
        
        return {
          'totalEpisodes': totalEpisodes,
          'completedEpisodes': completedEpisodes.length,
          'remainingEpisodes': totalEpisodes - completedEpisodes.length,
          'progressPercentage': totalEpisodes > 0 ? (completedEpisodes.length / totalEpisodes) * 100 : 0.0,
          'completedEpisodeIds': completedEpisodes,
        };
      } else {
        // Create the user progress document for new users
        await userProgressRef.set({
          'userId': userId,
          'seasonId': 'S01',
          'completedEpisodes': [],
          'unlockedEpisodes': [],
          'totalDistance': 0.0,
          'totalRuns': 0,
          'currentEpisode': 'S01E01',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Created user progress document for new user in getUserProgressSummary');
        
        // Also update the user's lastEpisode field
        await _updateUserLastEpisode(userId, 'S01E01');
        
        return {
          'totalEpisodes': totalEpisodes,
          'completedEpisodes': 0,
          'remainingEpisodes': totalEpisodes,
          'progressPercentage': 0.0,
          'completedEpisodeIds': [],
        };
      }
    } catch (e) {
      print('❌ Error getting user progress summary: $e');
      return {
        'totalEpisodes': 0,
        'completedEpisodes': 0,
        'remainingEpisodes': 0,
        'progressPercentage': 0.0,
        'completedEpisodeIds': [],
      };
    }
  }

  /// Gets the progression path for a specific episode (all episodes leading to it)
  List<String> getProgressionPath(String episodeId) {
    final path = <String>[];
    final visited = <String>{};
    
    void _findPath(String currentEpisodeId) {
      if (visited.contains(currentEpisodeId)) return;
      visited.add(currentEpisodeId);
      
      final progression = getEpisodeProgression(currentEpisodeId);
      if (progression != null) {
        for (final prerequisite in progression.prerequisites) {
          _findPath(prerequisite);
        }
        path.add(currentEpisodeId);
      }
    }
    
    _findPath(episodeId);
    return path;
  }

  /// Gets all episodes that depend on completing a specific episode
  List<String> getDependentEpisodes(String episodeId) {
    final dependent = <String>{};
    
    for (final progression in _episodeProgressionTable.values) {
      if (progression.prerequisites.contains(episodeId)) {
        dependent.add(progression.episodeId);
        // Also add episodes that depend on this dependent episode
        dependent.addAll(getDependentEpisodes(progression.episodeId));
      }
    }
    
    return dependent.toList();
  }

  /// Validates the progression table for circular dependencies and missing episodes
  static List<String> validateProgressionTable() {
    final issues = <String>[];
    final visited = <String>{};
    final recursionStack = <String>{};
    
    void _checkForCycles(String episodeId) {
      if (recursionStack.contains(episodeId)) {
        issues.add('❌ Circular dependency detected: $episodeId');
        return;
      }
      
      if (visited.contains(episodeId)) return;
      
      visited.add(episodeId);
      recursionStack.add(episodeId);
      
      final progression = _episodeProgressionTable[episodeId];
      if (progression != null) {
        for (final prerequisite in progression.prerequisites) {
          if (!_episodeProgressionTable.containsKey(prerequisite)) {
            issues.add('❌ Missing prerequisite episode: $prerequisite (required by $episodeId)');
          } else {
            _checkForCycles(prerequisite);
          }
        }
      }
      
      recursionStack.remove(episodeId);
    }
    
    for (final episodeId in _episodeProgressionTable.keys) {
      if (!visited.contains(episodeId)) {
        _checkForCycles(episodeId);
      }
    }
    
    if (issues.isEmpty) {
      issues.add('✅ Progression table validation passed');
    }
    
    return issues;
  }

  /// Checks if a user can unlock a specific episode based on prerequisites
  Future<bool> canUnlockEpisode(String userId, String episodeId) async {
    try {
      final progression = getEpisodeProgression(episodeId);
      if (progression == null) {
        print('❌ No progression data found for episode: $episodeId');
        return false;
      }

      // Check prerequisites
      for (final prerequisiteId in progression.prerequisites) {
        if (!await hasCompletedEpisode(userId, prerequisiteId)) {
          print('❌ Prerequisite episode $prerequisiteId not completed');
          return false;
        }
      }

      // Check unlock requirements
      if (progression.unlockRequirements.isNotEmpty) {
        return await _checkUnlockRequirements(userId, episodeId, progression.unlockRequirements);
      }

      return true;
    } catch (e) {
      print('❌ Error checking episode unlock status: $e');
      return false;
    }
  }

  /// Gets the next available episode for a user based on their progress
  Future<EpisodeModel?> getNextEpisodeByProgression(String userId, String seasonId) async {
    try {
      print('🔍 Getting next episode by progression for user $userId in season $seasonId');
      
      // Get user's completed episodes for this season
      final completedEpisodes = await getCompletedEpisodesForSeason(userId, seasonId);
      
      // Find the highest order completed episode
      String? lastCompletedEpisodeId;
      int highestOrder = -1;
      
      for (final episodeId in completedEpisodes) {
        final episode = await getEpisodeById(episodeId);
        if (episode != null && episode.order > highestOrder) {
          highestOrder = episode.order;
          lastCompletedEpisodeId = episodeId;
        }
      }
      
      if (lastCompletedEpisodeId == null) {
        // No episodes completed, return first episode
        final episodes = await getAllEpisodes();
        final seasonEpisodes = episodes.where((e) => e.id.startsWith(seasonId)).toList();
        return seasonEpisodes.isNotEmpty ? seasonEpisodes.first : null;
      }
      
      // Get progression data for the last completed episode
      final progression = getEpisodeProgression(lastCompletedEpisodeId);
      if (progression == null || progression.nextEpisodes.isEmpty) {
        print('🎉 Season completed! No more episodes available');
        return null;
      }
      
      // Check each next episode to see which one can be unlocked
      for (final nextEpisodeId in progression.nextEpisodes) {
        if (await canUnlockEpisode(userId, nextEpisodeId)) {
          final nextEpisode = await getEpisodeById(nextEpisodeId);
          if (nextEpisode != null) {
            print('✅ Next episode available: ${nextEpisode.id} - ${nextEpisode.title}');
            return nextEpisode;
          }
        }
      }
      
      print('⚠️ No next episode can be unlocked yet');
      return null;
    } catch (e) {
      print('❌ Error getting next episode by progression: $e');
      return null;
    }
  }

  /// Gets all episodes that a user can currently unlock
  Future<List<EpisodeModel>> getUnlockableEpisodes(String userId, String seasonId) async {
    try {
      final episodes = await getAllEpisodes();
      final seasonEpisodes = episodes.where((e) => e.id.startsWith(seasonId)).toList();
      final unlockableEpisodes = <EpisodeModel>[];
      
      for (final episode in seasonEpisodes) {
        if (await canUnlockEpisode(userId, episode.id)) {
          unlockableEpisodes.add(episode);
        }
      }
      
      return unlockableEpisodes;
    } catch (e) {
      print('❌ Error getting unlockable episodes: $e');
      return [];
    }
  }

  /// Gets the user's episode completion status for a specific season
  Future<Map<String, EpisodeStatus>> getEpisodeStatusForSeason(String userId, String seasonId) async {
    try {
      final episodes = await getAllEpisodes();
      final seasonEpisodes = episodes.where((e) => e.id.startsWith(seasonId)).toList();
      final episodeStatuses = <String, EpisodeStatus>{};
      
      for (final episode in seasonEpisodes) {
        final isCompleted = await hasCompletedEpisode(userId, episode.id);
        final canUnlock = await canUnlockEpisode(userId, episode.id);
        
        episodeStatuses[episode.id] = EpisodeStatus(
          episodeId: episode.id,
          isCompleted: isCompleted,
          canUnlock: canUnlock,
          isLocked: !isCompleted && !canUnlock,
          order: episode.order,
        );
      }
      
      return episodeStatuses;
    } catch (e) {
      print('❌ Error getting episode status for season: $e');
      return {};
    }
  }

  /// Checks if a user has completed a specific episode
  Future<bool> hasCompletedEpisode(String userId, String episodeId) async {
    try {
      final episode = await getEpisodeById(episodeId);
      if (episode == null) return false;
      
      // Extract season ID from episode ID (e.g., S01E01 -> S01)
      final seasonId = episode.id.substring(0, 3);
      
      final userProgressDoc = await _firestore
          .collection(_userProgressCollection)
          .doc('${userId}_$seasonId')
          .get();

      if (!userProgressDoc.exists) return false;
      
      final userProgress = userProgressDoc.data()!;
      final completedEpisodes = List<String>.from(userProgress['completedEpisodes'] ?? []);
      
      return completedEpisodes.contains(episodeId);
    } catch (e) {
      print('❌ Error checking episode completion: $e');
      return false;
    }
  }

  /// Gets all completed episodes for a user in a specific season
  Future<List<String>> getCompletedEpisodesForSeason(String userId, String seasonId) async {
    try {
      final userProgressDoc = await _firestore
          .collection(_userProgressCollection)
          .doc('${userId}_$seasonId')
          .get();

      if (!userProgressDoc.exists) return [];
      
      final userProgress = userProgressDoc.data()!;
      return List<String>.from(userProgress['completedEpisodes'] ?? []);
    } catch (e) {
      print('❌ Error getting completed episodes: $e');
      return [];
    }
  }

  /// Checks if user can unlock an episode
  /// Only requirement: they must have heard the previous episode
  Future<bool> _checkUnlockRequirements(String userId, String episodeId, Map<String, dynamic>? requirements) async {
    try {
      // Get the episode order to find the previous one
      final episode = await getEpisodeById(episodeId);
      if (episode == null) return false;
      
      // First episode is always unlockable
      if (episode.order == 1) return true;
      
      // Check if they've heard the previous episode
      final previousEpisodeId = 'S01E${(episode.order - 1).toString().padLeft(2, '0')}';
      final hasHeardPrevious = await hasCompletedEpisode(userId, previousEpisodeId);
      
      if (!hasHeardPrevious) {
        print('❌ User must hear previous episode $previousEpisodeId first');
        return false;
      }
      
      return true;
    } catch (e) {
      print('❌ Error checking unlock requirements: $e');
      return false;
    }
  }

  /// Gets user stats for other app functionality (not used for episode unlocking)
  /// User stats are tracked separately from episode progression
  Future<UserStats> _getUserStats(String userId) async {
    try {
      // This would typically come from a user stats service
      // For now, we'll return default stats
      return UserStats(
        totalRuns: 0,
        totalDistance: 0.0,
        totalTime: 0,
        averagePace: 0.0,
        bestPace: 0.0,
        longestRun: 0.0,
        currentStreak: 0,
        longestStreak: 0,
        currentLevel: 1,
        experiencePoints: 0,
        totalSeasonsCompleted: 0,
        totalAchievements: 0,
      );
    } catch (e) {
      print('❌ Error getting user stats: $e');
      return UserStats(
        totalRuns: 0,
        totalDistance: 0.0,
        totalTime: 0,
        averagePace: 0.0,
        bestPace: 0.0,
        longestRun: 0.0,
        currentStreak: 0,
        longestStreak: 0,
        currentLevel: 1,
        experiencePoints: 0,
        totalSeasonsCompleted: 0,
        totalAchievements: 0,
      );
    }
  }

  /// Gets the user's overall progression status across all episodes
  Future<UserProgressionStatus> getUserProgressionStatus(String userId) async {
    try {
      final episodes = await getAllEpisodes();
      int completedCount = 0;
      int unlockableCount = 0;
      int lockedCount = 0;
      
      for (final episode in episodes) {
        final isCompleted = await hasCompletedEpisode(userId, episode.id);
        final canUnlock = await canUnlockEpisode(userId, episode.id);
        
        if (isCompleted) {
          completedCount++;
        } else if (canUnlock) {
          unlockableCount++;
        } else {
          lockedCount++;
        }
      }
      
      final totalEpisodes = episodes.length;
      final overallProgressPercentage = totalEpisodes > 0 ? (completedCount / totalEpisodes) * 100 : 0.0;
      
      return UserProgressionStatus(
        userId: userId,
        totalEpisodes: totalEpisodes,
        completedEpisodes: completedCount,
        unlockableEpisodes: unlockableCount,
        lockedEpisodes: lockedCount,
        overallProgressPercentage: overallProgressPercentage,
      );
    } catch (e) {
      print('❌ Error getting user progression status: $e');
      return UserProgressionStatus(
        userId: userId,
        totalEpisodes: 0,
        completedEpisodes: 0,
        unlockableEpisodes: 0,
        lockedEpisodes: 0,
        overallProgressPercentage: 0.0,
      );
    }
  }

  /// Gets the next episode that should be recommended to the user
  Future<EpisodeModel?> getRecommendedNextEpisode(String userId) async {
    try {
      // Simply get the next available episode for the user
      return await getNextAvailableEpisode(userId);
    } catch (e) {
      print('❌ Error getting recommended next episode: $e');
      return null;
    }
  }



  Future<EpisodeModel?> getEpisodeById(String episodeId) async {
    try {
      final doc = await _firestore
          .collection(_episodesCollection)
          .doc(episodeId)
          .get();

      if (doc.exists) {
        return EpisodeModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch episode: $e');
    }
  }

  /// Gets all episodes from the database
  Future<List<EpisodeModel>> getAllEpisodes() async {
    try {
      final querySnapshot = await _firestore
          .collection(_episodesCollection)
          .orderBy('order')
          .get();

      return querySnapshot.docs
          .map((doc) => EpisodeModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching all episodes: $e');
      return [];
    }
  }

  /// Gets the first available episode for a user, automatically defaulting to S01E01
  Future<EpisodeModel?> getFirstAvailableEpisode(String userId) async {
    try {
      print('🔍 Getting first available episode for user $userId');
      
      // Directly query episodes collection and get the first one
      final episodesSnapshot = await _firestore
          .collection(_episodesCollection)
          .orderBy('order')
          .limit(1)
          .get();
      
      if (episodesSnapshot.docs.isNotEmpty) {
        final episode = EpisodeModel.fromJson(episodesSnapshot.docs.first.data());
        print('✅ Found first episode: ${episode.id} - ${episode.title}');
        return episode;
      }
      
      print('❌ No episodes found in database');
      return null;
    } catch (e) {
      print('❌ Error getting first available episode: $e');
      return null;
    }
  }

  /// Automatically unlocks the first episode for a new user
  Future<void> unlockFirstEpisodeForNewUser(String userId, String seasonId) async {
    try {
      print('🔓 Unlocking first episode for new user $userId in season $seasonId');
      
      // Check if user already has progress
      final userProgressDoc = await _firestore
          .collection(_userProgressCollection)
          .doc('${userId}_$seasonId')
          .get();

      if (userProgressDoc.exists) {
        print('👤 User already has progress, skipping unlock');
        return;
      }

      // Get the first episode
      final episodes = await getAllEpisodes();
      final seasonEpisodes = episodes.where((e) => e.id.startsWith(seasonId)).toList();
      if (seasonEpisodes.isEmpty) {
        print('❌ No episodes found for season $seasonId');
        return;
      }

      final firstEpisode = seasonEpisodes.first;
      print('🎯 Unlocking first episode: ${firstEpisode.id}');

      // Create user progress document with first episode unlocked
      await _firestore
          .collection(_userProgressCollection)
          .doc('${userId}_$seasonId')
          .set({
        'userId': userId,
        'seasonId': seasonId,
        'unlockedEpisodes': [firstEpisode.id],
        'completedEpisodes': [],
        'totalDistance': 0.0,
        'totalRuns': 0,
        'currentEpisode': firstEpisode.id,
        'episodeProgress': {
          firstEpisode.id: {
            'status': 'unlocked',
            'unlockedAt': FieldValue.serverTimestamp(),
            'completedAt': null,
            'attempts': 0,
            'bestTime': null,
            'bestDistance': null,
          }
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ First episode unlocked for user $userId');
      
      // Also update the user's lastEpisode field
      await _updateUserLastEpisode(userId, firstEpisode.id);
    } catch (e) {
      print('❌ Error unlocking first episode: $e');
    }
  }

  /// Completes an episode and automatically unlocks the next one
  Future<void> completeEpisode(String userId, String episodeId) async {
    try {
      print('🏁 Completing episode $episodeId for user $userId');
      
      final episode = await getEpisodeById(episodeId);
      if (episode == null) {
        print('❌ Episode not found: $episodeId');
        return;
      }

      // Extract season ID from episode ID (e.g., S01E01 -> S01)
      final seasonId = episode.id.substring(0, 3);
      
      final userProgressRef = _firestore
          .collection(_userProgressCollection)
          .doc('${userId}_$seasonId');

      await _firestore.runTransaction((transaction) async {
        final userProgressDoc = await transaction.get(userProgressRef);
        
        if (userProgressDoc.exists) {
          final userProgress = userProgressDoc.data()!;
          final completedEpisodes = List<String>.from(userProgress['completedEpisodes'] ?? []);
          final unlockedEpisodes = List<String>.from(userProgress['completedEpisodes'] ?? []);
          final episodeProgress = Map<String, dynamic>.from(userProgress['episodeProgress'] ?? {});

          // Mark episode as completed
          if (!completedEpisodes.contains(episodeId)) {
            completedEpisodes.add(episodeId);
          }

          // Update episode progress
          if (episodeProgress.containsKey(episodeId)) {
            episodeProgress[episodeId]['status'] = 'completed';
            episodeProgress[episodeId]['completedAt'] = FieldValue.serverTimestamp();
          }

          // Use the new progression system to find the next episode
          final progression = getEpisodeProgression(episodeId);
          if (progression != null && progression.nextEpisodes.isNotEmpty) {
            // Find the first next episode that can be unlocked
            for (final nextEpisodeId in progression.nextEpisodes) {
              if (await canUnlockEpisode(userId, nextEpisodeId)) {
                print('🔓 Unlocking next episode: $nextEpisodeId');
                
                // Unlock next episode
                if (!unlockedEpisodes.contains(nextEpisodeId)) {
                  unlockedEpisodes.add(nextEpisodeId);
                }
                
                // Add next episode to progress tracking
                episodeProgress[nextEpisodeId] = {
                  'status': 'unlocked',
                  'unlockedAt': FieldValue.serverTimestamp(),
                  'completedAt': null,
                  'attempts': 0,
                  'bestTime': null,
                  'bestDistance': null,
                };
                
                // Update current episode to next unlocked episode
                userProgress['currentEpisode'] = nextEpisodeId;
                
                // Also update the user's lastEpisode field
                await _updateUserLastEpisode(userId, nextEpisodeId);
                break; // Only unlock the first available next episode
              }
            }
          }

          transaction.update(userProgressRef, {
            'completedEpisodes': completedEpisodes,
            'unlockedEpisodes': unlockedEpisodes,
            'episodeProgress': episodeProgress,
            'currentEpisode': userProgress['currentEpisode'],
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          print('✅ Episode $episodeId completed and next episode unlocked');
        }
      });

      // Update season progress
      await _updateSeasonProgress(userId, seasonId);
      
      // Update the user's lastEpisode field
      await _updateUserLastEpisode(userId, episodeId);
    } catch (e) {
      print('❌ Error completing episode: $e');
    }
  }

  /// Gets the current episode for a user based on their progress
  /// If no episode is available, returns the first episode from the episodes table
  Future<EpisodeModel?> getCurrentEpisode(String userId, String seasonId) async {
    try {
      print('🔍 Getting current episode for user $userId in season $seasonId');
      
      final userProgressDoc = await _firestore
          .collection(_userProgressCollection)
          .doc('${userId}_$seasonId')
          .get();

      if (!userProgressDoc.exists) {
        print('👤 First time user - unlocking first episode');
        await unlockFirstEpisodeForNewUser(userId, seasonId);
        
        // Get the first episode
        final episodes = await getAllEpisodes();
        final seasonEpisodes = episodes.where((e) => e.id.startsWith(seasonId)).toList();
        return seasonEpisodes.isNotEmpty ? seasonEpisodes.first : null;
      }

      final userProgress = userProgressDoc.data()!;
      final currentEpisodeId = userProgress['currentEpisode'] as String?;
      
      if (currentEpisodeId != null) {
        final episode = await getEpisodeById(currentEpisodeId);
        if (episode != null) {
          print('✅ Current episode: ${episode.id} - ${episode.title}');
          return episode;
        }
      }

      // If no episode is available, return the first episode from the episodes table
      print('⚠️ No current episode found, returning first available episode');
      final allEpisodes = await _firestore
          .collection(_episodesCollection)
          .orderBy('order')
          .limit(1)
          .get();
      
      if (allEpisodes.docs.isNotEmpty) {
        final firstEpisode = EpisodeModel.fromJson(allEpisodes.docs.first.data());
        print('✅ Returning first available episode: ${firstEpisode.id} - ${firstEpisode.title}');
        return firstEpisode;
      }

      print('❌ No episodes found in database');
      return null;
    } catch (e) {
      print('❌ Error getting current episode: $e');
      return null;
    }
  }

  Future<EpisodeModel?> getNextAvailableEpisode(String userId) async {
    try {
      print('🔍 Getting next available episode for user $userId');
      
      // Get user's progress for Season 1
      final userProgressRef = _firestore
          .collection(_userProgressCollection)
          .doc('${userId}_S01');
      
      final userProgressDoc = await userProgressRef.get();
      List<String> completedEpisodes = [];
      
      if (userProgressDoc.exists) {
        final userProgress = userProgressDoc.data()!;
        completedEpisodes = List<String>.from(userProgress['completedEpisodes'] ?? []);
        print('📊 User has completed episodes: $completedEpisodes');
      } else {
        print('📊 New user, creating progress document...');
        // Create the user progress document for new users
        await userProgressRef.set({
          'userId': userId,
          'seasonId': 'S01',
          'completedEpisodes': [],
          'unlockedEpisodes': [],
          'totalDistance': 0.0,
          'totalRuns': 0,
          'currentEpisode': 'S01E01',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ Created user progress document for new user');
        
        // Also update the user's lastEpisode field
        await _updateUserLastEpisode(userId, 'S01E01');
      }
      
      // Get all episodes from the episodes collection, ordered by their order field
      final episodesSnapshot = await _firestore
          .collection(_episodesCollection)
          .orderBy('order')
          .get();
      
      if (episodesSnapshot.docs.isEmpty) {
        print('❌ No episodes found in episodes collection');
        return null;
      }
      
      // Convert to EpisodeModel objects
      final episodes = episodesSnapshot.docs
          .map((doc) => EpisodeModel.fromJson(doc.data()))
          .toList();
      
      print('📺 Found ${episodes.length} episodes in database');
      
      // Just return the first episode from the episodes collection
      print('🎯 Returning first episode from episodes collection');
      final firstEpisode = episodes.first;
      print('✅ Returning first episode: ${firstEpisode.id} - ${firstEpisode.title}');
      return firstEpisode;
      
      return null;
    } catch (e) {
      print('❌ Error getting next available episode: $e');
      return null;
    }
  }
  


  Future<void> createEpisode(EpisodeModel episode) async {
    try {
      await _firestore
          .collection(_episodesCollection)
          .doc(episode.id)
          .set(episode.toJson());

      // Seasons are now derived automatically from episodes, no need to update season documents
      print('✅ Episode ${episode.id} created successfully');
    } catch (e) {
      throw Exception('Failed to create episode: $e');
    }
  }

  // User progress methods
  Future<void> markEpisodeAsCompleted(String userId, String episodeId) async {
    try {
      print('✅ Marking episode $episodeId as completed for user $userId');
      
      // Extract season ID from episode ID (e.g., S01E01 -> S01)
      final seasonId = episodeId.substring(0, 3);

      final userProgressRef = _firestore
          .collection(_userProgressCollection)
          .doc('${userId}_$seasonId');

      await _firestore.runTransaction((transaction) async {
        final userProgressDoc = await transaction.get(userProgressRef);
        
        if (userProgressDoc.exists) {
          final userProgress = userProgressDoc.data()!;
          final completedEpisodes = List<String>.from(userProgress['completedEpisodes'] ?? []);

          if (!completedEpisodes.contains(episodeId)) {
            completedEpisodes.add(episodeId);
          }

          transaction.update(userProgressRef, {
            'completedEpisodes': completedEpisodes,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new user progress document
          transaction.set(userProgressRef, {
            'userId': userId,
            'seasonId': seasonId,
            'completedEpisodes': [episodeId],
            'unlockedEpisodes': [],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Update the user's lastEpisode field
      await _updateUserLastEpisode(userId, episodeId);

      print('✅ Episode $episodeId marked as completed for user $userId');
    } catch (e) {
      print('❌ Error marking episode as completed: $e');
      throw Exception('Failed to mark episode as completed: $e');
    }
  }

  /// Updates the user's lastEpisode field in the users collection
  Future<void> _updateUserLastEpisode(String userId, String episodeId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'lastEpisode': episodeId,
        'lastActive': FieldValue.serverTimestamp(),
      });
      print('✅ Updated lastEpisode to $episodeId for user $userId');
    } catch (e) {
      print('❌ Error updating user lastEpisode: $e');
      // Don't throw here as this is not critical for episode completion
    }
  }

  Future<void> updateEpisodeProgress(String userId, String episodeId, String status) async {
    try {
      final episode = await getEpisodeById(episodeId);
      if (episode == null) throw Exception('Episode not found');

      // Extract season ID from episode ID (e.g., S01E01 -> S01)
      final seasonId = episode.id.substring(0, 3);

      final userProgressRef = _firestore
          .collection(_userProgressCollection)
          .doc('${userId}_$seasonId');

      await _firestore.runTransaction((transaction) async {
        final userProgressDoc = await transaction.get(userProgressRef);
        
        if (userProgressDoc.exists) {
          final userProgress = userProgressDoc.data()!;
          final completedEpisodes = List<String>.from(userProgress['completedEpisodes'] ?? []);
          final unlockedEpisodes = List<String>.from(userProgress['unlockedEpisodes'] ?? []);

          if (status == 'completed' && !completedEpisodes.contains(episodeId)) {
            completedEpisodes.add(episodeId);
          }

          if (status == 'unlocked' && !unlockedEpisodes.contains(episodeId)) {
            unlockedEpisodes.add(episodeId);
          }

          transaction.update(userProgressRef, {
            'completedEpisodes': completedEpisodes,
            'unlockedEpisodes': unlockedEpisodes,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new user progress document
          transaction.set(userProgressRef, {
            'userId': userId,
            'seasonId': seasonId,
            'completedEpisodes': status == 'completed' ? [episodeId] : [],
            'unlockedEpisodes': status == 'unlocked' ? [episodeId] : [],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Update season progress
      await _updateSeasonProgress(userId, seasonId);
      
      // Update the user's lastEpisode field if episode is completed
      if (status == 'completed') {
        await _updateUserLastEpisode(userId, episodeId);
      }
    } catch (e) {
      throw Exception('Failed to update episode progress: $e');
    }
  }

  Future<void> _updateSeasonProgress(String userId, String seasonId) async {
    try {
      // Seasons are now derived from episodes, so we don't need to update season documents
      // User progress is still tracked in the userProgress collection
      print('✅ User progress updated for season $seasonId');
    } catch (e) {
      print('❌ Error updating season progress: $e');
    }
  }

  Future<bool> _checkEpisodeRequirements(String userId, EpisodeModel episode) async {
    try {
      // This is a simplified check - you can expand this based on your requirements
      // For now, we'll just check if the previous episode was completed
      final seasonId = episode.id.substring(0, 3); // Extract S01 from S01E01
      final episodes = await getAllEpisodes();
      final seasonEpisodes = episodes.where((e) => e.id.startsWith(seasonId)).toList();
      final episodeIndex = seasonEpisodes.indexWhere((e) => e.id == episode.id);
      
      if (episodeIndex > 0) {
        final previousEpisode = seasonEpisodes[episodeIndex - 1];
        final userProgressDoc = await _firestore
            .collection(_userProgressCollection)
            .doc('${userId}_$seasonId')
            .get();

        if (userProgressDoc.exists) {
          final userProgress = userProgressDoc.data()!;
          final completedEpisodes = List<String>.from(userProgress['completedEpisodes'] ?? []);
          return completedEpisodes.contains(previousEpisode.id);
        }
      }

      return episodeIndex == 0; // First episode is always available
    } catch (e) {
      print('Failed to check episode requirements: $e');
      return false;
    }
  }

  // Story segment methods
  Future<List<StorySegmentModel>> getStorySegmentsForEpisode(String episodeId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_storySegmentsCollection)
          .where('episodeId', isEqualTo: episodeId)
          .orderBy('order')
          .get();

      return querySnapshot.docs
          .map((doc) => StorySegmentModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch story segments: $e');
    }
  }

  /// Gets all seasons
  Future<List<SeasonModel>> getSeasons() async {
    try {
      print('🔍 StoryService: Attempting to fetch seasons');
      final querySnapshot = await _firestore
          .collection('seasons')
          .orderBy('order')
          .get();

      print('🔍 StoryService: Seasons query successful, found ${querySnapshot.docs.length} seasons');
      
      final seasons = querySnapshot.docs
          .map((doc) => SeasonModel.fromJson(doc.data()))
          .toList();
      
      print('🔍 StoryService: Parsed ${seasons.length} seasons successfully');
      return seasons;
    } catch (e) {
      print('❌ StoryService: Failed to fetch seasons: $e');
      print('❌ StoryService: Error type: ${e.runtimeType}');
      print('❌ StoryService: Falling back to default seasons');
      // Return default seasons if Firebase fails
      return _getDefaultSeasons();
    }
  }

    /// Gets episodes for a specific season
  Future<List<EpisodeModel>> getEpisodesBySeason(int seasonNumber) async {
    // Removed debug collection checks to reduce memory usage
    try {
      print('🔍 StoryService: Attempting to fetch episodes for season $seasonNumber');
      print('🔍 StoryService: Collection: $_episodesCollection');
      
      // Try to get episodes by seasonId first
      var querySnapshot = await _firestore
          .collection(_episodesCollection)
          .where('seasonId', isEqualTo: 'fantasy_quest_season_1')
          .orderBy('order')
          .get();

      // If no results, try without the where clause to get all episodes
      if (querySnapshot.docs.isEmpty) {
        print('🔍 StoryService: No episodes found with seasonId fantasy_quest_season_1, trying to get all episodes');
        try {
          querySnapshot = await _firestore
              .collection(_episodesCollection)
              .orderBy('order')
              .get();
        } catch (e) {
          print('🔍 StoryService: Error getting all episodes: $e');
          // Try without orderBy as a last resort
          try {
            querySnapshot = await _firestore
                .collection(_episodesCollection)
                .get();
            print('🔍 StoryService: Got ${querySnapshot.docs.length} episodes without ordering');
          } catch (e2) {
            print('🔍 StoryService: Final error getting episodes: $e2');
            return [];
          }
        }
      }

      print('🔍 StoryService: Query successful, found ${querySnapshot.docs.length} episodes');
      
      final episodes = querySnapshot.docs
          .map((doc) => EpisodeModel.fromJson(doc.data()))
          .toList();
      
      print('🔍 StoryService: Parsed ${episodes.length} episodes successfully');
      return episodes;
    } catch (e) {
      print('❌ StoryService: Failed to fetch episodes for season $seasonNumber: $e');
      print('❌ StoryService: Error type: ${e.runtimeType}');
      print('❌ StoryService: No fallback - letting error happen');
      
      // Let the error happen so we can see what's really failing
      rethrow;
    }
  }

  /// Gets the user's last episode from their profile and loads the episode info
  Future<EpisodeModel?> getLastEpisodeFromUserProfile(String userId) async {
    try {
      // Get user profile from users collection
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        // If user profile not found, get S01E01 directly
        final episodeDoc = await _firestore
            .collection(_episodesCollection)
            .doc('S01E01')
            .get();
        
        if (episodeDoc.exists) {
          return EpisodeModel.fromJson(episodeDoc.data()!);
        }
        return null;
      }
      
      final userData = userDoc.data()!;
      final lastEpisodeId = userData['lastEpisode'] as String? ?? 'S01E01';
      
      // Get the episode from the episodes collection
      final episodeDoc = await _firestore
          .collection(_episodesCollection)
          .doc(lastEpisodeId)
          .get();
      
      if (!episodeDoc.exists) {
        // If episode not found, fallback to S01E01
        final fallbackDoc = await _firestore
            .collection(_episodesCollection)
            .doc('S01E01')
            .get();
        
        if (fallbackDoc.exists) {
          return EpisodeModel.fromJson(fallbackDoc.data()!);
        }
        return null;
      }
      
      return EpisodeModel.fromJson(episodeDoc.data()!);
    } catch (e) {
      // If anything fails, try to get S01E01 as fallback
      try {
        final fallbackDoc = await _firestore
            .collection(_episodesCollection)
            .doc('S01E01')
            .get();
        
        if (fallbackDoc.exists) {
          return EpisodeModel.fromJson(fallbackDoc.data()!);
        }
      } catch (_) {
        // If even the fallback fails, return null
      }
      return null;
    }
  }

  /// Get default seasons when Firebase has no data
  List<SeasonModel> _getDefaultSeasons() {
    return [
      SeasonModel(
        id: 'S01',
        title: 'Season 1',
        description: 'The beginning of your journey in Abel Township',
        episodeIds: ['S01E01', 'S01E02', 'S01E03'],
        totalEpisodes: 3,
        completedEpisodes: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'active',
        order: 1,
      ),
      SeasonModel(
        id: 'S02',
        title: 'Season 2',
        description: 'Continue your adventure',
        episodeIds: ['S02E01', 'S02E02'],
        totalEpisodes: 2,
        completedEpisodes: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'locked',
        order: 2,
      ),
      SeasonModel(
        id: 'S03',
        title: 'Season 3',
        description: 'New challenges await',
        episodeIds: ['S03E01'],
        totalEpisodes: 1,
        completedEpisodes: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'locked',
        order: 3,
      ),
    ];
  }

  /// Get default episodes when Firebase has no data
  List<EpisodeModel> _getDefaultEpisodes(int seasonNumber) {
    if (seasonNumber == 1) {
      return [
        EpisodeModel(
          id: 'S01E01',
          seasonId: 'S01',
          title: 'Jolly Alpha Five Niner',
          description: 'Your story begins here',
          status: 'unlocked',
          order: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          objective: 'Complete your first run in Abel Township',
          targetDistance: 5.0,
          targetTime: 1800000, // 30 minutes
          audioFiles: [
            'scene_1_quick.mp3',
            'scene_2_mission_briefing.mp3', 
            'scene_3_the_journey.mp3',
            'scene_4_first_contact.mp3',
            'scene_5_the_crisis.mp3'
          ],
          requirements: {},
          rewards: {},
        ),
        EpisodeModel(
          id: 'S01E02',
          seasonId: 'S01',
          title: 'Distraction',
          description: 'Dead herring',
          status: 'unlocked',
          order: 2,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          objective: 'Continue your investigation',
          targetDistance: 7.0,
          targetTime: 2400000, // 40 minutes
          audioFiles: [
            'scene_1_quick.mp3',
            'scene_2_mission_briefing.mp3', 
            'scene_3_the_journey.mp3',
            'scene_4_first_contact.mp3',
            'scene_5_the_crisis.mp3'
          ],
          requirements: {},
          rewards: {},
        ),
        EpisodeModel(
          id: 'S01E03',
          seasonId: 'S01',
          title: 'Lay of the Land',
          description: 'There\'s no place like home',
          status: 'locked',
          order: 3,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          objective: 'Explore the town boundaries',
          targetDistance: 10.0,
          targetTime: 3600000, // 60 minutes
          audioFiles: [
            'scene_1_quick.mp3',
            'scene_2_mission_briefing.mp3', 
            'scene_3_the_journey.mp3',
            'scene_4_first_contact.mp3',
            'scene_5_the_crisis.mp3'
          ],
          requirements: {},
          rewards: {},
        ),
      ];
    }
    return [];
  }
}
