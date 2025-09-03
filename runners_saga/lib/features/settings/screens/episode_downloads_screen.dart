import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runners_saga/core/constants/app_theme.dart';
import 'package:runners_saga/shared/models/episode_model.dart';
import 'package:runners_saga/shared/providers/story_providers.dart';
import 'package:runners_saga/shared/services/audio/download_service.dart';
import 'package:runners_saga/shared/widgets/navigation/bottom_navigation_widget.dart';

class EpisodeDownloadsScreen extends ConsumerStatefulWidget {
  const EpisodeDownloadsScreen({super.key});

  @override
  ConsumerState<EpisodeDownloadsScreen> createState() => _EpisodeDownloadsScreenState();
}

class _EpisodeDownloadsScreenState extends ConsumerState<EpisodeDownloadsScreen> {
  final DownloadService _downloadService = DownloadService();
  List<EpisodeModel> _downloadedEpisodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadedEpisodes();
  }

  Future<void> _loadDownloadedEpisodes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all episodes from the database
      final allEpisodes = await ref.read(storyServiceProvider).getAllEpisodes();
      
      // Filter episodes that are downloaded
      final downloadedEpisodes = <EpisodeModel>[];
      
      for (final episode in allEpisodes) {
        final isDownloaded = await _downloadService.isEpisodeDownloaded(episode.id);
        if (isDownloaded) {
          downloadedEpisodes.add(episode);
        }
      }
      
      setState(() {
        _downloadedEpisodes = downloadedEpisodes;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading downloaded episodes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEpisode(EpisodeModel episode) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: kMidnightNavy,
          title: const Text(
            'Delete Episode',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete "${episode.title}" from your device? This action cannot be undone.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: kElectricAqua),
              ),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Delete the episode directory and all its files
        await _downloadService.deleteEpisode(episode.id);
        
        // Remove from the list
        setState(() {
          _downloadedEpisodes.removeWhere((e) => e.id == episode.id);
        });
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${episode.title} deleted successfully'),
              backgroundColor: kElectricAqua,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error deleting episode: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting episode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMidnightNavy,
      appBar: AppBar(
        backgroundColor: kMidnightNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Episode Downloads',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kElectricAqua),
              ),
            )
          : _downloadedEpisodes.isEmpty
              ? _buildEmptyState()
              : _buildEpisodesList(),
      bottomNavigationBar: const BottomNavigationWidget(
        currentIndex: 3, // Settings index
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_done_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'No Downloaded Episodes',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Download episodes to listen to them offline',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _downloadedEpisodes.length,
      itemBuilder: (context, index) {
        final episode = _downloadedEpisodes[index];
        return _buildEpisodeCard(episode);
      },
    );
  }

  Widget _buildEpisodeCard(EpisodeModel episode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: kElectricAqua.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.play_circle_outline,
            color: kElectricAqua,
            size: 24,
          ),
        ),
        title: Text(
          episode.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              episode.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.route,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '${episode.targetDistance.toStringAsFixed(1)} km',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '${(episode.targetTime / 60000).toStringAsFixed(0)} min',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.delete_outline,
            color: Colors.red,
          ),
          onPressed: () => _deleteEpisode(episode),
        ),
      ),
    );
  }
}

