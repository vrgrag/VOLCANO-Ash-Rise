import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../widgets/ember_button.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.score,
    required this.bestScore,
    required this.isNewBest,
    required this.maxStreak,
    required this.perfectHits,
    required this.stoppedObjects,
    required this.onRetry,
    required this.onMenu,
  });

  final int score;
  final int bestScore;
  final bool isNewBest;
  final int maxStreak;
  final int perfectHits;
  final int stoppedObjects;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.charcoal,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.emberOrange.withValues(alpha: 0.6), width: 2),
            boxShadow: [
              BoxShadow(color: AppColors.emberOrange.withValues(alpha: 0.35), blurRadius: 30),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isNewBest ? 'NEW RECORD!' : 'THE LAVA CLAIMS IT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isNewBest ? AppColors.emberYellow : Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const Text(
                'SCORE',
                style: TextStyle(color: AppColors.ashGrey, fontSize: 13, letterSpacing: 2),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 18,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _StatChip(label: 'Best score', value: '$bestScore'),
                  _StatChip(label: 'Max streak', value: '$maxStreak'),
                  _StatChip(label: 'Perfect hits', value: '$perfectHits'),
                  _StatChip(label: 'Stopped', value: '$stoppedObjects'),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: EmberButton(
                      label: 'Menu',
                      filled: false,
                      onTap: onMenu,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EmberButton(
                      label: 'Retry',
                      filled: true,
                      onTap: onRetry,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(color: AppColors.ashGrey, fontSize: 11),
        ),
      ],
    );
  }
}
