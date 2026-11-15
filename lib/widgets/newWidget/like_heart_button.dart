import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Heart button for likes. Liking plays a pop (grow, then settle) and the
/// heart fills with [activeColor]. Unliking clears it at once.
class LikeHeartButton extends StatefulWidget {
  const LikeHeartButton({
    Key? key,
    required this.isLiked,
    required this.onToggle,
    required this.size,
    required this.inactiveColor,
    required this.activeColor,
  }) : super(key: key);

  final bool isLiked;
  final VoidCallback onToggle;
  final double size;
  final Color inactiveColor;
  final Color activeColor;

  @override
  State<LikeHeartButton> createState() => _LikeHeartButtonState();
}

class _LikeHeartButtonState extends State<LikeHeartButton>
    with SingleTickerProviderStateMixin {
  late bool _liked = widget.isLiked;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..value = _liked ? 1 : 0;

  @override
  void didUpdateWidget(covariant LikeHeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow the stored state when it changes from somewhere else
    // (for example, a refresh that shows the like was saved).
    if (widget.isLiked != _liked) {
      _liked = widget.isLiked;
      _controller.value = _liked ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tap() {
    final next = !_liked;
    setState(() => _liked = next);
    if (next) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 0;
    }
    widget.onToggle();
  }

  /// Grows to 1.35x and settles back to 1.0x over the animation.
  double _popScale(double t) => 1 + 0.35 * math.sin(math.pi * t);

  /// Fill grows in after the pop starts.
  double _fill(double t) {
    final p = (((t - 0.15) / 0.6).clamp(0.0, 1.0) as num).toDouble();
    return (Curves.easeOutBack.transform(p).clamp(0.0, 1.0) as num).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _tap,
      icon: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final scale = _liked ? _popScale(t) : 1.0;
          final fill = _liked ? _fill(t) : 0.0;
          final size = widget.size;
          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Opacity(
                    opacity: ((1 - fill).clamp(0.0, 1.0) as num).toDouble(),
                    child: Icon(LucideIcons.heart,
                        size: size, color: widget.inactiveColor),
                  ),
                  Opacity(
                    opacity: fill,
                    child: Transform.scale(
                      scale: 0.4 + 0.6 * fill,
                      child: Icon(Icons.favorite,
                          size: size, color: widget.activeColor),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}




