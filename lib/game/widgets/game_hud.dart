import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Top HUD strip. Shows every metric called out in the design document:
/// current score, best score, current streak, max streak this run,
/// perfect hits and stopped objects.
class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.score,
    required this.bestScore,
    required this.streak,
    required this.maxStreak,
    required this.perfectHits,
    required this.stoppedObjects,
    required this.onExit,
  });

  final int score;
  final int bestScore;
  final int streak;
  final int maxStreak;
  final int perfectHits;
  final int stoppedObjects;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconButton(icon: Icons.close_rounded, onTap: onExit),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '$score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 10),
                          ],
                        ),
                      ),
                      Text(
                        'BEST $bestScore',
                        style: TextStyle(
                          color: AppColors.emberYellow.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                _StreakBadge(streak: streak),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MiniStat(icon: Icons.bolt_rounded, label: 'Max streak', value: maxStreak),
                const SizedBox(width: 18),
                _MiniStat(icon: Icons.center_focus_strong_rounded, label: 'Perfect', value: perfectHits),
                const SizedBox(width: 18),
                _MiniStat(icon: Icons.adjust_rounded, label: 'Stopped', value: stoppedObjects),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: AppColors.emberGradient),
        boxShadow: [
          BoxShadow(color: AppColors.emberOrange.withValues(alpha: 0.5), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.ashGrey.withValues(alpha: 0.9), size: 14),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
