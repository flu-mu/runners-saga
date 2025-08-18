import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/story_service.dart';
import '../models/episode_model.dart';
import '../models/season_model.dart';

// Service provider
final storyServiceProvider = Provider<StoryService>((ref) {
  return StoryService();
});

// Episodes providers
final episodeByIdProvider = FutureProvider.family<EpisodeModel?, String>((ref, episodeId) async {
  final storyService = ref.read(storyServiceProvider);
  return await storyService.getEpisodeById(episodeId);
});

// Current episode provider
final currentEpisodeProvider = StateProvider<EpisodeModel?>((ref) => null);

// Next available episode provider
final nextAvailableEpisodeProvider = FutureProvider<EpisodeModel?>((ref) async {
  final storyService = ref.read(storyServiceProvider);
  // This will need to be updated to get the current user ID from auth
  return null;
});

// User progress providers
final userEpisodeProgressProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  // This would fetch user progress for all episodes
  // Implementation depends on your user progress structure
  return null;
});

// Story segments provider
final episodeStorySegmentsProvider = FutureProvider.family<List<dynamic>, String>((ref, episodeId) async {
  final storyService = ref.read(storyServiceProvider);
  return await storyService.getStorySegmentsForEpisode(episodeId);
});

// Seasons providers
final seasonsProvider = FutureProvider<List<SeasonModel>>((ref) async {
  print('🎬 SeasonsProvider: Fetching seasons');
  final storyService = ref.read(storyServiceProvider);
  final seasons = await storyService.getSeasons();
  print('🎬 SeasonsProvider: Retrieved ${seasons.length} seasons');
  return seasons;
});

// Episodes by season provider
final episodesBySeasonProvider = FutureProvider.family<List<EpisodeModel>, int>((ref, seasonNumber) async {
  print('🎬 EpisodesProvider: Fetching episodes for season $seasonNumber');
  final storyService = ref.read(storyServiceProvider);
  final episodes = await storyService.getEpisodesBySeason(seasonNumber);
  print('🎬 EpisodesProvider: Retrieved ${episodes.length} episodes for season $seasonNumber');
  return episodes;
});
