import 'package:flutter/material.dart';

/// Accuracy tiers for a stopped falling object, ordered from best to worst.
enum HitTier { perfect, great, good, ok, miss }

extension HitTierData on HitTier {
  String get label {
    switch (this) {
      case HitTier.perfect:
        return 'PERFECT!';
      case HitTier.great:
        return 'GREAT';
      case HitTier.good:
        return 'GOOD';
      case HitTier.ok:
        return 'OK';
      case HitTier.miss:
        return 'MISS';
    }
  }

  int get basePoints {
    switch (this) {
      case HitTier.perfect:
        return 100;
      case HitTier.great:
        return 65;
      case HitTier.good:
        return 35;
      case HitTier.ok:
        return 15;
      case HitTier.miss:
        return 0;
    }
  }

  Color get color {
    switch (this) {
      case HitTier.perfect:
        return const Color(0xFFFFE066);
      case HitTier.great:
        return const Color(0xFFFF9A3C);
      case HitTier.good:
        return const Color(0xFFFF6A1A);
      case HitTier.ok:
        return const Color(0xFFCF8B5C);
      case HitTier.miss:
        return const Color(0xFF8B0000);
    }
  }

  bool get endsRun => this == HitTier.miss;
}
