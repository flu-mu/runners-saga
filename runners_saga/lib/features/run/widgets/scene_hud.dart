import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_theme.dart';
import '../../../shared/providers/run_session_providers.dart';
import '../../../shared/services/scene_trigger_service.dart';

class SceneHud extends ConsumerWidget {
  const SceneHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentScene = ref.watch(currentSceneProvider);
    final isScenePlaying = currentScene != null;
    
    // Only show when a scene is actually playing
    if (!isScenePlaying) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: kMidnightNavy.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kElectricAqua.withValues(alpha: 0.8), width: 2),
        boxShadow: [
          BoxShadow(
            color: kElectricAqua.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated radio icon
          _AnimatedRadioIcon(),
          const SizedBox(width: 12),
          // Scene info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'STORY TRANSMISSION',
                style: TextStyle(
                  color: kElectricAqua.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                SceneTriggerService.getSceneTitle(currentScene!),
                style: TextStyle(
                  color: kElectricAqua,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Animated dots
          _AnimatedDots(),
        ],
      ),
    );
  }
}

class _AnimatedRadioIcon extends StatefulWidget {
  @override
  State<_AnimatedRadioIcon> createState() => _AnimatedRadioIconState();
}

class _AnimatedRadioIconState extends State<_AnimatedRadioIcon> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    // Only start animation if widget is still mounted
    if (mounted && !_disposed) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Icon(
            Icons.radio,
            color: kElectricAqua,
            size: 24,
          ),
        );
      },
    );
  }
}

class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> with TickerProviderStateMixin {
  late List<AnimationController> _dotControllers;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _dotControllers = List.generate(3, (index) => 
      AnimationController(duration: Duration(milliseconds: 600 + (index * 200)), vsync: this)
    );
    _dotAnimations = _dotControllers.map((controller) => 
      Tween<double>(begin: 0.0, end: 1.0).animate(controller)
    ).toList();
    
    // Start animations with staggered timing
    for (int i = 0; i < _dotControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _dotControllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _dotControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _dotAnimations[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: kElectricAqua.withValues(alpha: 0.3 + (_dotAnimations[index].value * 0.7)),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}



