import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

/// Lightweight persisted lifetime statistics for the player.
/// Backed by [SharedPreferences] so the game keeps progress fully offline.
class StatsRepository {
  StatsRepository._(this._prefs);

  final SharedPreferences _prefs;

  static StatsRepository? _instance;

  static Future<StatsRepository> load() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    _instance = StatsRepository._(prefs);
    return _instance!;
  }

  int get bestScore => _prefs.getInt(AppPrefsKeys.bestScore) ?? 0;
  int get maxStreak => _prefs.getInt(AppPrefsKeys.maxStreak) ?? 0;
  int get perfectHitsTotal => _prefs.getInt(AppPrefsKeys.perfectHits) ?? 0;
  int get stoppedObjectsTotal => _prefs.getInt(AppPrefsKeys.stoppedObjects) ?? 0;
  bool get soundEnabled => _prefs.getBool(AppPrefsKeys.soundEnabled) ?? true;

  Future<void> setSoundEnabled(bool value) =>
      _prefs.setBool(AppPrefsKeys.soundEnabled, value);

  /// Returns true if a new best score record was set.
  Future<bool> reportRoundResult({
    required int score,
    required int maxStreakThisRun,
    required int perfectHitsThisRun,
    required int stoppedObjectsThisRun,
  }) async {
    final isNewBest = score > bestScore;
    if (isNewBest) {
      await _prefs.setInt(AppPrefsKeys.bestScore, score);
    }
    if (maxStreakThisRun > maxStreak) {
      await _prefs.setInt(AppPrefsKeys.maxStreak, maxStreakThisRun);
    }
    await _prefs.setInt(
      AppPrefsKeys.perfectHits,
      perfectHitsTotal + perfectHitsThisRun,
    );
    await _prefs.setInt(
      AppPrefsKeys.stoppedObjects,
      stoppedObjectsTotal + stoppedObjectsThisRun,
    );
    return isNewBest;
  }
}
