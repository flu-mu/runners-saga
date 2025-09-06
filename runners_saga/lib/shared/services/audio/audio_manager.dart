import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

enum AudioType {
  background,
  story,
  sfx,
}

class AudioItem {
  final String audioFile;
  final AudioType type;
  final double? volume;

  AudioItem({
    required this.audioFile,
    required this.type,
    this.volume,
  });
}

class AudioManager {
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();
  final AudioPlayer _storyAudioPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  
  // Volume levels
  double _backgroundMusicVolume = 0.5;
  double _storyAudioVolume = 1.0;
  double _sfxVolume = 0.7;
  
  // State tracking
  bool _isBackgroundMusicPlaying = false;
  bool _isStoryAudioPlaying = false;
  bool _isSfxPlaying = false;
  bool _backgroundDucked = false;
  double _preDuckBackgroundVolume = 0.5;
  
  // Audio queue
  final List<AudioItem> _audioQueue = [];
  bool _isProcessingQueue = false;
  
  // Crossfade settings
  Duration _crossfadeDuration = const Duration(milliseconds: 500);
  
  // Callbacks
  Function(String audioFile)? onAudioStart;
  Function(String audioFile)? onAudioComplete;
  Function(String audioFile)? onAudioError;
  
  // Getters
  bool get isBackgroundMusicPlaying => _isBackgroundMusicPlaying;
  bool get isStoryAudioPlaying => _isStoryAudioPlaying;
  bool get isSfxPlaying => _isSfxPlaying;
  
