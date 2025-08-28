import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_manager.dart';

/// Provider for AudioManager service
final audioManagerProvider = Provider<AudioManager>((ref) {
  return AudioManager();
});

/// Provider for audio manager state
final audioStateProvider = StateNotifierProvider<AudioStateNotifier, AudioState>((ref) {
  return AudioStateNotifier(ref.read(audioManagerProvider));
});

/// Audio state
class AudioState {
  final bool isBackgroundMusicPlaying;
  final bool isStoryAudioPlaying;
  final bool isSfxPlaying;
  
  const AudioState({
    this.isBackgroundMusicPlaying = false,
    this.isStoryAudioPlaying = false,
    this.isSfxPlaying = false,
  });
  
  AudioState copyWith({
    bool? isBackgroundMusicPlaying,
    bool? isStoryAudioPlaying,
    bool? isSfxPlaying,
  }) {
    return AudioState(
      isBackgroundMusicPlaying: isBackgroundMusicPlaying ?? this.isBackgroundMusicPlaying,
      isStoryAudioPlaying: isStoryAudioPlaying ?? this.isStoryAudioPlaying,
      isSfxPlaying: isSfxPlaying ?? this.isSfxPlaying,
    );
  }
}

/// Audio state notifier
class AudioStateNotifier extends StateNotifier<AudioState> {
  final AudioManager _audioManager;
  
  AudioStateNotifier(this._audioManager) : super(const AudioState()) {
    _initializeAudioManager();
  }
  
  Future<void> _initializeAudioManager() async {
    await _audioManager.initialize();
  }
  
  Future<void> pauseAll() async {
    await _audioManager.pauseAll();
    state = state.copyWith(
      isBackgroundMusicPlaying: false,
      isStoryAudioPlaying: false,
      isSfxPlaying: false,
    );
  }
  
  Future<void> resumeAll() async {
    await _audioManager.resumeAll();
    // Note: We can't easily determine the actual state without more complex tracking
    // For now, we'll assume audio is playing if it was playing before
  }
  
  Future<void> stopAll() async {
    await _audioManager.stopAll();
    state = const AudioState();
  }
}















