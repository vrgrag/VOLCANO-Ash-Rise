import 'package:flutter/material.dart';

/// Central place for asset paths, links and shared visual constants.
class AppAssets {
  AppAssets._();

  static const String backgroundCave = 'assets/bg1_asset.webp';
  static const String backgroundVolcano = 'assets/bg2_asset.webp';
  static const String backgroundTemple = 'assets/bg3_asset.webp';

  static const String logo = 'assets/Game_Name.webp';
  static const String icon = 'assets/Icon.png';

  static const String loadingVertical = 'assets/Vertical_Loading_Screen.webp';
  static const String loadingHorizontal = 'assets/Horizontal_Loading_Screen.webp';

  static const String landingZone = 'assets/volcanic_landing_zone_asset.webp';

  static const String coreRed = 'assets/lava_core_asset.webp';
  static const String coreBlue = 'assets/blue_lava_core_asset.webp';
  static const String corePurple = 'assets/purple_lava_core_asset.webp';
  static const String rockA = 'assets/lava_rockasset.webp';
  static const String rockB = 'assets/lava_rock_asset.webp';
  static const String goldenCoin = 'assets/golden_coin_asset.webp';

  /// All falling-object skins used during normal gameplay.
  static const List<String> fallingObjects = [
    coreRed,
    coreBlue,
    corePurple,
    rockA,
    rockB,
  ];

  /// Every image asset that should be pre-cached before the game is playable.
  static const List<String> preloadable = [
    backgroundCave,
    backgroundVolcano,
    backgroundTemple,
    logo,
    landingZone,
    coreRed,
    coreBlue,
    corePurple,
    rockA,
    rockB,
    goldenCoin,
  ];
}

class AppLinks {
  AppLinks._();

  static const String privacyPolicy = 'https://ashhrise.com/privacy-policy.html';
  static const String support = 'https://ashhrise.com/support.html';
}

class AppColors {
  AppColors._();

  static const Color emberOrange = Color(0xFFFF6A1A);
  static const Color emberYellow = Color(0xFFFFC24B);
  static const Color deepRed = Color(0xFF7A1408);
  static const Color charcoal = Color(0xFF120A08);
  static const Color ashGrey = Color(0xFFBFB6AC);

  static const List<Color> emberGradient = [
    Color(0xFFFFD166),
    Color(0xFFFF8A1E),
    Color(0xFFB3220C),
  ];
}

class AppPrefsKeys {
  AppPrefsKeys._();

  static const String bestScore = 'best_score';
  static const String maxStreak = 'max_streak';
  static const String perfectHits = 'perfect_hits_total';
  static const String stoppedObjects = 'stopped_objects_total';
  static const String soundEnabled = 'sound_enabled';
}