  /// Initialize the audio manager
  Future<void> initialize() async {
    // Set up audio players
    await _backgroundMusicPlayer.setLoopMode(LoopMode.all);
    
    // Set initial volumes
    await _backgroundMusicPlayer.setVolume(_backgroundMusicVolume);
    await _storyAudioPlayer.setVolume(_storyAudioVolume);
    await _sfxPlayer.setVolume(_sfxVolume);
    
    // Set up completion handlers
    _storyAudioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onStoryAudioComplete();
      }
    });
    _sfxPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onSfxComplete();
      }
    });
  }
  
  /// Play background music
  Future<void> playBackgroundMusic(String audioFile, {double? volume}) async {
    try {
      await _backgroundMusicPlayer.setAsset(audioFile);
      await _backgroundMusicPlayer.setVolume(volume ?? _backgroundMusicVolume);
      await _backgroundMusicPlayer.play();
      
      _isBackgroundMusicPlaying = true;
      onAudioStart?.call(audioFile);
      
    } catch (e) {
      if (kDebugMode) {
        print('Error playing background music: $e');
      }
      onAudioError?.call(audioFile);
    }
  }
  
  /// Play story audio
  Future<void> playStoryAudio(String audioFile, {double? volume}) async {
    try {
      // Stop any currently playing story audio
      if (_isStoryAudioPlaying) {
        await _fadeOutStoryAudio();
      }
      
      await _storyAudioPlayer.setAsset(audioFile);
      await _storyAudioPlayer.setVolume(volume ?? _storyAudioVolume);
      await _storyAudioPlayer.play();
      
      _isStoryAudioPlaying = true;
      onAudioStart?.call(audioFile);
      
      // Fade in
      await _fadeInStoryAudio();
      
    } catch (e) {
      if (kDebugMode) {
        print('Error playing story audio: $e');
      }
      onAudioError?.call(audioFile);
    }
  }
  
  /// Play sound effect
  Future<void> playSfx(String audioFile, {double? volume}) async {
    try {
      // Stop any currently playing SFX
      if (_isSfxPlaying) {
        await _sfxPlayer.stop();
      }
      
      await _sfxPlayer.setAsset(audioFile);
      await _sfxPlayer.setVolume(volume ?? _sfxVolume);
      await _sfxPlayer.play();
      
      _isSfxPlaying = true;
      
    } catch (e) {
      if (kDebugMode) {
        print('Error playing SFX: $e');
      }
    }
  }
  
  /// Stop background music
  Future<void> stopBackgroundMusic() async {
    await _backgroundMusicPlayer.stop();
    _isBackgroundMusicPlaying = false;
  }
  
  /// Stop story audio
  Future<void> stopStoryAudio() async {
    if (!_isStoryAudioPlaying) return;
    await _fadeOutStoryAudio();
    await _storyAudioPlayer.stop();
    _isStoryAudioPlaying = false;
  }
  
  /// Stop sound effect
  Future<void> stopSfx() async {
    await _sfxPlayer.stop();
    _isSfxPlaying = false;
  }
  
  /// Pause all audio
  Future<void> pauseAll() async {
    await _backgroundMusicPlayer.pause();
    await _storyAudioPlayer.pause();
    await _sfxPlayer.pause();
  }
  
  /// Resume all audio
  Future<void> resumeAll() async {
    if (_isBackgroundMusicPlaying) await _backgroundMusicPlayer.play();
    if (_isStoryAudioPlaying) await _storyAudioPlayer.play();
    if (_isSfxPlaying) await _sfxPlayer.play();
  }
  
  /// Stop all audio
  Future<void> stopAll() async {
    await _backgroundMusicPlayer.stop();
    await _storyAudioPlayer.stop();
    await _sfxPlayer.stop();
    
    _isBackgroundMusicPlaying = false;
    _isStoryAudioPlaying = false;
    _isSfxPlaying = false;
  }
  
  /// Set volume levels
  Future<void> setVolume(AudioType type, double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    
    switch (type) {
      case AudioType.background:
        _backgroundMusicVolume = clampedVolume;
        await _backgroundMusicPlayer.setVolume(clampedVolume);
        break;
      case AudioType.story:
        _storyAudioVolume = clampedVolume;
        await _storyAudioPlayer.setVolume(clampedVolume);
        break;
      case AudioType.sfx:
        _sfxVolume = clampedVolume;
        await _sfxPlayer.setVolume(clampedVolume);
        break;
    }
  }

  /// Duck internal/background music to a fraction of its normal volume
  Future<void> duckBackgroundMusic({double fraction = 0.10, bool gradual = true}) async {
    try {
      if (!_isBackgroundMusicPlaying) return;
      if (_backgroundDucked) return; // already ducked
      _preDuckBackgroundVolume = _backgroundMusicVolume;
      final target = (_preDuckBackgroundVolume * fraction).clamp(0.0, 1.0);

      if (gradual) {
        const fadeSteps = 6;
        const fadeDuration = Duration(milliseconds: 300);
        for (int i = 1; i <= fadeSteps; i++) {
          final v = _preDuckBackgroundVolume - (i * (_preDuckBackgroundVolume - target) / fadeSteps);
          await _backgroundMusicPlayer.setVolume(v);
          await Future.delayed(fadeDuration ~/ fadeSteps);
        }
      } else {
        await _backgroundMusicPlayer.setVolume(target);
      }
      _backgroundDucked = true;
      if (kDebugMode) {
        print('🔇 AudioManager: Background music ducked to ${fraction * 100}%');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ AudioManager: Error ducking background music: $e');
      }
    }
  }

  /// Restore background/internal music volume after ducking
  Future<void> restoreBackgroundMusic({bool gradual = true}) async {
    try {
      if (!_isBackgroundMusicPlaying) return;
      final target = _preDuckBackgroundVolume.clamp(0.0, 1.0);
      if (gradual) {
        const fadeSteps = 10;
        const fadeDuration = Duration(milliseconds: 500);
        final currentVol = await _backgroundMusicPlayer.volume;
        for (int i = 1; i <= fadeSteps; i++) {
          final v = currentVol + (i * (target - currentVol) / fadeSteps);
          await _backgroundMusicPlayer.setVolume(v);
          await Future.delayed(fadeDuration ~/ fadeSteps);
        }
      } else {
        await _backgroundMusicPlayer.setVolume(target);
      }
      _backgroundDucked = false;
      if (kDebugMode) {
        print('🔊 AudioManager: Background music volume restored');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ AudioManager: Error restoring background music: $e');
      }
    }
  }
  
  /// Fade in story audio
  Future<void> _fadeInStoryAudio() async {
    const fadeSteps = 10;
    const fadeDuration = Duration(milliseconds: 500);
    
    for (int i = 0; i <= fadeSteps; i++) {
      final volume = (_storyAudioVolume * i / fadeSteps);
      await _storyAudioPlayer.setVolume(volume);
      await Future.delayed(fadeDuration ~/ fadeSteps);
    }
  }
  
  /// Fade out story audio
  Future<void> _fadeOutStoryAudio() async {
    const fadeSteps = 10;
    const fadeDuration = Duration(milliseconds: 500);
    
    for (int i = fadeSteps; i >= 0; i--) {
      final volume = (_storyAudioVolume * i / fadeSteps);
      await _storyAudioPlayer.setVolume(volume);
      await Future.delayed(fadeDuration ~/ fadeSteps);
    }
  }
  
  /// Handle story audio completion
  void _onStoryAudioComplete() async {
    _isStoryAudioPlaying = false;
    onAudioComplete?.call('story_audio');
    
    // Automatically restore external music volume when story audio completes
    await _restoreExternalMusicVolume(gradual: true);
  }
  
  /// Handle SFX completion
  void _onSfxComplete() {
    _isSfxPlaying = false;
  }
  
  /// Duck external music volume (for when story audio plays)
  Future<void> _duckExternalMusic({bool gradual = true}) async {
    try {
      if (gradual) {
        // Gradual volume reduction over 300ms
        const fadeSteps = 6;
        const fadeDuration = Duration(milliseconds: 300);
        
        for (int i = fadeSteps; i >= 0; i--) {
          final volume = (_backgroundMusicVolume * i / fadeSteps);
          // await _backgroundMusicPlayer.setVolume(volume);
          await Future.delayed(fadeDuration ~/ fadeSteps);
        }
      } else {
        // Immediate volume reduction
        // await _backgroundMusicPlayer.setVolume(_backgroundMusicVolume * 0.3);
      }
      
      print('🔇 AudioManager: External music volume ducked');
    } catch (e) {
      print('⚠️ AudioManager: Error ducking external music: $e');
    }
  }
  
  /// Restore external music volume
  Future<void> _restoreExternalMusicVolume({bool gradual = true}) async {
    try {
      if (gradual) {
        // Gradual volume restoration over 500ms
        const fadeSteps = 10;
        const fadeDuration = Duration(milliseconds: 500);
        
        for (int i = 0; i <= fadeSteps; i++) {
          final volume = (_backgroundMusicVolume * i / fadeSteps);
          // await _backgroundMusicPlayer.setVolume(volume);
          await Future.delayed(fadeDuration ~/ fadeSteps);
        }
      } else {
        // Immediate volume restoration
        // await _backgroundMusicPlayer.setVolume(_backgroundMusicVolume);
      }
      
      print('🔊 AudioManager: External music volume restored');
    } catch (e) {
      print('⚠️ AudioManager: Error restoring external music: $e');
    }
  }
  
  /// Play audio with automatic volume ducking for external music
  Future<void> playAudioWithDucking(String audioFile) async {
    try {
      print('🎵 AudioManager: Starting audio with ducking for: $audioFile');
      
      // Duck external music volume gradually
      await _duckExternalMusic(gradual: true);
      
      // Play the audio
      await playStoryAudio(audioFile);
      
      // Note: Volume restoration will happen automatically when audio completes
      // via the _onStoryAudioComplete callback
      
      print('✅ AudioManager: Audio playback with ducking started');
      
    } catch (e) {
      print('❌ Error playing audio with ducking: $e');
      // Ensure external music volume is restored even on error
      await _restoreExternalMusicVolume(gradual: false);
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await stopAll();
    await _backgroundMusicPlayer.dispose();
    await _storyAudioPlayer.dispose();
    await _sfxPlayer.dispose();
  }
}
