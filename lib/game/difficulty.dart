import 'dart:math';

import 'hit_tier.dart';

/// All difficulty scaling driven by the current streak (combo) length.
/// Speed increases and the precise zone effectively tightens the longer
/// the player survives, per the game design document.
class Difficulty {
  Difficulty._();

  static const int _baseDurationMs = 1750;
  static const int _minDurationMs = 620;
  static const int _msLostPerStreak = 38;

  /// Total fall duration for the current streak. Gets shorter (faster
  /// falling object) as the streak grows, floors out so it stays playable.
  static Duration fallDuration(int streak) {
    final ms = _baseDurationMs - streak * _msLostPerStreak;
    return Duration(milliseconds: ms.clamp(_minDurationMs, _baseDurationMs));
  }

  /// Multiplier applied to the accuracy thresholds. Shrinks the effective
  /// "precise zone" as the streak grows, bottoming out so perfects remain
  /// achievable with real skill.
  static double thresholdScale(int streak) {
    final scale = 1.0 - streak * 0.014;
    return scale.clamp(0.62, 1.0);
  }

  /// Classifies a stop distance (in logical px from the zone's dead-center)
  /// against the zone's outer radius, honoring current difficulty.
  static HitTier classify({
    required double distance,
    required double zoneRadius,
    required int streak,
  }) {
    final scale = thresholdScale(streak);
    final ratio = distance / zoneRadius;

    if (ratio <= 0.16 * scale) return HitTier.perfect;
    if (ratio <= 0.38 * scale) return HitTier.great;
    if (ratio <= 0.68 * scale) return HitTier.good;
    if (ratio <= 1.0) return HitTier.ok;
    return HitTier.miss;
  }

  /// Small extra reward for keeping a long streak alive, layered on top of
  /// the tier's base points. Capped so scoring stays predictable.
  static int streakBonus(int streak) => min(streak * 2, 60);

  static final Random _random = Random();

  /// Picks whether this round should feature the rare golden coin bonus
  /// object. Unlocked only once the player has proven some consistency.
  static bool rollGoldenCoin(int streak) {
    if (streak < 5) return false;
    return _random.nextDouble() < 0.14;
  }

  /// Picks a random falling-object asset index, unlocking more exotic
  /// skins as the streak grows for visual variety.
  static int rollObjectVariant(int streak, int variantCount) {
    final unlocked = min(variantCount, 2 + (streak ~/ 3));
    return _random.nextInt(unlocked);
  }
}
