import 'dart:math';

import 'package:flutter/material.dart';

import '../bridge/insight.dart';
import '../core/constants.dart';
import '../core/storage/stats_repository.dart';
import 'difficulty.dart';
import 'hit_tier.dart';
import 'widgets/falling_object.dart';
import 'widgets/game_hud.dart';
import 'widgets/game_over_overlay.dart';
import 'widgets/hit_effect.dart';
import 'widgets/landing_zone.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.stats});

  final StatsRepository stats;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _ActiveEffect {
  _ActiveEffect(this.id, this.tier, this.y);
  final int id;
  final HitTier tier;
  final double y;
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fallController;
  final Random _random = Random();

  late final String _background;

  int _score = 0;
  int _streak = 0;
  int _maxStreakThisRun = 0;
  int _perfectHitsThisRun = 0;
  int _stoppedObjectsThisRun = 0;

  bool _roundActive = false;
  bool _isGameOver = false;
  bool _isNewBest = false;
  bool _persisted = false;

  String _currentAsset = AppAssets.fallingObjects.first;
  bool _isGolden = false;

  final List<_ActiveEffect> _effects = [];
  int _effectSeq = 0;

  // Cached from the last build; used by the tap handler for accurate
  // geometry-based scoring.
  double _startY = 0;
  double _totalTravel = 1;
  double _zoneCenterY = 0;
  double _zoneRadius = 1;

  @override
  void initState() {
    super.initState();
    Insight.screen('game');
    _background =
        _random.nextBool() ? AppAssets.backgroundCave : AppAssets.backgroundTemple;
    _fallController = AnimationController(vsync: this);
    _fallController.addStatusListener(_onFallStatusChanged);
    _spawnRound();
  }

  @override
  void dispose() {
    _fallController.dispose();
    super.dispose();
  }

  void _onFallStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && _roundActive) {
      _roundActive = false;
      _resolveHit();
    }
  }

  void _spawnRound() {
    final variantIdx =
        Difficulty.rollObjectVariant(_streak, AppAssets.fallingObjects.length);
    final golden = Difficulty.rollGoldenCoin(_streak);
    setState(() {
      _isGolden = golden;
      _currentAsset = golden ? AppAssets.goldenCoin : AppAssets.fallingObjects[variantIdx];
      _roundActive = true;
    });
    _fallController.duration = Difficulty.fallDuration(_streak);
    _fallController.forward(from: 0);
  }

  void _handleTap() {
    if (!_roundActive || _isGameOver) return;
    _roundActive = false;
    _fallController.stop();
    _resolveHit();
  }

  void _resolveHit() {
    final t = Curves.easeIn.transform(_fallController.value);
    final currentY = _startY + _totalTravel * t;
    final distance = (currentY - _zoneCenterY).abs();
    final tier = Difficulty.classify(
      distance: distance,
      zoneRadius: _zoneRadius,
      streak: _streak,
    );

    _stoppedObjectsThisRun++;
    _addEffect(tier, currentY);

    if (tier.endsRun) {
      _endRun();
      return;
    }

    var points = tier.basePoints + Difficulty.streakBonus(_streak);
    if (_isGolden && (tier == HitTier.perfect || tier == HitTier.great)) {
      points += 50;
    }
    if (tier == HitTier.perfect) {
      _perfectHitsThisRun++;
    }

    setState(() {
      _score += points;
      _streak++;
      _maxStreakThisRun = max(_maxStreakThisRun, _streak);
    });

    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted || _isGameOver) return;
      _spawnRound();
    });
  }

  void _addEffect(HitTier tier, double y) {
    final id = _effectSeq++;
    setState(() => _effects.add(_ActiveEffect(id, tier, y)));
  }

  void _removeEffect(int id) {
    if (!mounted) return;
    setState(() => _effects.removeWhere((e) => e.id == id));
  }

  Future<void> _endRun() async {
    setState(() => _isGameOver = true);
    await _persistRun();
  }

  Future<void> _persistRun() async {
    if (_persisted) return;
    _persisted = true;
    final isNewBest = await widget.stats.reportRoundResult(
      score: _score,
      maxStreakThisRun: _maxStreakThisRun,
      perfectHitsThisRun: _perfectHitsThisRun,
      stoppedObjectsThisRun: _stoppedObjectsThisRun,
    );
    if (!mounted) return;
    setState(() => _isNewBest = isNewBest);
  }

  void _retry() {
    setState(() {
      _score = 0;
      _streak = 0;
      _maxStreakThisRun = 0;
      _perfectHitsThisRun = 0;
      _stoppedObjectsThisRun = 0;
      _isGameOver = false;
      _isNewBest = false;
      _persisted = false;
    });
    _spawnRound();
  }

  Future<void> _exitToMenu() async {
    _fallController.stop();
    await _persistRun();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          final zoneDiameter = min(width * 0.72, 320.0);
          final zoneRadius = zoneDiameter * 0.33;
          final zoneCenterY = height * 0.66;
          final objectSize = zoneDiameter * 0.34;
          final startY = -objectSize * 0.3;
          final missY = zoneCenterY + zoneRadius * 1.7;

          _zoneRadius = zoneRadius;
          _zoneCenterY = zoneCenterY;
          _startY = startY;
          _totalTravel = missY - startY;

          final bestScoreDisplay = max(widget.stats.bestScore, _score);

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _handleTap(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(_background, fit: BoxFit.cover),
                Container(color: Colors.black.withValues(alpha: 0.18)),
                Positioned(
                  left: 0,
                  right: 0,
                  top: zoneCenterY - zoneDiameter / 2,
                  child: Center(
                    child: LandingZone(
                      diameter: zoneDiameter,
                      pulse: _fallController.isAnimating
                          ? _fallController.value
                          : 0,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _fallController,
                  builder: (context, _) {
                    final t = Curves.easeIn.transform(_fallController.value);
                    final y = startY + (missY - startY) * t;
                    return FallingObject(
                      asset: _currentAsset,
                      size: objectSize,
                      centerY: y,
                      rotation: _fallController.value * pi * 3,
                      isGolden: _isGolden,
                    );
                  },
                ),
                for (final effect in _effects)
                  Positioned(
                    top: effect.y - 100,
                    left: 0,
                    right: 0,
                    height: 200,
                    child: HitEffect(
                      tier: effect.tier,
                      onComplete: () => _removeEffect(effect.id),
                    ),
                  ),
                GameHud(
                  score: _score,
                  bestScore: bestScoreDisplay,
                  streak: _streak,
                  maxStreak: _maxStreakThisRun,
                  perfectHits: _perfectHitsThisRun,
                  stoppedObjects: _stoppedObjectsThisRun,
                  onExit: _exitToMenu,
                ),
                if (_isGameOver)
                  GameOverOverlay(
                    score: _score,
                    bestScore: max(widget.stats.bestScore, _score),
                    isNewBest: _isNewBest,
                    maxStreak: _maxStreakThisRun,
                    perfectHits: _perfectHitsThisRun,
                    stoppedObjects: _stoppedObjectsThisRun,
                    onRetry: _retry,
                    onMenu: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
