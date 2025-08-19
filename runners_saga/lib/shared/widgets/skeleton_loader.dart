import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';

class SkeletonLoader extends StatefulWidget {
  final double height;
  final double width;
  final double borderRadius;
  final EdgeInsets? margin;

  const SkeletonLoader({
    super.key,
    this.height = 20,
    this.width = double.infinity,
    this.borderRadius = 8,
    this.margin,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                kSurfaceElev.withValues(alpha: 0.3 + (_animation.value * 0.2)),
                kSurfaceElev.withValues(alpha: 0.5 + (_animation.value * 0.3)),
                kSurfaceElev.withValues(alpha: 0.3 + (_animation.value * 0.2)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double height;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final List<Widget> children;

  const SkeletonCard({
    super.key,
    this.height = 120,
    this.margin,
    this.padding,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceBase,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSurfaceElev.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class SkeletonText extends StatelessWidget {
  final double height;
  final double width;
  final EdgeInsets? margin;

  const SkeletonText({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      height: height,
      width: width,
      margin: margin,
      borderRadius: height / 2,
    );
  }
}

class SkeletonAvatar extends StatelessWidget {
  final double size;
  final EdgeInsets? margin;

  const SkeletonAvatar({
    super.key,
    this.size = 40,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      height: size,
      width: size,
      margin: margin,
      borderRadius: size / 2,
    );
  }
}




