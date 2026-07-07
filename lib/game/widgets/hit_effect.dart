import 'package:flutter/material.dart';

import '../hit_tier.dart';

/// A short-lived burst effect shown at the point where the falling object
/// was stopped. Bright expanding rings for great hits, a duller red pulse
/// for a miss.
class HitEffect extends StatefulWidget {
  const HitEffect({
    super.key,
    required this.tier,
    required this.onComplete,
  });

  final HitTier tier;
  final VoidCallback onComplete;

  @override
  State<HitEffect> createState() => _HitEffectState();
}

class _HitEffectState extends State<HitEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBig = widget.tier == HitTier.perfect || widget.tier == HitTier.great;
    final maxSize = isBig ? 190.0 : 130.0;
    final color = widget.tier.color;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final size = maxSize * Curves.easeOut.transform(t);
          final opacity = (1 - t).clamp(0.0, 1.0);
          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: opacity,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.8),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                Opacity(
                  opacity: (opacity * 1.4).clamp(0.0, 1.0),
                  child: Container(
                    width: size * 0.45,
                    height: size * 0.45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.55),
                      boxShadow: [
                        BoxShadow(
                          color: color,
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                if (t < 0.65)
                  Opacity(
                    opacity: (1 - t / 0.65).clamp(0.0, 1.0),
                    child: Text(
                      widget.tier.label,
                      style: TextStyle(
                        color: color,
                        fontSize: isBig ? 30 : 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
