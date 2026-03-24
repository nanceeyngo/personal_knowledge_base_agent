import 'package:flutter/material.dart';

/// Animated three-dot typing indicator shown while the assistant streams.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
          (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: c, curve: Curves.easeInOut),
    ))
        .toList();

    // Stagger the dots
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (_, _) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 7,
              height: 7,
              transform: Matrix4.translationValues(0, -_animations[i].value, 0),
              decoration: BoxDecoration(
                color: color.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}