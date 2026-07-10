import 'package:flutter/material.dart';

import '../core/constants.dart';

// ============================================================
// Gray-flow (shell) buttons — ember/volcano themed
// ============================================================
// Distinct from the game's EmberButton widget on purpose (different code
// path + different fingerprint), but visually on-theme so they sit cleanly
// inside the lava artwork.
//
// Both buttons follow gray_part_pitfalls.md:
//   • §13 — label uses height:1.0 + CrossAxisAlignment.center so it never
//     drifts off the geometric centre in either orientation.
//   • §12 — the secondary "Skip" is a real, high-contrast pill button,
//     NOT a faint underlined text link.
// ============================================================

/// Primary call-to-action (Accept / Retry). Filled ember gradient pill.
class LavaButton extends StatefulWidget {
  const LavaButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.width,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final double? width;
  final bool compact;

  @override
  State<LavaButton> createState() => _LavaButtonState();
}

class _LavaButtonState extends State<LavaButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          height: widget.compact ? 48 : 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.emberGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.emberOrange.withValues(alpha: 0.55),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _CenteredLabel(
            label: widget.label,
            icon: widget.icon,
            color: Colors.white,
            fontSize: widget.compact ? 16 : 18,
          ),
        ),
      ),
    );
  }
}

/// Secondary action (Skip). Translucent pill with an ember border — a real
/// button with strong contrast, never a low-contrast text link (§12).
class LavaGhostButton extends StatefulWidget {
  const LavaGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final double? width;
  final bool compact;

  @override
  State<LavaGhostButton> createState() => _LavaGhostButtonState();
}

class _LavaGhostButtonState extends State<LavaGhostButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          height: widget.compact ? 46 : 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.emberOrange.withValues(alpha: 0.85),
              width: 1.5,
            ),
          ),
          child: _CenteredLabel(
            label: widget.label,
            color: AppColors.emberYellow,
            fontSize: widget.compact ? 15 : 17,
          ),
        ),
      ),
    );
  }
}

class _CenteredLabel extends StatelessWidget {
  const _CenteredLabel({
    required this.label,
    required this.color,
    required this.fontSize,
    this.icon,
  });

  final String label;
  final Color color;
  final double fontSize;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            height: 1.0,
            shadows: const [
              Shadow(color: Color(0x99000000), offset: Offset(0, 2), blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}
