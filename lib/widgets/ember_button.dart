import 'package:flutter/material.dart';

import '../core/constants.dart';

/// Reusable pill-shaped call-to-action button with the game's ember theme.
class EmberButton extends StatelessWidget {
  const EmberButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = true,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: filled ? Colors.white : AppColors.emberYellow),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : AppColors.emberYellow,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: filled
                ? const LinearGradient(colors: AppColors.emberGradient)
                : null,
            color: filled ? null : Colors.black.withValues(alpha: 0.35),
            border: filled
                ? null
                : Border.all(color: AppColors.emberOrange.withValues(alpha: 0.7), width: 1.6),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: AppColors.emberOrange.withValues(alpha: 0.5),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
